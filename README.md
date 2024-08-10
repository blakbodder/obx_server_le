# obx_server_le

macos/ios <-> raspberry pi data transfer over L2CAP le.
the mac uses CBL2CAPChannel.  at the pi end, a python prog with a c-extension
module sends OBEX commands over l2cap_le to implement file transfer.

mac requirements:
- macos (tested on 10.15.7)
- xcode (tested on 11.7)

pi requirements:
- a model with bluetooth
- python 3.x
- bluez  (i think it is built into bullseye)
- bluez_peripheral if need l2cap host socket on pi.

L2CAP operates in several different modes.  this is probably basic mode
l2cap_le but am not sure because apple documentation is poor.

tested only on mac powerbook.  in theory, the comms should work with ios
because it uses the same corebluetooth framework but the gui would need
to be UIKit instead of Cocoa.  if porting to ios, bear in mind that
bluetooth does not work in the simulator.

settings on the mac:
- firewall off
- bluetooth sharing on
    -  receiving items: accept and save
    -  folder for accepted items: Downloads
    -  browse: allways allow

transfer setup.py, l2cap_le_py.c, obxget_le.py, obx_const.py and demopihost.py
to the same raspberry directory. 
edit line 8 of obxget_le.py :
MACADDR="AA:BB:CC:DD:EE:FF"
so the bd_addr is that of your mac.  you can find this with `hcitool scan`.
make sure bluetooth is on (both devices) and mac + pi are close to each other.
on raspberry do:
`python setup.py build_ext --inplace`
  this builds the _L2CAP_le extension module.
maybe adjust xcode-build-settings-deployment install group + owner.
compile/run obx_server_le on the mac.
when you see added service, do:
`python obxget_le.py <filename_to_get>` in raspberry terminal.
you might get pop-ups asking for connect- and dir-access- perimissions.
probably a good idea to switch bluetooth sharing off when you are done.

the mac complains: "no central present! creating new object. this shouldn't
happen."  but things still work.  maybe when the mac can't find an apple
peer it gets grumpy.  technically, the client should retreive the psm via
a gatt enquiry.  bleak_get_psm.py ia an example of how to do this (where
bleak does the heavy lifting).  

demopihost.py is an example of making the raspberry the L2CAP le server,
to which corebluetooth can connect.  the Correspondent class acts as a
test-partner to demopihost.
