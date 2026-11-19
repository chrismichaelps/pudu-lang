#ifndef PUDU_IOS_VALUES_H
#define PUDU_IOS_VALUES_H

/* Controls that hold a value: slider, stepper, segmented control, wheel,
   date picker, text area, search field, symbol, page indicator and color
   well. Values cross the stream as exact integers. A slider runs in step
   indexes, so the value it reports is always low + index * step whatever its
   range. Each control reports the person's change as one event; a value the
   program sets reports nothing. */
#import <UIKit/UIKit.h>
#include <math.h>
#include <stdint.h>
#include "pudu_ios_controls.h"
#include "pudu_ios_events.h"

enum { PUDU_MOMENTS = 3 };

/* A slider over whole steps: its track runs from index 0 to the step count. */
@interface PuduSlider : UISlider
@property (nonatomic) int64_t low;
@property (nonatomic) int64_t step;
@property (nonatomic) NSInteger index;
@end
@implementation PuduSlider
@end

/* A one-column wheel over the labels the program gave it. */
@interface PuduWheel : UIPickerView <UIPickerViewDataSource, UIPickerViewDelegate>
@property (copy, nonatomic) NSArray<NSString *> *labels;
@end
@implementation PuduWheel
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)view { (void)view; return 1; }
- (NSInteger)pickerView:(UIPickerView *)view numberOfRowsInComponent:(NSInteger)component {
  (void)view;
  (void)component;
  return (NSInteger)self.labels.count;
}
- (NSString *)pickerView:(UIPickerView *)view titleForRow:(NSInteger)row forComponent:(NSInteger)component {
  (void)view;
  (void)component;
  return self.labels[(NSUInteger)row];
}
- (void)pickerView:(UIPickerView *)view didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
  (void)view;
  (void)component;
  pudu_queue(PUDU_UI_VALUED, self.tag, nil, (uint32_t)row);
}
@end

/* A text area reports each edit as a field does. */
@interface PuduTextArea : UITextView <UITextViewDelegate>
@end
@implementation PuduTextArea
- (void)textViewDidChange:(UITextView *)view { pudu_queue(PUDU_UI_CHANGED, view.tag, view.text, 0); }
@end

@interface PuduValueTarget : NSObject
- (void)slid:(PuduSlider *)sender;
- (void)stepped:(UIStepper *)sender;
- (void)segmented:(UISegmentedControl *)sender;
- (void)dated:(UIDatePicker *)sender;
- (void)paged:(UIPageControl *)sender;
- (void)colored:(UIColorWell *)sender;
@end
@implementation PuduValueTarget
/* The thumb settles on the nearest index; an unchanged index reports nothing. */
- (void)slid:(PuduSlider *)sender {
  NSInteger index = (NSInteger)lroundf(sender.value);
  sender.value = (float)index;
  if (index == sender.index) return;
  sender.index = index;
  pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)(int32_t)(sender.low + (int64_t)index * sender.step));
}
- (void)stepped:(UIStepper *)sender { pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)(int32_t)llround(sender.value)); }
- (void)segmented:(UISegmentedControl *)sender {
  if (sender.selectedSegmentIndex >= 0) pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)sender.selectedSegmentIndex);
}
/* Whole seconds since the epoch, as the high and low words. */
- (void)dated:(UIDatePicker *)sender {
  int64_t seconds = (int64_t)floor(sender.date.timeIntervalSince1970);
  pudu_queue_words(PUDU_UI_DATED, sender.tag, nil, 0, @[ @((int32_t)(seconds >> 32)), @((int32_t)(uint32_t)seconds) ]);
}
- (void)paged:(UIPageControl *)sender { pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)sender.currentPage); }
- (void)colored:(UIColorWell *)sender {
  CGFloat red = 0, green = 0, blue = 0, alpha = 0;
  [sender.selectedColor getRed:&red green:&green blue:&blue alpha:&alpha];
  uint32_t rgba = (uint32_t)lround(red * 255) << 24 | (uint32_t)lround(green * 255) << 16 | (uint32_t)lround(blue * 255) << 8 |
                  (uint32_t)lround(alpha * 255);
  pudu_queue(PUDU_UI_COLORED, sender.tag, nil, rgba);
}
@end
static PuduValueTarget *pudu_value_target;

static PuduValueTarget *pudu_values_target(void) {
  if (pudu_value_target == nil) pudu_value_target = [PuduValueTarget new];
  return pudu_value_target;
}

