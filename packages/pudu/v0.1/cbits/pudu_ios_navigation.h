#ifndef PUDU_IOS_NAVIGATION_H
#define PUDU_IOS_NAVIGATION_H

/* The native page stack and page sheet. The program owns which routes exist:
   NAVIGATE names them root first, each with its body node and title, then the
   sheet. UIKit draws the bars, back affordances and transitions.

   The accepted stack is the program's last presentation, trimmed by user pops
   already reported. A pop is reported once the platform's final stack is a
   strict prefix of it; a programmatic change sets it before UIKit animates,
   so its completion compares equal and reports nothing, as does a cancelled
   swipe. A sheet's dismissal is reported once UIKit confirms a user
   dismissal, and only for the sheet still current. A newer NAVIGATE
   supersedes reports the program has not read, and an update that arrives
   during a transition waits for it to end. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_controls.h"
#include "pudu_ios_events.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_layout.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_stream.h"

/* One route's page: the route's body under the platform's bars, laid out with
   the screen's safe-area and docked-keyboard policy. */
@interface PuduPage : UIViewController
@property (nonatomic) uint32_t route;
@property (strong, nonatomic) UIView *body;
@property (strong, nonatomic) UILayoutGuide *area;
- (void)show:(UIView *)body fills:(BOOL)fills;
@end
@implementation PuduPage
- (void)show:(UIView *)body fills:(BOOL)fills {
  if (body == self.body) return;
  UIView *view = self.view;
  if (self.area == nil) {
    view.backgroundColor = UIColor.systemBackgroundColor;
    self.area = pudu_available_area(view);
  }
  if (self.body.superview == view) [self.body removeFromSuperview];
  self.body = body;
  [body removeFromSuperview];
  body.translatesAutoresizingMaskIntoConstraints = NO;
  [view addSubview:body];
  pudu_place_root(body, self.area, fills);
}
@end

static NSArray<NSNumber *> *pudu_route_ids(NSArray<UIViewController *> *controllers) {
  NSMutableArray<NSNumber *> *ids = [NSMutableArray new];
  for (UIViewController *controller in controllers) [ids addObject:@(((PuduPage *)controller).route)];
  return ids;
}

/* The controller a new presentation goes over. */
static UIViewController *pudu_topmost(UIViewController *controller) {
  while (controller.presentedViewController != nil && !controller.presentedViewController.isBeingDismissed) {
    controller = controller.presentedViewController;
  }
  return controller;
}

@interface PuduNavigator : NSObject <UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate>
@property (weak, nonatomic) UIViewController *root;
@property (strong, nonatomic) UINavigationController *stack;
/* Pages by route id: the last presentation's, kept until the next one so a
   refused pop shows the same controllers again. */
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, PuduPage *> *pages;
@property (copy, nonatomic) NSArray<NSNumber *> *accepted;
@property (strong, nonatomic) PuduPage *sheet;
/* A sheet presentation or dismissal is in flight. */
@property (nonatomic) BOOL presenting;
/* The newest presentation not yet shown. */
@property (strong, nonatomic) NSDictionary *pending;
@end

@implementation PuduNavigator
- (PuduPage *)page:(NSArray *)entry {
  PuduPage *page = self.pages[entry[0]] ?: [PuduPage new];
  page.route = [entry[0] unsignedIntValue];
  [page show:entry[1] fills:[entry[2] boolValue]];
  return page;
}

- (void)want:(NSDictionary *)desired {
  pudu_unqueue(PUDU_UI_POPPED);
  pudu_unqueue(PUDU_UI_DISMISSED);
  self.pending = desired;
  [self settle];
}

/* Shows the pending presentation once no transition is in flight. */
- (void)settle {
  id<UIViewControllerTransitionCoordinator> moving = self.stack.transitionCoordinator;
  if (self.pending == nil || self.presenting) return;
  if (moving != nil) {
    [moving animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
      (void)context;
      dispatch_async(dispatch_get_main_queue(), ^{ [self settle]; });
    }];
    return;
  }
  NSDictionary *desired = self.pending;
  NSMutableDictionary<NSNumber *, PuduPage *> *pages = [NSMutableDictionary new];
  NSMutableArray<PuduPage *> *controllers = [NSMutableArray new];
  self.pending = nil;
  for (NSArray *entry in desired[@"routes"]) {
    PuduPage *page = [self page:entry];
    page.navigationItem.title = entry[3];
    pages[entry[0]] = page;
    [controllers addObject:page];
  }
  self.pages = pages;
  self.accepted = pudu_route_ids(controllers);
  if (![self.stack.viewControllers isEqualToArray:controllers]) {
    [self.stack setViewControllers:controllers animated:self.stack.viewControllers.count > 0];
  }
  [self present:desired[@"sheet"]];
}

