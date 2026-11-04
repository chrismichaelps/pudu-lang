#ifndef PUDU_DESKTOP_HOST_H
#define PUDU_DESKTOP_HOST_H

#import <AppKit/AppKit.h>

/* Draws the presented frame; its accessibility children are the exposed tree. */
@interface PuduFrameView : NSView
@property(nonatomic, strong) NSData *rgba;
@property(nonatomic) NSInteger pixelWidth;
@property(nonatomic) NSInteger pixelHeight;
/* The exposed element holding keyboard focus, if any. */
@property(nonatomic, weak) id focusedElement;
@end

/* What an opaque desktop handle points to. */
@interface PuduWindowHost : NSObject <NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) PuduFrameView *frameView;
@property(nonatomic) BOOL closeRequested;
@property(nonatomic, strong) NSMutableData *inputs;
/* What the installed menu bar's items call, or nil when this window installed none. */
@property(nonatomic, strong) id menuTarget;
/* Frame pixels per content point; 1 unless configured. */
@property(nonatomic) CGFloat density;
/* Last reported backing scale, so an unchanged scale is not reported again. */
@property(nonatomic) CGFloat reportedScale;
/* Appends one input record, dropped past the queue's limit. */
- (void)record:(NSString *)line;
@end

/* Platform-driven window transitions, recorded as `scale`, `focus`, `minimize`
   and `fullscreen` input lines. */
@interface PuduWindowHost (WindowState)
/* Records the backing scale when it differs from the last one recorded. */
- (void)recordScale;
@end

#endif