/* Factories. */
static UIView *pudu_make_slider(void) {
  PuduSlider *slider = [PuduSlider new];
  slider.step = 1;
  slider.minimumValue = 0;
  slider.maximumValue = 0;
  [slider.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  [slider addTarget:pudu_values_target() action:@selector(slid:) forControlEvents:UIControlEventValueChanged];
  return slider;
}

static UIView *pudu_make_stepper(void) {
  UIStepper *stepper = [UIStepper new];
  [stepper addTarget:pudu_values_target() action:@selector(stepped:) forControlEvents:UIControlEventValueChanged];
  return stepper;
}

static UIView *pudu_make_segments(void) {
  UISegmentedControl *segments = [UISegmentedControl new];
  [segments addTarget:pudu_values_target() action:@selector(segmented:) forControlEvents:UIControlEventValueChanged];
  return segments;
}

static UIView *pudu_make_wheel(void) {
  PuduWheel *wheel = [PuduWheel new];
  wheel.labels = @[];
  wheel.dataSource = wheel;
  wheel.delegate = wheel;
  return wheel;
}

static UIView *pudu_make_date(void) {
  UIDatePicker *picker = [UIDatePicker new];
  picker.preferredDatePickerStyle = UIDatePickerStyleCompact;
  [picker addTarget:pudu_values_target() action:@selector(dated:) forControlEvents:UIControlEventValueChanged];
  return picker;
}

static UIView *pudu_make_text_area(void) {
  PuduTextArea *area = [PuduTextArea new];
  area.delegate = area;
  area.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  area.adjustsFontForContentSizeCategory = YES;
  area.layer.cornerRadius = 8;
  area.layer.borderWidth = 1;
  area.layer.borderColor = UIColor.separatorColor.CGColor;
  [area.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  [area.heightAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;
  return area;
}

static UIView *pudu_make_search(void) {
  UISearchTextField *search = [UISearchTextField new];
  [search.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  [search addTarget:pudu_target action:@selector(focused:) forControlEvents:UIControlEventEditingDidBegin];
  [search addTarget:pudu_target action:@selector(edited:) forControlEvents:UIControlEventEditingChanged];
  return search;
}

static UIView *pudu_make_symbol(void) {
  UIImageView *symbol = [UIImageView new];
  symbol.contentMode = UIViewContentModeScaleAspectFit;
  symbol.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleTitle1];
  return symbol;
}

static UIView *pudu_make_pages(void) {
  UIPageControl *pages = [UIPageControl new];
  pages.pageIndicatorTintColor = UIColor.tertiaryLabelColor;
  pages.currentPageIndicatorTintColor = UIColor.labelColor;
  [pages addTarget:pudu_values_target() action:@selector(paged:) forControlEvents:UIControlEventValueChanged];
  return pages;
}

static UIView *pudu_make_well(void) {
  UIColorWell *well = [UIColorWell new];
  well.supportsAlpha = YES;
  [well addTarget:pudu_values_target() action:@selector(colored:) forControlEvents:UIControlEventValueChanged];
  return well;
}

/* BOUNDS setters; the host has refused an inverted range or a step below one. */
static void pudu_slider_bounds(UIView *view, int32_t low, int32_t high, int32_t step) {
  PuduSlider *slider = (PuduSlider *)view;
  slider.low = low;
  slider.step = step;
  slider.maximumValue = (float)(((int64_t)high - low) / step);
}

static void pudu_stepper_bounds(UIView *view, int32_t low, int32_t high, int32_t step) {
  UIStepper *stepper = (UIStepper *)view;
  stepper.minimumValue = low;
  stepper.maximumValue = high;
  stepper.stepValue = step;
}

/* OPTIONS setters; the host has refused an empty list. A new list leaves no
   selection until VALUE sets one. */
static void pudu_segments_options(UIView *view, NSArray<NSString *> *labels) {
  UISegmentedControl *segments = (UISegmentedControl *)view;
  [segments removeAllSegments];
  [labels enumerateObjectsUsingBlock:^(NSString *label, NSUInteger index, BOOL *stop) {
    (void)stop;
    [segments insertSegmentWithTitle:label atIndex:index animated:NO];
  }];
}

static void pudu_wheel_options(UIView *view, NSArray<NSString *> *labels) {
  PuduWheel *wheel = (PuduWheel *)view;
  wheel.labels = labels;
  [wheel reloadAllComponents];
}

/* How many labels a choosing kind offers, for the host's check on VALUE. */
static NSUInteger pudu_segments_count(UIView *view) { return ((UISegmentedControl *)view).numberOfSegments; }
static NSUInteger pudu_wheel_count(UIView *view) { return ((PuduWheel *)view).labels.count; }

/* VALUE setters, one per kind that holds a number. */
static void pudu_slider_number(UIView *view, uint32_t word) {
  PuduSlider *slider = (PuduSlider *)view;
  slider.index = (NSInteger)(((int64_t)(int32_t)word - slider.low) / slider.step);
  slider.value = (float)slider.index;
}

static void pudu_stepper_number(UIView *view, uint32_t word) { ((UIStepper *)view).value = (int32_t)word; }
static void pudu_segments_number(UIView *view, uint32_t index) { ((UISegmentedControl *)view).selectedSegmentIndex = (NSInteger)index; }
static void pudu_wheel_number(UIView *view, uint32_t index) { [(PuduWheel *)view selectRow:(NSInteger)index inComponent:0 animated:NO]; }
static void pudu_pages_number(UIView *view, uint32_t page) { ((UIPageControl *)view).currentPage = (NSInteger)page; }

static void pudu_well_number(UIView *view, uint32_t rgba) {
  ((UIColorWell *)view).selectedColor = [UIColor colorWithRed:(rgba >> 24 & 0xff) / 255.0 green:(rgba >> 16 & 0xff) / 255.0
                                                         blue:(rgba >> 8 & 0xff) / 255.0 alpha:(rgba & 0xff) / 255.0];
}

/* COUNT and MOMENT. */
static void pudu_pages_count(UIView *view, uint32_t total) { ((UIPageControl *)view).numberOfPages = (NSInteger)total; }

static void pudu_date_moment(UIView *view, uint32_t mode, int64_t seconds) {
  static const UIDatePickerMode modes[PUDU_MOMENTS] = { UIDatePickerModeDate, UIDatePickerModeTime, UIDatePickerModeDateAndTime };
  UIDatePicker *picker = (UIDatePicker *)view;
  picker.datePickerMode = modes[mode];
  picker.date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)seconds];
}

/* Text, hint and paint setters of the text-showing value kinds. */
static void pudu_text_area_text(UIView *view, NSString *text) {
  UITextView *area = (UITextView *)view;
  if (![area.text isEqualToString:text]) area.text = text;
}

static void pudu_text_area_paint(UIView *view, UIColor *color) { ((UITextView *)view).textColor = color; }
static void pudu_text_area_style(UIView *view, UIFont *font) { ((UITextView *)view).font = font; }
static void pudu_symbol_text(UIView *view, NSString *name) { ((UIImageView *)view).image = [UIImage systemImageNamed:name]; }
static void pudu_symbol_paint(UIView *view, UIColor *color) { view.tintColor = color; }

/* What the controls self-test does to each value kind: one change, then the
   event the platform sends for it. */
static void pudu_slider_drive(UIView *view) {
  PuduSlider *slider = (PuduSlider *)view;
  slider.value = slider.maximumValue;
  [slider sendActionsForControlEvents:UIControlEventValueChanged];
}

static void pudu_stepper_drive(UIView *view) {
  UIStepper *stepper = (UIStepper *)view;
  stepper.value = MIN(stepper.value + stepper.stepValue, stepper.maximumValue);
  [stepper sendActionsForControlEvents:UIControlEventValueChanged];
}

static void pudu_segments_drive(UIView *view) {
  UISegmentedControl *segments = (UISegmentedControl *)view;
  segments.selectedSegmentIndex = (NSInteger)segments.numberOfSegments - 1;
  [segments sendActionsForControlEvents:UIControlEventValueChanged];
}

static void pudu_wheel_drive(UIView *view) {
  PuduWheel *wheel = (PuduWheel *)view;
  NSInteger last = (NSInteger)wheel.labels.count - 1;
  [wheel selectRow:last inComponent:0 animated:NO];
  [wheel pickerView:wheel didSelectRow:last inComponent:0];
}

static void pudu_date_drive(UIView *view) {
  UIDatePicker *picker = (UIDatePicker *)view;
  picker.date = [NSDate dateWithTimeIntervalSince1970:1000000000];
  [picker sendActionsForControlEvents:UIControlEventValueChanged];
}

static void pudu_text_area_drive(UIView *view) {
  PuduTextArea *area = (PuduTextArea *)view;
  area.text = @"Notes";
  [area textViewDidChange:area];
}

static void pudu_search_drive(UIView *view) {
  UISearchTextField *search = (UISearchTextField *)view;
  search.text = @"pudu";
  [search sendActionsForControlEvents:UIControlEventEditingChanged];
}

static void pudu_pages_drive(UIView *view) {
  UIPageControl *pages = (UIPageControl *)view;
  pages.currentPage = pages.numberOfPages - 1;
  [pages sendActionsForControlEvents:UIControlEventValueChanged];
}

static void pudu_well_drive(UIView *view) {
  UIColorWell *well = (UIColorWell *)view;
  well.selectedColor = [UIColor colorWithRed:1 green:128 / 255.0 blue:0 alpha:1];
  [well sendActionsForControlEvents:UIControlEventValueChanged];
}

#endif
