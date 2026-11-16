#ifndef PUDU_IOS_CONTROLS_TEST_H
#define PUDU_IOS_CONTROLS_TEST_H

/* What the controls self-test does to each value control: one change, as a
   person would make it, followed by the event the platform sends for it.
   The kind table names each kind's drive; the program shows what it
   received. The slider's thumb lands between steps, so the run also proves
   it settles on the nearest one. */
#import <UIKit/UIKit.h>
#include "pudu_ios_controls.h"
#include "pudu_ios_text.h"
#include "pudu_ios_values.h"

static void pudu_changed(UIView *view) { [(UIControl *)view sendActionsForControlEvents:UIControlEventValueChanged]; }

static void pudu_slider_drive(UIView *view) {
  ((PuduSlider *)view).value = 2.6f;
  pudu_changed(view);
}

static void pudu_stepper_drive(UIView *view) {
  UIStepper *stepper = (UIStepper *)view;
  stepper.value = stepper.value + stepper.stepValue;
  pudu_changed(view);
}

static void pudu_segments_drive(UIView *view) {
  ((UISegmentedControl *)view).selectedSegmentIndex = 1;
  pudu_changed(view);
}

static void pudu_wheel_drive(UIView *view) {
  PuduWheel *wheel = (PuduWheel *)view;
  [wheel selectRow:2 inComponent:0 animated:NO];
  [wheel pickerView:wheel didSelectRow:2 inComponent:0];
}

static void pudu_date_drive(UIView *view) {
  ((UIDatePicker *)view).date = [NSDate dateWithTimeIntervalSince1970:1000000000];
  pudu_changed(view);
}

static void pudu_pages_drive(UIView *view) {
  ((UIPageControl *)view).currentPage = 2;
  pudu_changed(view);
}

static void pudu_well_drive(UIView *view) {
  ((UIColorWell *)view).selectedColor = pudu_color_of(0xff8000ffu);
  pudu_changed(view);
}

static void pudu_text_area_drive(UIView *view) { pudu_text_area_fill(view, @"Notes"); }
static void pudu_search_drive(UIView *view) { pudu_field_fill(view, @"pudu"); }

#endif
