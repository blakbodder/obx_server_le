//
//  proto.h
//  obx_server_le
//

#ifndef proto_h
#define proto_h
#include <CoreBluetooth/CBL2CAPChannel.h>

@protocol Feedback

-(void) transport: (CBL2CAPChannel*) l2capchan;
-(void) update: (char*) str;
-(void) append_text: (NSString *) text;
-(void) reset;

@end
#endif /* proto_h */
