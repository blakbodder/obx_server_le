//
//  correspondent.m
//  obx_server_le
//

#import <Foundation/Foundation.h>
#import "correspondent.h"

extern NSWindowController <Feedback> * mammy;

@implementation Correspondent

-(instancetype) initWith: (NSWindowController <Feedback> *) madre
{
    self = [super init];
    mammy = _madre = madre;
    _connected = false;
    _centralmanager = [ [ CBCentralManager alloc ] initWithDelegate: self queue: nil ];
    return self;
}

-(void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    // raspberry is advertising BEEF so we can find it
    CBUUID* beef_uuid = [ CBUUID UUIDWithString: @"BEEF" ];
    switch (central.state) {
        case CBManagerStatePoweredOn:
            [ _madre append_text: @"central power on\n"];
            [ self.centralmanager scanForPeripheralsWithServices: @[beef_uuid] options: nil ];
            break;
        
        case CBManagerStatePoweredOff:
            [ _madre append_text: @"central power off\n" ];
            break;
    }
    //NSLog(@"%ld\n", (long)central.state );
}

-(void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSMutableString* s = [ NSMutableString stringWithFormat: @"discovered %@\n", peripheral.name ];
    [ _madre append_text: s ];
    // NSLog(@"discovered %@\n", peripheral);
   // NSLog(@"%@\n", advertisementData);
    if ([peripheral.name isEqualToString: @"raspberry"] ) {
        [ _centralmanager stopScan ];
        _raspberry = peripheral;
        _raspberry.delegate = self;
        
       // if (peripheral.state == CBPeripheralStateDisconnected) {
        [ _centralmanager connectPeripheral: peripheral options: nil ];
       // }
    }
}

-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (!self.connected) {
        self.connected = true;
        NSMutableString* s = [ NSMutableString stringWithFormat: @"connected to %@\n", peripheral.name];
        [ _madre append_text: s ];
        //NSLog(@"connected %ld", peripheral.state);
       [ _raspberry openL2CAPChannel: 195 ];
    }
    else  printf("ignoring double connection\n");
}

-(void) peripheral:(CBPeripheral *)peripheral didOpenL2CAPChannel:(CBL2CAPChannel *)channel error:(NSError *)error
{
    NSMutableString* s = [ NSMutableString stringWithFormat: @"peripheral CBL2CAP OPEN.  psm=%d\n", channel.PSM ];
    [ _madre append_text: s ];
    
    _mainrunloop = [ NSRunLoop mainRunLoop ];
    _l2capchan = channel;
    _outstream = channel.outputStream;
    [ _outstream scheduleInRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
    _outstream.delegate = self;
    
    _instream = channel.inputStream;
    [ _instream scheduleInRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
    _instream.delegate = self;
   
    [ _outstream open ];
    [ _instream open ];
}

-(void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSMutableString* s = [ NSMutableString stringWithFormat: @"disconnected from %@\n", peripheral.name ];
    [ _madre append_text: s ];
    _connected = false;
}

char script[][40] = { "hello raspberry, are you receiving me?",
                       "my name is not roger.",
                       "bye bye." };

int slen[] = { 38, 21, 8 };
int corr_state;

-(void) stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    uint8_t buff[2050];
    char w[2100];
    long n;
    
    if (aStream == _instream) {
        switch (eventCode) {
            case NSStreamEventOpenCompleted:
                [ _madre append_text: @"_instream opened\n" ];
                break;
                
            case NSStreamEventHasBytesAvailable:
                n = [ _instream read: buff maxLength: 2048 ];
                buff[n] = 0;    // add nul terminator
                snprintf(w, 2100, "from pi:  %s\n", (char*) buff);
                [ _madre update:  w ];
                
                if (corr_state < 2) {   // send reply
                    snprintf(w, 100, "to pi:  %s\n", script[corr_state]);
                    [ _madre update: w ];
                    [ _outstream write: (uint8_t*)script[corr_state] maxLength: slen[corr_state]];
                    corr_state++;
                }
                break;
                
            case NSStreamEventEndEncountered:
                [ _madre append_text: @"_instream end\n" ];
                [ self shutdown ];
                break;
                
            case NSStreamEventErrorOccurred:
                [ _madre append_text: @"_instream error\n" ];
                break;
                
        }
    }
    else if (aStream == _outstream) {
        switch (eventCode) {
            case NSStreamEventOpenCompleted:
                [ _madre append_text: @"_outstream opened\n"];
                corr_state = 0;
                snprintf(w, 100, "to pi:  %s\n", script[0]);
                [ _madre update: w];
                [ _outstream write: script[corr_state] maxLength: slen[corr_state] ];
                corr_state++;
                break;
                
            case NSStreamEventEndEncountered:
                [ _madre append_text: @"_outstream end\n" ];
                break;
            
            case NSStreamEventErrorOccurred:
                [ _madre append_text: @"_outstream error\n" ];
                break;
        }
    }
}

-(void) shutdown
{
    [ _instream close ];
    [ _instream removeFromRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
    [ _outstream close ];
    [ _outstream removeFromRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
    [ _centralmanager cancelPeripheralConnection: _raspberry ];
    [ _madre append_text: @"shutdown\n" ];
}

@end
