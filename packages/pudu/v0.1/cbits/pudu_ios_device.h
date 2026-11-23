#ifndef PUDU_IOS_DEVICE_H
#define PUDU_IOS_DEVICE_H

/* What the device is and how it reaches the network. DEVICE answers once
   with DESCRIBED. NETWORK keeps a path monitor on the main queue that sends
   NETWORKED when watching starts and whenever the kind of link changes.
   AWAKE holds the idle timer off while the application is in front. */
#import <Network/Network.h>
#import <UIKit/UIKit.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/utsname.h>
#include "pudu_ios_events.h"
#include "pudu_ios_stream.h"

enum { PUDU_LINK_OFFLINE, PUDU_LINK_WIFI, PUDU_LINK_CELLULAR, PUDU_LINK_WIRED, PUDU_LINK_UNKNOWN };

static nw_path_monitor_t pudu_network_monitor;
static uint32_t pudu_network_link = PUDU_LINK_UNKNOWN;

/* The hardware model: the simulated device's identifier on the simulator,
   where uname names the host processor, else the machine identifier. */
static NSString *pudu_device_model(void) {
  const char *simulated = getenv("SIMULATOR_MODEL_IDENTIFIER");
  if (simulated != NULL) return @(simulated);
  struct utsname names;
  if (uname(&names) != 0) return UIDevice.currentDevice.model;
  return @(names.machine);
}

/* DEVICE: the tag. The language falls back to "en" when the person lists none. */
static void pudu_do_device(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSString *language = NSLocale.preferredLanguages.firstObject ?: @"en";
  NSArray *lines = @[ @"ios", UIDevice.currentDevice.systemVersion, pudu_device_model(), language, NSTimeZone.localTimeZone.name ];
  uint32_t scale = (uint32_t)lround([UIFontMetrics.defaultMetrics scaledValueForValue:100]);
  pudu_queue(PUDU_UI_DESCRIBED, tag, [lines componentsJoinedByString:@"\n"], scale);
}

static uint32_t pudu_link_of(nw_path_t path) {
  if (nw_path_get_status(path) != nw_path_status_satisfied) return PUDU_LINK_OFFLINE;
  if (nw_path_uses_interface_type(path, nw_interface_type_wifi)) return PUDU_LINK_WIFI;
  if (nw_path_uses_interface_type(path, nw_interface_type_cellular)) return PUDU_LINK_CELLULAR;
  return PUDU_LINK_WIRED;
}

/* NETWORK: 1 to watch, 0 to stop. Watching again repeats the last known link. */
static void pudu_do_network(pudu_reader *reader) {
  uint32_t watching = pudu_word(reader);
  if (watching > 1) pudu_stream_defect("set network watching to", watching);
  if (watching == 0) {
    if (pudu_network_monitor != nil) nw_path_monitor_cancel(pudu_network_monitor);
    pudu_network_monitor = nil;
    pudu_network_link = PUDU_LINK_UNKNOWN;
    return;
  }
  if (pudu_network_monitor != nil) {
    if (pudu_network_link != PUDU_LINK_UNKNOWN) pudu_queue(PUDU_UI_NETWORKED, 0, nil, pudu_network_link);
    return;
  }
  nw_path_monitor_t monitor = nw_path_monitor_create();
  nw_path_monitor_set_queue(monitor, dispatch_get_main_queue());
  nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
    if (pudu_network_monitor != monitor) return;
    uint32_t link = pudu_link_of(path);
    if (link == pudu_network_link) return;
    pudu_network_link = link;
    pudu_queue(PUDU_UI_NETWORKED, 0, nil, link);
  });
  pudu_network_monitor = monitor;
  nw_path_monitor_start(monitor);
}

/* AWAKE: 1 to keep the screen on, 0 to let it sleep. */
static void pudu_do_awake(pudu_reader *reader) {
  uint32_t on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set keep-awake to", on);
  UIApplication.sharedApplication.idleTimerDisabled = on == 1;
  if (getenv("PUDU_UI_DEVICE_TEST") != NULL) {
    printf("PUDU_DEVICE awake %s\n", UIApplication.sharedApplication.idleTimerDisabled ? "yes" : "no");
    fflush(stdout);
  }
}

#endif
