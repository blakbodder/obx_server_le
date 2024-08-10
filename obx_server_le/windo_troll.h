//
//  windo_troll.h
//  obx_server_le
//

#ifndef windo_troll_h
#define windo_troll_h
#import <Cocoa/Cocoa.h>
#include "bluetooth.h"
#include "obx_le.h"
#include "correspondent.h"

@interface WindoTroll: NSWindowController <Feedback>

@property NSScrollView* scrlv;
@property NSTextView* tv;
@property NSDictionary* attdict;

@property Bluetooth* blootuth;
@property OBEXserver* obx_le_server;
@property Correspondent* corr;  // only for testing demopihost.py

@end

#endif /* windo_troll_h */
