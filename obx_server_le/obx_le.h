//
//  obx_le.h
//  obx_server_le
//

#ifndef obx_le_h
#define obx_le_h
#import <Cocoa/cocoa.h>
#include "proto.h"

#define kOBEXResponseCodeSuccessWithFinalBit     0xa0
#define kOBEXResponseCodeBadRequestWithFinalBit  0xc0
#define kOBEXResponseCodeForbiddenWithFinalBit   0xc3
#define kOBEXResponseCodeNotFoundWithFinalBit    0xc4
#define kOBEXOpCodeConnect                    0x80
#define kOBEXOpCodeDisconnect                 0x81
#define kOBEXOpCodePut                        0x02
#define kOBEXOpCodePutWithHighBitSet          0x82
#define kOBEXOpCodeGet                        0x03
#define kOBEXOpCodeGetWithHighBitSet          0x83
#define kOBEXOpCodeReservedWithHighBitSet     0x84
#define kOBEXOpCodeSetPath                    0x85
#define kOBEXOpCodeAbort                      0xFF

@interface OBEXserver : NSObject <NSStreamDelegate>

@property NSInputStream* instream;
@property NSOutputStream* outstream;
@property NSRunLoop* mainrunloop;
@property NSWindowController <Feedback> * madre;

-(instancetype) initWithChan: (CBL2CAPChannel*) l2capchan  troll: madre;

@end
#endif /* obx_le_h */