/* Keeps, replaces, presents or closes the sheet. A replacement is presented
   once the old sheet has finished dismissing. */
- (void)present:(id)wanted {
  NSArray *entry = wanted == [NSNull null] ? nil : wanted;
  PuduPage *current = self.sheet;
  PuduPage *next = nil;
  if (current != nil && entry != nil && current.route == [entry[0] unsignedIntValue]) {
    [current show:entry[1] fills:[entry[2] boolValue]];
    return;
  }
  if (current == nil && entry == nil) return;
  if (entry != nil) {
    next = [PuduPage new];
    next.route = [entry[0] unsignedIntValue];
    [next show:entry[1] fills:[entry[2] boolValue]];
    next.modalPresentationStyle = UIModalPresentationPageSheet;
    next.presentationController.delegate = self;
  }
  self.sheet = next;
  self.presenting = YES;
  void (^shown)(void) = ^{
    if (next == nil) {
      self.presenting = NO;
      [self settle];
      return;
    }
    [pudu_topmost(self.root) presentViewController:next animated:YES completion:^{
      self.presenting = NO;
      pudu_alert_presenter = next;
      [self settle];
    }];
  };
  if (current != nil && current.presentingViewController != nil) {
    [current dismissViewControllerAnimated:YES completion:^{
      pudu_alert_presenter = self.root;
      shown();
    }];
  } else {
    shown();
  }
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentation {
  PuduPage *gone = (PuduPage *)presentation.presentedViewController;
  if (pudu_alert_presenter == gone) pudu_alert_presenter = self.root;
  /* A late report about an earlier sheet cannot close its replacement. */
  if (gone != self.sheet) return;
  self.sheet = nil;
  pudu_queue(PUDU_UI_DISMISSED, gone.route, nil, 0);
  [self settle];
}

- (void)navigationController:(UINavigationController *)stack didShowViewController:(UIViewController *)shown animated:(BOOL)animated {
  (void)shown;
  (void)animated;
  NSArray<NSNumber *> *ids = pudu_route_ids(stack.viewControllers);
  NSArray<NSNumber *> *accepted = self.accepted;
  /* A pending presentation already asked for a destination; the user's
     transition it overtook is not reported. */
  if (self.pending == nil && ids.count > 0 && ids.count < accepted.count &&
      [ids isEqualToArray:[accepted subarrayWithRange:NSMakeRange(0, ids.count)]]) {
    self.accepted = ids;
    pudu_queue(PUDU_UI_POPPED, (NSInteger)accepted.lastObject.unsignedIntValue, nil, ids.lastObject.unsignedIntValue);
  }
  [self settle];
}
@end

static PuduNavigator *pudu_navigator;

/* A route's body node: its view and whether it fills the page. */
static UIView *pudu_navigation_body(pudu_reader *reader, BOOL *fills) {
  uint32_t node = pudu_node_id(reader);
  *fills = pudu_node_scrolls(node);
  return pudu_nodes[node];
}

/* Reads a NAVIGATE whole and refuses repeated ids before anything changes. */
static NSDictionary *pudu_navigation_read(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  NSMutableArray<NSArray *> *routes = [NSMutableArray new];
  NSMutableSet<NSNumber *> *ids = [NSMutableSet new];
  id sheet = [NSNull null];
  if (count == 0) pudu_stream_defect("showed a navigation without a root route, count", count);
  for (uint32_t i = 0; i < count; i++) {
    uint32_t route = pudu_word(reader);
    BOOL fills = NO;
    UIView *body = pudu_navigation_body(reader, &fills);
    NSString *title = pudu_text(reader);
    if ([ids containsObject:@(route)]) pudu_stream_defect("showed two routes with id", route);
    [ids addObject:@(route)];
    [routes addObject:@[ @(route), body, @(fills), title ]];
  }
  uint32_t present = pudu_word(reader);
  if (present > 1) pudu_stream_defect("marked a sheet with", present);
  if (present == 1) {
    uint32_t route = pudu_word(reader);
    BOOL fills = NO;
    UIView *body = pudu_navigation_body(reader, &fills);
    if ([ids containsObject:@(route)]) pudu_stream_defect("showed a sheet sharing a route's id", route);
    sheet = @[ @(route), body, @(fills) ];
  }
  return @{ @"routes" : routes, @"sheet" : sheet };
}

/* Installs the platform stack over the root controller on first use, then
   shows `desired`. */
static void pudu_navigation_show(UIViewController *root, NSDictionary *desired) {
  if (pudu_navigator == nil) {
    UINavigationController *stack = [UINavigationController new];
    pudu_navigator = [PuduNavigator new];
    pudu_navigator.root = root;
    pudu_navigator.accepted = @[];
    pudu_navigator.stack = stack;
    stack.delegate = pudu_navigator;
    [root addChildViewController:stack];
    stack.view.frame = root.view.bounds;
    stack.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root.view addSubview:stack.view];
    [stack didMoveToParentViewController:root];
  }
  [pudu_navigator want:desired];
}

