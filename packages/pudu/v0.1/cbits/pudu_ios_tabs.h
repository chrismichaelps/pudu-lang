#ifndef PUDU_IOS_TABS_H
#define PUDU_IOS_TABS_H

/* The tab bar: one navigation stack per tab under a tab bar controller, the
   tab's system symbol as its bar item's image, and at most one page sheet
   over the bar. The program owns the tabs, each tab's routes and the
   selection; a person's tab pick is applied at once and reported as SELECTED,
   and a pop inside a tab is reported as POPPED with the same rule as a single
   stack: once the platform's stack is a strict prefix of the one accepted.
   A programmatic selection or stack change reports nothing. TABS replaces a
   single-stack navigation, and NAVIGATE replaces the tabs. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_navigation.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_stream.h"

/* One tab's stack: its id, its pages by route id, and the route ids last
   accepted, trimmed by reported pops. */
@interface PuduTabStack : NSObject <UINavigationControllerDelegate>
@property (nonatomic) uint32_t tab;
@property (strong, nonatomic) UINavigationController *stack;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, PuduPage *> *pages;
@property (copy, nonatomic) NSArray<NSNumber *> *accepted;
@end
@implementation PuduTabStack
- (void)navigationController:(UINavigationController *)stack didShowViewController:(UIViewController *)shown animated:(BOOL)animated {
  (void)shown;
  (void)animated;
  NSArray<NSNumber *> *ids = pudu_route_ids(stack.viewControllers);
  NSArray<NSNumber *> *accepted = self.accepted;
  if (ids.count > 0 && ids.count < accepted.count && [ids isEqualToArray:[accepted subarrayWithRange:NSMakeRange(0, ids.count)]]) {
    self.accepted = ids;
    pudu_queue(PUDU_UI_POPPED, (NSInteger)accepted.lastObject.unsignedIntValue, nil, ids.lastObject.unsignedIntValue);
  }
}
@end

@interface PuduTabs : NSObject <UITabBarControllerDelegate, UIAdaptivePresentationControllerDelegate>
@property (weak, nonatomic) UIViewController *root;
@property (strong, nonatomic) UITabBarController *bar;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, PuduTabStack *> *stacks;
@property (strong, nonatomic) PuduPage *sheet;
@property (nonatomic) BOOL presenting;
@property (strong, nonatomic) NSDictionary *pending;
@end

@implementation PuduTabs
- (void)want:(NSDictionary *)desired {
  pudu_unqueue(PUDU_UI_POPPED);
  pudu_unqueue(PUDU_UI_DISMISSED);
  pudu_unqueue(PUDU_UI_SELECTED);
  self.pending = desired;
  [self settle];
}

/* Shows the pending tabs once no stack is moving and no sheet is in flight. */
- (void)settle {
  if (self.pending == nil || self.presenting) return;
  for (PuduTabStack *held in self.stacks.allValues) {
    id<UIViewControllerTransitionCoordinator> moving = held.stack.transitionCoordinator;
    if (moving != nil) {
      [moving animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        (void)context;
        dispatch_async(dispatch_get_main_queue(), ^{ [self settle]; });
      }];
      return;
    }
  }
  NSDictionary *desired = self.pending;
  NSMutableDictionary<NSNumber *, PuduTabStack *> *stacks = [NSMutableDictionary new];
  NSMutableArray<UINavigationController *> *controllers = [NSMutableArray new];
  NSUInteger selected = 0;
  self.pending = nil;
  for (NSDictionary *tab in desired[@"tabs"]) {
    PuduTabStack *held = self.stacks[tab[@"id"]];
    if (held == nil) {
      held = [PuduTabStack new];
      held.tab = [tab[@"id"] unsignedIntValue];
      held.stack = [UINavigationController new];
      held.stack.delegate = held;
      held.pages = [NSMutableDictionary new];
    }
    NSMutableDictionary<NSNumber *, PuduPage *> *pages = [NSMutableDictionary new];
    NSMutableArray<PuduPage *> *routes = [NSMutableArray new];
    for (NSArray *entry in tab[@"routes"]) {
      PuduPage *page = held.pages[entry[0]] ?: [PuduPage new];
      page.route = [entry[0] unsignedIntValue];
      [page show:entry[1] fills:[entry[2] boolValue]];
      page.navigationItem.title = entry[3];
      pages[entry[0]] = page;
      [routes addObject:page];
    }
    held.pages = pages;
    held.accepted = pudu_route_ids(routes);
    if (![held.stack.viewControllers isEqualToArray:routes]) {
      [held.stack setViewControllers:routes animated:held.stack.viewControllers.count > 0];
    }
    held.stack.tabBarItem.title = tab[@"title"];
    held.stack.tabBarItem.image = [UIImage systemImageNamed:tab[@"symbol"]];
    if ([tab[@"id"] isEqual:desired[@"selected"]]) selected = controllers.count;
    stacks[tab[@"id"]] = held;
    [controllers addObject:held.stack];
  }
  self.stacks = stacks;
  if (![self.bar.viewControllers isEqualToArray:controllers]) [self.bar setViewControllers:controllers animated:NO];
  self.bar.selectedIndex = selected;
  [self present:desired[@"sheet"]];
}

