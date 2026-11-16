#ifndef PUDU_IOS_VALUES_H
#define PUDU_IOS_VALUES_H

/* Controls that hold a value: slider, stepper, segmented control, wheel, date
   picker, page control and color well. Values cross the stream as exact
   integers; the platform clamps them and reports what it shows. A slider
   runs in step indexes, so its value stays exact whatever its range. */
#import <UIKit/UIKit.h>
#include <math.h>
#include <stdint.h>
#include "pudu_ios_events.h"
#include "pudu_ios_stream.h"

enum { PUDU_MOMENTS = 3 };

/* A slider over step indexes 0 to (high - low) / step, the least value and
   the step it maps them by, and the value it last reported. */
@interface PuduSlider : UISlider
@property (nonatomic) int64_t low, step, reported;
@end
@implementation PuduSlider
@end

/* A wheel of one component that is its own data source and delegate. */
@interface PuduWheel : UIPickerView <UIPickerViewDataSource, UIPickerViewDelegate>
@property (copy, nonatomic) NSArray<NSString *> *titles;
@end
@implementation PuduWheel
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)view { (void)view; return 1; }
- (NSInteger)pickerView:(UIPickerView *)view numberOfRowsInComponent:(NSInteger)component {
  (void)view;
  (void)component;
  return (NSInteger)self.titles.count;
}
- (NSString *)pickerView:(UIPickerView *)view titleForRow:(NSInteger)row forComponent:(NSInteger)component {
  (void)view;
  (void)component;
  return self.titles[(NSUInteger)row];
}
- (void)pickerView:(UIPickerView *)view didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
  (void)component;
  pudu_queue(PUDU_UI_VALUED, view.tag, nil, (uint32_t)row);
}
@end

/* The value a slider shows at its thumb's nearest step index. */
static int64_t pudu_slider_value(PuduSlider *slider) { return slider.low + (int64_t)llroundf(slider.value) * slider.step; }

/* Packed RGBA, red in the high byte, from a color's sRGB components. */
static uint32_t pudu_rgba_of(UIColor *color) {
  CGFloat parts[4] = { 0, 0, 0, 1 };
  uint32_t packed = 0;
  [color getRed:&parts[0] green:&parts[1] blue:&parts[2] alpha:&parts[3]];
  for (int i = 0; i < 4; i++) packed = (packed << 8) | (uint32_t)lround(fmin(fmax(parts[i], 0), 1) * 255);
  return packed;
}

static UIColor *pudu_color_of(uint32_t rgba) {
  return [UIColor colorWithRed:((rgba >> 24) & 255) / 255.0 green:((rgba >> 16) & 255) / 255.0
                          blue:((rgba >> 8) & 255) / 255.0 alpha:(rgba & 255) / 255.0];
}

@interface PuduValueTarget : NSObject
@end
@implementation PuduValueTarget
/* A drag reports once per step it crosses; the thumb settles on the step. */
- (void)slid:(PuduSlider *)sender {
  int64_t value = pudu_slider_value(sender);
  sender.value = (float)llroundf(sender.value);
  if (value == sender.reported) return;
  sender.reported = value;
  pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)(int32_t)value);
}
- (void)stepped:(UIStepper *)sender { pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)(int32_t)llround(sender.value)); }
- (void)segmented:(UISegmentedControl *)sender { pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)sender.selectedSegmentIndex); }
- (void)paged:(UIPageControl *)sender { pudu_queue(PUDU_UI_VALUED, sender.tag, nil, (uint32_t)sender.currentPage); }
- (void)colored:(UIColorWell *)sender { pudu_queue(PUDU_UI_COLORED, sender.tag, nil, pudu_rgba_of(sender.selectedColor)); }
/* Whole seconds since the epoch as the high and low words. */
- (void)dated:(UIDatePicker *)sender {
  int64_t seconds = (int64_t)floor(sender.date.timeIntervalSince1970);
  pudu_queue_words(PUDU_UI_DATED, sender.tag, nil, 0, @[ @((int32_t)(seconds >> 32)), @((int32_t)(uint32_t)seconds) ]);
}
@end
static PuduValueTarget *pudu_value_target;

static UIControl *pudu_watched(UIControl *control, SEL action) {
  if (pudu_value_target == nil) pudu_value_target = [PuduValueTarget new];
  [control addTarget:pudu_value_target action:action forControlEvents:UIControlEventValueChanged];
  return control;
}

