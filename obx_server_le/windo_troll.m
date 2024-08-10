//
//  windo_troll.m
//  obx_server_le
//

#import <Foundation/Foundation.h>
#include "windo_troll.h"

@implementation WindoTroll

-(void) windowDidLoad
{
    NSView* contview = self.window.contentView;
    NSRect cframe = contview.frame;
   // printf("w=%.0f  h=%.0f\n", cframe.size.width, cframe.size.height);
    self.scrlv = [[ NSScrollView alloc ] initWithFrame: cframe ];
    NSSize contentsize = [ self.scrlv contentSize ];
    [ self.scrlv setBorderType: NSNoBorder ];
    [ self.scrlv setHasVerticalScroller: YES ];
    [ self.scrlv setHasHorizontalScroller: NO ];
    [ self.scrlv setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable ];
    
    NSRect sframe = { 0, 0, contentsize.width, contentsize.height };
    self.tv = [[ NSTextView alloc ] initWithFrame: sframe ];
    [ self.tv setMinSize: (NSSize) { 0.0, contentsize.height } ];
    [ self.tv setMaxSize: (NSSize) {FLT_MAX, FLT_MAX} ];
    [ self.tv setVerticallyResizable: YES ];
    [ self.tv setHorizontallyResizable: NO ];
    [ self.tv setAutoresizingMask: NSViewWidthSizable];
    [ self.tv setEditable: NO ];
    
    NSTextContainer* tainer = self.tv.textContainer;
    [ tainer setContainerSize: (NSSize) {contentsize.width, FLT_MAX} ];
    [ tainer setWidthTracksTextView: YES ];
    
    [ self.scrlv setDocumentView: self.tv ];
    [ self.window setContentView: self.scrlv ];
    [ self.window makeKeyAndOrderFront: nil ];
   // [ self.window makeFirstResponder: self.tv];
    
    NSFont* helv = [NSFont fontWithName: @"Helvetica"  size: 14.0 ];
    self.attdict = @{ NSBackgroundColorAttributeName: [NSColor blackColor],
                      NSForegroundColorAttributeName: [NSColor whiteColor],
                      NSFontAttributeName: helv };

    _blootuth = [[ Bluetooth alloc ] init ];
    [ _blootuth start_with: self ];
      
//   _corr = [[ Correspondent alloc ] initWith: self ];  // only for testing demopihost.py
//    when enable _corr no need _blootuth
}

-(void) update: (char *) str
{
    NSString *addendum = [ NSString stringWithCString: str encoding: NSASCIIStringEncoding];
    NSAttributedString* atstr = [[ NSAttributedString alloc ] initWithString: addendum
                                                                attributes: self.attdict ];
    [ self.tv.textStorage appendAttributedString: atstr];
}

-(void) append_text: (NSString*) text
{
    NSAttributedString* atstr = [[ NSAttributedString alloc ] initWithString: text
                                                                  attributes: self.attdict ];
    [ self.tv.textStorage appendAttributedString: atstr];
}

-(void) reset
{
    NSAttributedString* atstr = [[ NSAttributedString alloc ] initWithString: @"RESETTING\n"
                                                                     attributes: self.attdict ];
    [ self.tv.textStorage appendAttributedString: atstr];
    [ self.blootuth restart ];
}

// when remote device connects, _blootuth provides the l2capchan
// which will be used by obex
-(void) transport: (CBL2CAPChannel *) l2capchan
{
    self.obx_le_server = [[OBEXserver alloc] initWithChan: (CBL2CAPChannel*) l2capchan troll: self ];
}

@end