/* A person's pick; a programmatic selection never reaches this. */
- (void)tabBarController:(UITabBarController *)bar didSelectViewController:(UIViewController *)picked {
  (void)bar;
  for (PuduTabStack *held in self.stacks.allValues) {
    if (held.stack == picked) pudu_queue(PUDU_UI_SELECTED, held.tab, nil, 0);
  }
}

/* Keeps, replaces, presents or closes the sheet over the bar. */
- (void)present:(id)wanted {
  NSArray *entry = wanted == [NSNull null] ? nil : wanted;
  PuduPage *current = self.sheet;
  if (current != nil && entry != nil && current.route == [entry[0] unsignedIntValue]) {
    [current show:entry[1] fills:[entry[2] boolValue]];
    return;
  }
  if (current == nil && entry == nil) return;
  PuduPage *next = nil;
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
  if (gone != self.sheet) return;
  self.sheet = nil;
  pudu_queue(PUDU_UI_DISMISSED, gone.route, nil, 0);
  [self settle];
}
@end

static PuduTabs *pudu_tabs;

/* Removes a controller shown inside the root, if any. */
static void pudu_detach_child(UIViewController *child) {
  if (child == nil) return;
  [child willMoveToParentViewController:nil];
  [child.view removeFromSuperview];
  [child removeFromParentViewController];
}

/* Ends the tabs, for a NAVIGATE or a ROOT that replaces them. */
static void pudu_tabs_close(void) {
  if (pudu_tabs == nil) return;
  pudu_detach_child(pudu_tabs.bar);
  pudu_tabs = nil;
}

/* Reads a TABS whole and refuses what cannot be shown before anything changes. */
static NSDictionary *pudu_tabs_read(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  NSMutableArray<NSDictionary *> *tabs = [NSMutableArray new];
  NSMutableSet<NSNumber *> *tabIds = [NSMutableSet new], *routeIds = [NSMutableSet new];
  id sheet = [NSNull null];
  if (count == 0) pudu_stream_defect("showed a tab bar without tabs, count", count);
  for (uint32_t i = 0; i < count; i++) {
    uint32_t tab = pudu_word(reader);
    NSString *title = pudu_text(reader), *symbol = pudu_text(reader);
    uint32_t pages = pudu_word(reader);
    NSMutableArray<NSArray *> *routes = [NSMutableArray new];
    if ([tabIds containsObject:@(tab)]) pudu_stream_defect("showed two tabs with id", tab);
    if (pages == 0) pudu_stream_defect("showed a tab without a root route, tab", tab);
    [tabIds addObject:@(tab)];
    for (uint32_t j = 0; j < pages; j++) {
      uint32_t route = pudu_word(reader);
      BOOL fills = NO;
      UIView *body = pudu_navigation_body(reader, &fills);
      NSString *named = pudu_text(reader);
      if ([routeIds containsObject:@(route)]) pudu_stream_defect("showed two routes with id", route);
      [routeIds addObject:@(route)];
      [routes addObject:@[ @(route), body, @(fills), named ]];
    }
    [tabs addObject:@{ @"id" : @(tab), @"title" : title, @"symbol" : symbol, @"routes" : routes }];
  }
  uint32_t selected = pudu_word(reader);
  if (![tabIds containsObject:@(selected)]) pudu_stream_defect("selected a tab that is not shown:", selected);
  uint32_t present = pudu_word(reader);
  if (present > 1) pudu_stream_defect("marked a sheet with", present);
  if (present == 1) {
    uint32_t route = pudu_word(reader);
    BOOL fills = NO;
    UIView *body = pudu_navigation_body(reader, &fills);
    if ([routeIds containsObject:@(route)]) pudu_stream_defect("showed a sheet sharing a route's id", route);
    sheet = @[ @(route), body, @(fills) ];
  }
  return @{ @"tabs" : tabs, @"selected" : @(selected), @"sheet" : sheet };
}

