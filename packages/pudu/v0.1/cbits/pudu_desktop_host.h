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
@end

#endif
