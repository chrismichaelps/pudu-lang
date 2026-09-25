#import "pudu_desktop.h"
#import "pudu_desktop_host.h"

/* What the installed menu bar's items call: a command records its name for
   the program, and Quit requests that the window close. */
@interface PuduMenuTarget : NSObject
@property(nonatomic, weak) PuduWindowHost *host;
@end

@implementation PuduMenuTarget

- (void)chosen:(NSMenuItem *)item {
  NSString *name = item.representedObject;
  if (name.length > 0) {
    [self.host record:[@"menu\t" stringByAppendingString:name]];
  }
}

- (void)quit:(NSMenuItem *)item {
  (void)item;
  self.host.closeRequested = YES;
}

@end

/* Marks the items the program wrote. AppKit adds items of its own to a menu
   titled Edit, and the report leaves those out. */
static NSUserInterfaceItemIdentifier const PuduMenuWritten = @"pudu.written";

/* Modifier names in the order a normalized chord writes them. */
static NSString *const PuduModifierNames[] = {@"cmd", @"ctrl", @"alt", @"shift"};
static const NSEventModifierFlags PuduModifierFlags[] = {
  NSEventModifierFlagCommand,
  NSEventModifierFlagControl,
  NSEventModifierFlagOption,
  NSEventModifierFlagShift
};

static BOOL pudu_menu_depth(NSString *text, NSUInteger *depth) {
  if (text.length == 0 || text.length > 3) {
    return NO;
  }
  NSUInteger total = 0;
  for (NSUInteger at = 0; at < text.length; at++) {
    unichar digit = [text characterAtIndex:at];
    if (digit < '0' || digit > '9') {
      return NO;
    }
    total = total * 10 + (digit - '0');
  }
  *depth = total;
  return YES;
}

/* Shows a chord holding Command or Control and ending in one character as the
   item's key equivalent; other chords are shown by none. */
static void pudu_menu_equivalent(NSMenuItem *item, NSString *chord) {
  NSArray<NSString *> *pieces = [chord componentsSeparatedByString:@"+"];
  NSString *key = pieces.lastObject;
  NSEventModifierFlags mask = 0;
  for (NSUInteger at = 0; at + 1 < pieces.count; at++) {
    for (int name = 0; name < 4; name++) {
      if ([pieces[at] isEqualToString:PuduModifierNames[name]]) {
        mask |= PuduModifierFlags[name];
      }
    }
  }
  if (key.length == 1 && (mask & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) != 0) {
    item.keyEquivalent = key;
    item.keyEquivalentModifierMask = mask;
  }
}

static NSMenuItem *pudu_menu_application(PuduMenuTarget *target, NSString *title) {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:title];
  NSMenuItem *quit = [[NSMenuItem alloc]
      initWithTitle:[@"Quit " stringByAppendingString:title]
             action:@selector(quit:)
      keyEquivalent:@""];
  quit.target = target;
  [menu addItem:quit];
  NSMenuItem *holder = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
  holder.submenu = menu;
  return holder;
}