/* Factories. */
static UIView *pudu_make_slider(void) {
  PuduSlider *slider = [PuduSlider new];
  [slider.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  slider.step = 1;
  return pudu_watched(slider, @selector(slid:));
}

static UIView *pudu_make_stepper(void) { return pudu_watched([UIStepper new], @selector(stepped:)); }
static UIView *pudu_make_segments(void) { return pudu_watched([UISegmentedControl new], @selector(segmented:)); }
static UIView *pudu_make_pages(void) { return pudu_watched([UIPageControl new], @selector(paged:)); }
static UIView *pudu_make_well(void) { return pudu_watched([UIColorWell new], @selector(colored:)); }
static UIView *pudu_make_date(void) { return pudu_watched([UIDatePicker new], @selector(dated:)); }

static UIView *pudu_make_wheel(void) {
  PuduWheel *wheel = [PuduWheel new];
  wheel.dataSource = wheel;
  wheel.delegate = wheel;
  [wheel.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  return wheel;
}

/* BOUNDS setters; the host has refused an inverted range or a step below one. */
static void pudu_slider_bounds(UIView *view, int32_t low, int32_t high, int32_t step) {
  PuduSlider *slider = (PuduSlider *)view;
  slider.low = low;
  slider.step = step;
  slider.minimumValue = 0;
  slider.maximumValue = (float)(((int64_t)high - low) / step);
}

static void pudu_stepper_bounds(UIView *view, int32_t low, int32_t high, int32_t step) {
  UIStepper *stepper = (UIStepper *)view;
  stepper.minimumValue = low;
  stepper.maximumValue = high;
  stepper.stepValue = step;
}

/* OPTIONS setters; the host has refused an empty list. */
static void pudu_segments_options(UIView *view, NSArray<NSString *> *labels) {
  UISegmentedControl *segments = (UISegmentedControl *)view;
  [segments removeAllSegments];
  for (NSUInteger i = 0; i < labels.count; i++) [segments insertSegmentWithTitle:labels[i] atIndex:i animated:NO];
}

static void pudu_wheel_options(UIView *view, NSArray<NSString *> *labels) {
  ((PuduWheel *)view).titles = labels;
  [(PuduWheel *)view reloadAllComponents];
}

/* VALUE setters, one per kind that holds a number. */
static void pudu_slider_number(UIView *view, uint32_t word) {
  PuduSlider *slider = (PuduSlider *)view;
  int64_t index = ((int64_t)(int32_t)word - slider.low) / slider.step;
  slider.value = (float)MAX(MIN(index, (int64_t)slider.maximumValue), 0);
  slider.reported = pudu_slider_value(slider);
}

static void pudu_stepper_number(UIView *view, uint32_t word) { ((UIStepper *)view).value = (int32_t)word; }

static void pudu_segments_number(UIView *view, uint32_t index) {
  UISegmentedControl *segments = (UISegmentedControl *)view;
  if (index >= segments.numberOfSegments) pudu_stream_defect("selected past the last segment:", index);
  segments.selectedSegmentIndex = index;
}

static void pudu_wheel_number(UIView *view, uint32_t index) {
  PuduWheel *wheel = (PuduWheel *)view;
  if (index >= wheel.titles.count) pudu_stream_defect("selected past the last row:", index);
  [wheel selectRow:index inComponent:0 animated:NO];
}

static void pudu_pages_number(UIView *view, uint32_t page) { ((UIPageControl *)view).currentPage = page; }
static void pudu_well_number(UIView *view, uint32_t rgba) { ((UIColorWell *)view).selectedColor = pudu_color_of(rgba); }

/* COUNT and MOMENT. */
static void pudu_pages_count(UIView *view, uint32_t total) { ((UIPageControl *)view).numberOfPages = total; }

static void pudu_date_moment(UIView *view, uint32_t mode, int64_t seconds) {
  static const UIDatePickerMode modes[PUDU_MOMENTS] = { UIDatePickerModeDate, UIDatePickerModeTime, UIDatePickerModeDateAndTime };
  UIDatePicker *picker = (UIDatePicker *)view;
  picker.datePickerMode = modes[mode];
  picker.date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)seconds];
}

#endif
