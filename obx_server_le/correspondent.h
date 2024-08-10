//
//  correspondent.h
//  obx_server_le
//

#ifndef correspondent_h
#define correspondent_h
#import <CoreBluetooth/CoreBluetooth.h>
#import "Cocoa/cocoa.h"
#include "proto.h"

@interface Correspondent: NSObject <CBCentralManagerDelegate, CBPeripheralDelegate, NSStreamDelegate>

@property bool connected;
@property NSWindowController <Feedback>* madre;
@property CBCentralManager* centralmanager;
@property CBPeripheral* raspberry;
@property CBL2CAPChannel* l2capchan;
@property NSOutputStream* outstream;
@property NSInputStream* instream;
@property NSRunLoop* mainrunloop;

-(instancetype) initWith: (NSWindowController <Feedback>*) madre;

@end



#endif /* correspondent_h */
