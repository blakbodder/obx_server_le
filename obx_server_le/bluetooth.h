//
//  Bluetooth.h
//  obx_server_le
//

#ifndef bluetooth_h
#define bluetooth_h
#import <CoreBluetooth/CoreBluetooth.h>
#import <Cocoa/Cocoa.h>
#include "proto.h"

#define OBEXUUSTR "F9EC7BC4-953C-11D2-984E-525400DC9E09"

@interface Bluetooth : NSObject < CBPeripheralManagerDelegate>

@property NSWindowController <Feedback>* madre;
@property CBPeripheralManager* peripheralmanager;

@property CBUUID* uuid_l2cap_ristic;
@property CBUUID* cbuuidobex;

@property CBMutableCharacteristic* l2cap_ristic;
@property CBMutableService* service;

@property bool connected;
@property bool service_added;

@property uint16_t psm;
@property NSData* psmdat;

@property CBL2CAPChannel* l2capchan;
@property NSOutputStream* outstream;
@property NSInputStream* instream;

-(void) start_with: (NSWindowController <Feedback> *) madre;
-(void) restart;

@end

#endif /* bluetooth_h */
