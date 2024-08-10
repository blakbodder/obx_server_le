//
//  bluetooth.m
//  obx_server_le

//  could go: windowcontroller creates Bluetooth instance which provides l2capchan
//  bluetooth instance then creates obex server with the l2capchan as transport.
//  but prefer blootuth passes l2capchan back to windowcontroller which then
//  creates obex-server-with-l2capchan

#import <Foundation/Foundation.h>
#include "bluetooth.h"
#include <stdarg.h>

NSWindowController <Feedback> * mammy;

void report(char* fmt, ...)
{
    char w[128];
    va_list(vargs);
    va_start(vargs, fmt);
    vsnprintf(w, 128, fmt, vargs);
    [ mammy update: w ];
    va_end(vargs);
}

@implementation Bluetooth

-(void) start_with : (NSWindowController <Feedback> *) madre
{
    mammy = _madre = madre;
    _service_added = _connected = false;
    _peripheralmanager = [ [ CBPeripheralManager alloc] initWithDelegate: self queue:nil options:nil ];
    _cbuuidobex = [ CBUUID UUIDWithString: @OBEXUUSTR ];
    _uuid_l2cap_ristic = [ CBUUID UUIDWithString: CBUUIDL2CAPPSMCharacteristicString ];
    _service = [[ CBMutableService alloc ] initWithType: _cbuuidobex primary: YES ];
}

-(void) peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBManagerStatePoweredOn:
            [ _madre update: "perif power on\n" ];
            // seems batty that this creates an l2cap listener but we only get hands on it
            // later when the peer connects
            [ _peripheralmanager publishL2CAPChannelWithEncryption: false ];
            break;
            
        case CBManagerStatePoweredOff:
            [ _madre update: "perif power off\n" ];
            break;
    }

}

-(void) peripheralManager: (CBPeripheralManager *)peripheral didPublishL2CAPChannel: (CBL2CAPPSM)PSM
                    error: (nullable NSError *)error
{
    report("L2CAPchan with PSM %d\n", PSM);
    // NSLog(@"%@", error);
    
    // create obex "service" with L2CAP PSM charactistic
    // although we only init the server when the l2capchan is connected to
    
    if (!_service_added) {
        _psm = PSM;
        _psmdat = [ NSData dataWithBytes: &PSM length: 2];
        _l2cap_ristic = [ [CBMutableCharacteristic alloc] initWithType: _uuid_l2cap_ristic properties:           CBCharacteristicPropertyRead value: _psmdat permissions: CBAttributePermissionsReadable ];
        _service.characteristics = @[_l2cap_ristic];
        [ _peripheralmanager addService: _service ];
        _service_added = true;
    }
}


-(void) peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    [ _madre update: "added service\n" ];
    // service up, so advertise
    NSDictionary* perifdict = @{ CBAdvertisementDataServiceUUIDsKey: @[_cbuuidobex],
                                 CBAdvertisementDataLocalNameKey: @"obex_over_l2cap_le" };
    [ _peripheralmanager startAdvertising: perifdict ];
}

-(void) peripheralManager:(CBPeripheralManager *)peripheral didOpenL2CAPChannel:(CBL2CAPChannel *)channel error:(NSError *)error
{
    // finally have cbl2capchan that is useable
    [ _madre update: "peripheral manager didOpen CBL2CAPchan\n" ];
    _l2capchan = channel;
    [ _madre transport: channel]; // tell viewcontroller have transport
}

-(void) restart
{
    // tear down l2capchan and make new one so that obxget_le can go again
    [ _peripheralmanager unpublishL2CAPChannel: _psm ];
     _l2capchan = nil;
    [ _peripheralmanager stopAdvertising ];
    [ _peripheralmanager removeService: _service ];
    _service_added = false;
    usleep(100000);
    if (_peripheralmanager.state == CBManagerStatePoweredOn )
        [ _peripheralmanager publishL2CAPChannelWithEncryption: false ];
}

@end
