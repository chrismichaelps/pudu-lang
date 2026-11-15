#ifndef PUDU_IOS_LIST_H
#define PUDU_IOS_LIST_H

/* Recycling lists and grids of the iOS host. The platform owns cells and
   scrolling; Pudu supplies a keyed window of row views starting at item
   `first`. The cell showing item i hosts window row i - first. When the
   visible range nears an edge of the window the host reports the first
   visible index, and the program answers with a shifted window. */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>

static NSUInteger pudu_cells_made;
static const char pudu_store_key = 0;

/* The ordered window rows of a list. It never displays them: placement
   instructions keep their meaning while cells host the views. */
@interface PuduRowStore : UIStackView
@property (strong, nonatomic) NSMutableArray<UIView *> *ordered;
@property (copy, nonatomic) void (^changed)(void);
- (void)forget:(UIView *)row;
@end
@implementation PuduRowStore
- (NSArray<UIView *> *)arrangedSubviews { return self.ordered; }
- (void)addArrangedSubview:(UIView *)row { [self insertArrangedSubview:row atIndex:self.ordered.count]; }
- (void)insertArrangedSubview:(UIView *)row atIndex:(NSUInteger)index {
  [self.ordered removeObjectIdenticalTo:row];
  [self.ordered insertObject:row atIndex:MIN(index, self.ordered.count)];
  objc_setAssociatedObject(row, &pudu_store_key, self, OBJC_ASSOCIATION_ASSIGN);
  self.changed();
}
- (void)forget:(UIView *)row {
  [self.ordered removeObjectIdenticalTo:row];
  objc_setAssociatedObject(row, &pudu_store_key, nil, OBJC_ASSOCIATION_ASSIGN);
  self.changed();
}
@end

@interface PuduCell : UICollectionViewCell
@property (weak, nonatomic) UIView *hosted;
@end
@implementation PuduCell
- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  pudu_cells_made++;
  return self;
}
/* Shows `row`, or nothing, pinned to the content edges. */
- (void)host:(UIView *)row {
  if (self.hosted == row && row.superview == self.contentView) return;
  if (self.hosted.superview == self.contentView) [self.hosted removeFromSuperview];
  self.hosted = row;
  if (row == nil) return;
  [row removeFromSuperview];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:row];
  [NSLayoutConstraint activateConstraints:@[
    [row.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
    [row.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
    [row.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
    [row.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-8],
  ]];
}
@end

@interface PuduList : UICollectionView <UICollectionViewDataSource>
@property (strong, nonatomic) PuduRowStore *store;
@property (nonatomic) uint32_t total, first, columns;
@property (nonatomic) BOOL stale;
@property (nonatomic) NSInteger reported;
/* Queues a Reached event with the list's tag and the first visible index. */
@property (copy, nonatomic) void (^reach)(NSInteger tag, uint32_t visible);
@end

/* Every list whose rows, range or columns changed during this commit. */
static NSMutableSet<PuduList *> *pudu_stale_lists;

static UICollectionViewLayout *pudu_grid_layout(uint32_t columns) {
  CGFloat share = 1.0 / (columns == 0 ? 1 : columns);
  NSCollectionLayoutSize *size = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:share]
                                                                heightDimension:[NSCollectionLayoutDimension estimatedDimension:44]];
  NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:size];
  NSCollectionLayoutSize *across = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                                                                  heightDimension:[NSCollectionLayoutDimension estimatedDimension:44]];
  NSCollectionLayoutGroup *row = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:across subitem:item count:columns == 0 ? 1 : columns];
  return [[UICollectionViewCompositionalLayout alloc] initWithSection:[NSCollectionLayoutSection sectionWithGroup:row]];
}

@implementation PuduList
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
  (void)view;
  (void)section;
  return self.total;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path {
  PuduCell *cell = [view dequeueReusableCellWithReuseIdentifier:@"row" forIndexPath:path];
  NSInteger local = path.item - (NSInteger)self.first;
  [cell host:local >= 0 && local < (NSInteger)self.store.ordered.count ? self.store.ordered[local] : nil];
  return cell;
}
/* After every scroll and layout pass: reports the first visible index when
   the visible range comes within a quarter window of an edge the window does
   not already touch. */