/* Installs the tab bar over the root on first use, replacing a single stack,
   then shows `desired`. */
static void pudu_tabs_show(UIViewController *root, NSDictionary *desired) {
  if (pudu_tabs == nil) {
    if (pudu_navigator != nil) {
      pudu_detach_child(pudu_navigator.stack);
      pudu_navigator = nil;
    }
    pudu_tabs = [PuduTabs new];
    pudu_tabs.root = root;
    pudu_tabs.stacks = [NSMutableDictionary new];
    pudu_tabs.bar = [UITabBarController new];
    pudu_tabs.bar.delegate = pudu_tabs;
    [root addChildViewController:pudu_tabs.bar];
    pudu_tabs.bar.view.frame = root.view.bounds;
    pudu_tabs.bar.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root.view addSubview:pudu_tabs.bar.view];
    [pudu_tabs.bar didMoveToParentViewController:root];
  }
  [pudu_tabs want:desired];
}

/* The body on top of the screen: the sheet's, otherwise the selected tab's top page's. */
static UIView *pudu_tabs_top(void) {
  if (pudu_tabs.sheet != nil) return pudu_tabs.sheet.body;
  UINavigationController *stack = (UINavigationController *)pudu_tabs.bar.selectedViewController;
  return ((PuduPage *)stack.topViewController).body;
}

/* Self-test against the Tabs example: the person picks the second tab and
   back, pushes and pops inside the first, and dismisses a sheet. */
static void pudu_test_tabs(void (^done)(void)) {
  __block int step = 0;
  CFTimeInterval deadline = CACurrentMediaTime() + 30;
  [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
    PuduTabs *tabs = pudu_tabs;
    UITabBarController *bar = tabs.bar;
    UINavigationController *first = bar.viewControllers.firstObject;
    if (CACurrentMediaTime() >= deadline) {
      fprintf(stderr, "pudu: tabs test timed out at step %d\n", step);
      [timer invalidate];
      done();
      return;
    }
    if (tabs == nil || first.transitionCoordinator != nil || tabs.presenting || tabs.pending != nil || pudu_events.count > 0) return;
    UIView *home = first.viewControllers.firstObject.view;
    PuduPage *sheet = tabs.sheet;
    BOOL sheetShown = sheet != nil && sheet.presentingViewController != nil && !sheet.isBeingPresented;
    if (step == 0 && bar.viewControllers.count == 2) {
      bar.selectedIndex = 1;
      [tabs tabBarController:bar didSelectViewController:bar.viewControllers[1]];
      step = 1;
    } else if (step == 1 && bar.selectedIndex == 1 && pudu_shows_text(home, @"Selected: 2")) {
      puts("PUDU_TABS picked");
      bar.selectedIndex = 0;
      [tabs tabBarController:bar didSelectViewController:first];
      step = 2;
    } else if (step == 2 && bar.selectedIndex == 0 && pudu_shows_text(home, @"Selected: 1")) {
      pudu_button_press(pudu_find_button(pudu_tabs_top(), @"Open"));
      step = 3;
    } else if (step == 3 && first.viewControllers.count == 2) {
      puts("PUDU_TABS pushed");
      [first popViewControllerAnimated:YES];
      step = 4;
    } else if (step == 4 && first.viewControllers.count == 1 && pudu_shows_text(home, @"Pops: 1")) {
      puts("PUDU_TABS popped once");
      pudu_button_press(pudu_find_button(pudu_tabs_top(), @"Show sheet"));
      step = 5;
    } else if (step == 5 && sheetShown) {
      [sheet dismissViewControllerAnimated:YES completion:^{ [tabs presentationControllerDidDismiss:sheet.presentationController]; }];
      step = 6;
    } else if (step == 6 && sheet == nil && pudu_shows_text(home, @"Dismissals: 1")) {
      puts("PUDU_TABS sheet dismissed once");
      fflush(stdout);
      [timer invalidate];
      done();
    }
  }];
}

#endif
