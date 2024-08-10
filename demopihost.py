# create listener l2cap le socket to which corebluetooth can connect
# to test, execute
#   _corr = [ [ Correspndent alloc ] initWith: self ];
# on apple device.  see obx_server_le/windo_troll.m.
# discovery usually takes a few seconds. so does connect.
# advertising may require sudo hciconfig hci leadv 0
# see http://bluez-peripheral.readthedocs.io

from _L2CAP_le import L2CAP_le
from bluez_peripheral.util import *
from bluez_peripheral.advert import Advertisement
import asyncio

async def main():
    bus = await get_message_bus()
    adapter = await Adapter.get_first(bus)
    advert = Advertisement("raspberry", ["BEEF"], 0, 120)
    await advert.register(bus, adapter)
    sk = L2CAP_le()
    sk.bind(("", 195))
    sk.listen(1)
    print("waiting for connection ...")
    noosk,addr = sk.accept()
    print("accepted connection from", addr)
    rawdat = noosk.recv()
    dat = str(rawdat, 'utf-8');  print("-> ",dat)
    print("<- roger.  ten four.");
    noosk.send(b'roger.  ten four.')
    rawdat = noosk.recv()
    dat = str(rawdat, 'utf-8');  print("-> ",dat)
    noosk.close()
    sk.close()
    # await bus.wait_for_disconnect()

asyncio.run(main())