- (void)layoutSubviews {
  [super layoutSubviews];
  NSInteger low = NSIntegerMax, high = -1;
  for (NSIndexPath *path in self.indexPathsForVisibleItems) {
    low = MIN(low, path.item);
    high = MAX(high, path.item);
  }
  /* The margin never exceeds what the window holds beyond the visible span,
     so a window too small for the screen cannot alternate between edges. */
  NSInteger count = (NSInteger)self.store.ordered.count;
  NSInteger margin = MAX(0, MIN(count / 4, (count - (high - low + 1)) / 2));
  NSInteger start = self.first, end = start + count;
  BOOL early = start > 0 && low < start + margin;
  BOOL late = end < (NSInteger)self.total && high >= end - margin;
  if (high < 0 || !(early || late) || low == self.reported) return;
  self.reported = low;
  self.reach(self.tag, (uint32_t)low);
}
@end

static void pudu_list_reload(void) {
  for (PuduList *list in pudu_stale_lists) [list reloadData];
  [pudu_stale_lists removeAllObjects];
}

/* A list making its cells through `reach`. */
static UIView *pudu_list_make(void (^reach)(NSInteger, uint32_t)) {
  PuduList *list = [[PuduList alloc] initWithFrame:CGRectZero collectionViewLayout:pudu_grid_layout(1)];
  __weak PuduList *weak = list;
  if (pudu_stale_lists == nil) pudu_stale_lists = [NSMutableSet new];
  list.columns = 1;
  list.reported = -1;
  list.reach = reach;
  list.backgroundColor = UIColor.clearColor;
  list.dataSource = list;
  [list registerClass:PuduCell.class forCellWithReuseIdentifier:@"row"];
  list.store = [PuduRowStore new];
  list.store.ordered = [NSMutableArray new];
  list.store.changed = ^{ if (weak != nil) [pudu_stale_lists addObject:weak]; };
  return list;
}

static UIStackView *pudu_list_store(UIView *view) { return ((PuduList *)view).store; }

static void pudu_list_range(UIView *view, uint32_t total, uint32_t first) {
  PuduList *list = (PuduList *)view;
  list.total = total;
  list.first = first;
  list.reported = -1;
  list.store.changed();
}

static void pudu_list_columns(UIView *view, uint32_t columns) {
  PuduList *list = (PuduList *)view;
  list.columns = columns;
  [list setCollectionViewLayout:pudu_grid_layout(columns) animated:NO];
  list.store.changed();
}

/* Drops a removed row from the store holding it, if any. */
static void pudu_list_forget(UIView *row) {
  PuduRowStore *store = objc_getAssociatedObject(row, &pudu_store_key);
  [store forget:row];
}

/* Self-test: scrolls the first list to its last item, waits until that
   item's cell shows a label, and reports it and whether fewer cells than a fifth of the items were ever made. */
static void pudu_test_list(NSArray *nodes, void (^done)(void)) {
  PuduList *list = nil;
  for (NSObject *node in nodes) {
    if (list == nil && [node isKindOfClass:PuduList.class]) list = (PuduList *)node;
  }
  if (list == nil || list.total == 0) {
    done();
    return;
  }
  NSIndexPath *last = [NSIndexPath indexPathForItem:list.total - 1 inSection:0];
  CFTimeInterval deadline = CACurrentMediaTime() + 20;
  [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
    [list scrollToItemAtIndexPath:last atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
    [list layoutIfNeeded];
    PuduCell *cell = (PuduCell *)[list cellForItemAtIndexPath:last];
    if ([cell.hosted isKindOfClass:UILabel.class]) {
      printf("PUDU_LIST reached %s\n", ((UILabel *)cell.hosted).text.UTF8String);
      if (pudu_cells_made < list.total / 5) puts("PUDU_LIST reused");
      printf("PUDU_CELLS %lu of %u items\n", (unsigned long)pudu_cells_made, list.total);
    } else if (CACurrentMediaTime() < deadline) {
      return;
    } else {
      fprintf(stderr, "pudu: list test timed out (first=%u rows=%lu cells=%lu)\n", list.first,
              (unsigned long)list.store.ordered.count, (unsigned long)pudu_cells_made);
    }
    fflush(stdout);
    [timer invalidate];
    done();
  }];
}

#endif
