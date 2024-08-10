# this will probably return \xc1\x00
# which is little-endian 193
import asyncio
from bleak import BleakClient
mac_addr = "AA:BB:CC:DD:EE:FF"
obxuuid = "F9EC7BC4-953C-11D2-984E-525400DC9E09"
chruuid = "ABDD3056-28FA-441D-A470-55A75A52553A"

async def main():
    async with BleakClient(mac_addr) as client:
        services = client.services
        for serv in services:  print(serv)
        psm = await client.read_gatt_char(chruuid)
        print("psm=",psm)

asyncio.run(main())
