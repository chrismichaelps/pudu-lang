#ifndef PUDU_IOS_NAVIGATION_H
#define PUDU_IOS_NAVIGATION_H

@interface PuduRouteSurface : UIView
@property (strong, nonatomic) UIView *body;
@property (strong, nonatomic) UILayoutGuide *available;
@end

@implementation PuduRouteSurface
- (void)placeBody:(UIView *)body fillsArea:(BOOL)fills {
  if (self.body == body) return;
  [self.body removeFromSuperview];
  self.body = body;
  body.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:body];
  if (self.available != nil) pudu_place_root(body, self.available, fills);
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window != nil && self.available == nil) {
    self.available = pudu_available_area(self);
    if (self.body != nil) pudu_place_root(self.body, self.available, [self.body isKindOfClass:PuduScroll.class]);
  }
}
@end

@interface PuduPage : UIViewController
@property (nonatomic) uint32_t instance;
@end

@implementation PuduPage
- (void)loadView {
  self.view = [PuduRouteSurface new];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
}
@end

@interface PuduRouteSnapshot : NSObject
@property (nonatomic) uint32_t instance;
@property (copy, nonatomic) NSString *title;
@property (strong, nonatomic) UIView *body;
@end

@implementation PuduRouteSnapshot
@end

@interface PuduNavigation : NSObject <UINavigationControllerDelegate>
@property (strong, nonatomic) UINavigationController *controller;
@property (copy, nonatomic) NSArray<PuduPage *> *requested;
@property (copy, nonatomic) NSArray<PuduPage *> *reported;
@property (copy, nonatomic) NSArray<PuduRouteSnapshot *> *pending;
@property (nonatomic) BOOL waiting;
- (void)publish:(NSArray<PuduRouteSnapshot *> *)routes;
@end

@implementation PuduNavigation
- (void)flush {
  self.waiting = NO;
  NSArray<PuduRouteSnapshot *> *next = self.pending;
  self.pending = nil;
  if (next != nil) [self publish:next];
}

- (void)publish:(NSArray<PuduRouteSnapshot *> *)routes {
  id<UIViewControllerTransitionCoordinator> transition = self.controller.transitionCoordinator;
  if (transition != nil || self.waiting) {
    self.pending = routes;
    if (!self.waiting) {
      self.waiting = YES;
      BOOL registered = [transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        (void)context;
        [self performSelector:@selector(flush) withObject:nil afterDelay:0];
      }];
      if (!registered) [self performSelector:@selector(flush) withObject:nil afterDelay:0];
    }
    return;
  }

  NSMutableArray<PuduPage *> *pages = [NSMutableArray arrayWithCapacity:routes.count];
  BOOL common = YES;
  for (PuduRouteSnapshot *route in routes) {
    NSUInteger index = pages.count;
    common = common && index < self.requested.count && self.requested[index].instance == route.instance;
    PuduPage *page = common ? self.requested[index] : [PuduPage new];
    page.instance = route.instance;
    page.title = route.title;
    [(PuduRouteSurface *)page.view placeBody:route.body fillsArea:[route.body isKindOfClass:PuduScroll.class]];
    [pages addObject:page];
  }
  self.requested = pages;
  self.reported = nil;
  if (self.controller == nil) {
    self.controller = [[UINavigationController alloc] initWithRootViewController:pages.firstObject];
    self.controller.delegate = self;
  }
  if (![self.controller.viewControllers isEqualToArray:pages]) {
    [self.controller setViewControllers:pages animated:self.controller.view.window != nil];
  }
  if (pudu_window.rootViewController != self.controller) pudu_window.rootViewController = self.controller;
}

- (void)navigationController:(UINavigationController *)controller didShowViewController:(UIViewController *)shown animated:(BOOL)animated {
  (void)shown;
  (void)animated;
  NSArray<PuduPage *> *actual = (NSArray<PuduPage *> *)controller.viewControllers;
  if (self.pending != nil || actual.count == 0 || actual.count >= self.requested.count ||
      [actual isEqualToArray:self.reported]) return;
  for (NSUInteger index = 0; index < actual.count; index++) {
    if (actual[index] != self.requested[index]) return;
  }
  self.reported = actual;
  pudu_queue_detail(PUDU_UI_POPPED, self.requested.lastObject.instance, nil, actual.lastObject.instance);
  if (getenv("PUDU_UI_BACK_TEST") != NULL) pudu_queue(PUDU_UI_STOPPED, 0, nil);
}
@end

static PuduNavigation *pudu_navigation;

static void pudu_do_navigation(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  if (count == 0 || count > (reader->length - reader->at) / 12) {
    pudu_stream_defect("invalid navigation route count:", count);
  }
  NSMutableArray<PuduRouteSnapshot *> *routes = [NSMutableArray arrayWithCapacity:count];
  NSMutableSet<NSNumber *> *instances = [NSMutableSet new];
  NSMutableSet<NSNumber *> *nodes = [NSMutableSet new];
  for (uint32_t i = 0; i < count; i++) {
    uint32_t instance = pudu_word(reader);
    uint32_t node = pudu_node_id(reader);
    NSString *title = pudu_text(reader);
    if ([instances containsObject:@(instance)]) pudu_stream_defect("duplicated navigation route:", instance);
    if ([nodes containsObject:@(node)]) pudu_stream_defect("duplicated navigation body:", node);
    if (title == nil) pudu_stream_defect("invalid navigation title for route:", instance);
    [instances addObject:@(instance)];
    [nodes addObject:@(node)];
    PuduRouteSnapshot *route = [PuduRouteSnapshot new];
    route.instance = instance;
    route.title = title;
    route.body = pudu_nodes[node];
    [routes addObject:route];
  }
  if (pudu_navigation == nil) pudu_navigation = [PuduNavigation new];
  [pudu_navigation publish:routes];
}

static void pudu_leave_navigation(void) {
  if (pudu_navigation != nil) {
    pudu_navigation.controller.delegate = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:pudu_navigation];
    pudu_navigation.pending = nil;
    pudu_navigation = nil;
    pudu_window.rootViewController = pudu_plain;
  }
}

static UIView *pudu_visible_body(void) {
  PuduRouteSurface *page = (PuduRouteSurface *)pudu_navigation.controller.topViewController.view;
  return page != nil ? page.body : pudu_shown_root;
}

static BOOL pudu_test_back(void) {
  if (getenv("PUDU_UI_BACK_TEST") == NULL || pudu_navigation == nil) return NO;
  [pudu_navigation.controller popViewControllerAnimated:NO];
  return YES;
}

#endif