int32_t pudu_desktop_menu(void *handle, const uint8_t *records, size_t length) {
  if (![NSThread isMainThread]) {
    return -2;
  }
  if (handle == NULL || (records == NULL && length > 0)) {
    return -1;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
      NSString *text = length == 0 ? @"" : [[NSString alloc]
          initWithBytes:records
                 length:length
               encoding:NSUTF8StringEncoding];
      if (text == nil) {
        return -3;
      }

      PuduMenuTarget *target = [[PuduMenuTarget alloc] init];
      target.host = host;
      NSMenu *bar = [[NSMenu alloc] initWithTitle:@""];
      [bar addItem:pudu_menu_application(target, host.window.title)];

      /* open[d] is the menu a record at depth d is placed in. */
      NSMutableArray<NSMenu *> *open = [NSMutableArray arrayWithObject:bar];
      for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (line.length == 0) {
          continue;
        }
        NSArray<NSString *> *fields = [line componentsSeparatedByString:@"\t"];
        NSString *kind = fields[0];
        NSUInteger depth = 0;
        if (fields.count < 2 || !pudu_menu_depth(fields[1], &depth) || depth >= open.count) {
          return -3;
        }
        [open removeObjectsInRange:NSMakeRange(depth + 1, open.count - depth - 1)];
        NSMenu *container = open[depth];
        if ([kind isEqualToString:@"menu"] && fields.count == 3) {
          NSMenu *menu = [[NSMenu alloc] initWithTitle:fields[2]];
          NSMenuItem *holder = [[NSMenuItem alloc] initWithTitle:fields[2] action:nil keyEquivalent:@""];
          holder.submenu = menu;
          holder.identifier = PuduMenuWritten;
          [container addItem:holder];
          [open addObject:menu];
        } else if (depth == 0) {
          return -3;
        } else if ([kind isEqualToString:@"command"] && fields.count == 5 && fields[2].length > 0) {
          NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:fields[4] action:@selector(chosen:) keyEquivalent:@""];
          item.target = target;
          item.representedObject = fields[2];
          pudu_menu_equivalent(item, fields[3]);
          item.identifier = PuduMenuWritten;
          [container addItem:item];
        } else if ([kind isEqualToString:@"separator"] && fields.count == 2) {
          NSMenuItem *separator = [NSMenuItem separatorItem];
          separator.identifier = PuduMenuWritten;
          [container addItem:separator];
        } else {
          return -3;
        }
      }

      host.menuTarget = target;
      [NSApp setMainMenu:bar];
      return 0;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}

static NSString *pudu_menu_chord(NSMenuItem *item) {
  if (item.keyEquivalent.length == 0) {
    return @"";
  }
  NSMutableString *chord = [NSMutableString string];
  for (int name = 0; name < 4; name++) {
    if (item.keyEquivalentModifierMask & PuduModifierFlags[name]) {
      [chord appendFormat:@"%@+", PuduModifierNames[name]];
    }
  }
  [chord appendString:item.keyEquivalent];
  return chord;
}

/* Appends a menu's items as records at `depth`, submenus depth first. */
static void pudu_menu_walk(NSMenu *menu, NSUInteger depth, NSMutableString *out) {
  for (NSMenuItem *item in menu.itemArray) {
    if (![item.identifier isEqualToString:PuduMenuWritten]) {
      continue;
    }
    if (item.isSeparatorItem) {
      [out appendFormat:@"separator\t%lu\n", (unsigned long)depth];
    } else if (item.submenu != nil) {
      [out appendFormat:@"menu\t%lu\t%@\n", (unsigned long)depth, item.submenu.title];
      pudu_menu_walk(item.submenu, depth + 1, out);
    } else {
      NSString *name = [item.representedObject isKindOfClass:[NSString class]] ? item.representedObject : @"";
      [out appendFormat:@"command\t%lu\t%@\t%@\t%@\n", (unsigned long)depth, name, pudu_menu_chord(item), item.title];
    }
  }
}

int64_t pudu_desktop_menu_report(void *handle, uint8_t *buffer, size_t capacity) {
  if (![NSThread isMainThread]) {
    return -2;
  }
  if (handle == NULL) {
    return -1;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
      NSMutableString *out = [NSMutableString string];
      NSMenu *bar = NSApp.mainMenu;
      if (host.menuTarget != nil && bar != nil) {
        /* The first item is the application menu, which the program did not write. */
        for (NSInteger at = 1; at < bar.numberOfItems; at++) {
          NSMenuItem *item = [bar itemAtIndex:at];
          if (![item.identifier isEqualToString:PuduMenuWritten]) {
            continue;
          }
          [out appendFormat:@"menu\t0\t%@\n", item.submenu.title];
          pudu_menu_walk(item.submenu, 1, out);
        }
      }
      NSData *bytes = [out dataUsingEncoding:NSUTF8StringEncoding];
      if (buffer != NULL && bytes.length <= capacity) {
        memcpy(buffer, bytes.bytes, bytes.length);
      }
      return (int64_t)bytes.length;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}