/* The body on top of the screen: the sheet's, otherwise the top page's. */
static UIView *pudu_navigation_top(void) {
  if (pudu_navigator.sheet != nil) return pudu_navigator.sheet.body;
  return ((PuduPage *)pudu_navigator.stack.topViewController).body;
}

static UIButton *pudu_find_button(UIView *view, NSString *title) {
  if ([view isKindOfClass:UIButton.class] && [((UIButton *)view).currentTitle isEqualToString:title]) return (UIButton *)view;
  for (UIView *child in view.subviews) {
    UIButton *found = pudu_find_button(child, title);
    if (found != nil) return found;
  }
  return nil;
}

static BOOL pudu_shows_text(UIView *view, NSString *text) {
  if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text isEqualToString:text]) return YES;
  for (UIView *child in view.subviews) {
    if (pudu_shows_text(child, text)) return YES;
  }
  return NO;
}

/* Self-test against the Pages example: a push, a back action the program
   applies, a sheet the user dismisses, then a sheet the program closes, which
   must not count as a dismissal. Each step waits for the platform and the
   program to settle. `done` asks the program to stop. */
static void pudu_test_navigation(void (^done)(void)) {
  __block int step = 0;
  CFTimeInterval deadline = CACurrentMediaTime() + 30;
  [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
    PuduNavigator *navigator = pudu_navigator;
    UINavigationController *stack = navigator.stack;
    if (CACurrentMediaTime() >= deadline) {
      fprintf(stderr, "pudu: navigation test timed out at step %d\n", step);
      [timer invalidate];
      done();
      return;
    }
    if (navigator == nil || stack.transitionCoordinator != nil || navigator.presenting || navigator.pending != nil || pudu_events.count > 0) return;
    UIView *home = stack.viewControllers.firstObject.view;
    UIView *top = pudu_navigation_top();
    PuduPage *sheet = navigator.sheet;
    BOOL sheetShown = sheet != nil && sheet.presentingViewController != nil && !sheet.isBeingPresented;
    if (step == 0 && stack.viewControllers.count == 1) {
      pudu_button_press(pudu_find_button(top, @"Open"));
      step = 1;
    } else if (step == 1 && stack.viewControllers.count == 2) {
      puts("PUDU_NAV pushed");
      [stack popViewControllerAnimated:YES];
      step = 2;
    } else if (step == 2 && stack.viewControllers.count == 1 && pudu_shows_text(home, @"Pops: 1")) {
      puts("PUDU_NAV popped once");
      pudu_button_press(pudu_find_button(top, @"Show sheet"));
      step = 3;
    } else if (step == 3 && sheetShown) {
      puts("PUDU_NAV sheet shown");
      [sheet dismissViewControllerAnimated:YES completion:^{
        [navigator presentationControllerDidDismiss:sheet.presentationController];
      }];
      step = 4;
    } else if (step == 4 && sheet == nil && pudu_shows_text(home, @"Dismissals: 1")) {
      puts("PUDU_NAV sheet dismissed once");
      pudu_button_press(pudu_find_button(top, @"Show sheet"));
      step = 5;
    } else if (step == 5 && sheetShown) {
      pudu_button_press(pudu_find_button(sheet.view, @"Close"));
      step = 6;
    } else if (step == 6 && sheet == nil && pudu_shows_text(home, @"Dismissals: 1")) {
      puts("PUDU_NAV sheet closed without echo");
      fflush(stdout);
      [timer invalidate];
      done();
    }
  }];
}

#endif
