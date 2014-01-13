From:

http://www.theregister.co.uk/2013/11/29/feature_diy_apple_ibeacons
http://developer.radiusnetworks.com/2013/10/09/how-to-make-an-ibeacon-out-of-a-raspberry-pi.html

sudo hcitool -i hci0 cmd 
0x08     bluetooth command group (OGF)
0x0008   specific command ("OCF"), HCI_LE_Set_Advertising_Data
1E       hex number of octets that follow, up to 31 (0x1e = 30)
--- start of advertising data sub-packets ---
--- adv data sub-packet #1
02       sub-packet is 2 octets long
01       next octet is bluetooth flags
1A       BT flags
    FLAGS (0x1A = 0001 :: 1010)
    bit 0: LE limited discoverable mode
    bit 1*: LE general discoverable mode
    bit 2: BR/EDR not supported
    bit 3*: simultaneous LE and BR/EDR to same device capable (controller)
    bit 4*: simultaneous LE and BR/EDR to same device capable (host)
    bit 5..7: reserved
--- adv data sub-packet #2
1A       sub-packet is 25 octets long
FF       manufacturer-specific data
4C 00    Apple's manufacturer ID
02       Data type (iBeacon)
15       data length (0x15 = 21)
92 77 83 0A B2 EB 49 0F A1 DD 7F E3 8C 49 2E DE uuid
00 00    major
00 00    minor
C5       power level
    TX POWER LEVEL
    Value 0x0A (?)
    -127 to +127 dBm
--- end of data sub-packet #2
00       EOM / irrelevant?


-----------------------------

Mystery command sent after "hciconfig hci0 leadv 3":

< HCI Command: LE Set Advertising Data (0x08|0x0008) plen 32
  0000: 13 02 01 0a 02 0a 04 0c  09 43 68 65 7a 53 71 75  .........ChezSqu
  0010: 79 72 65 73 00 00 00 00  00 00 00 00 00 00 00 00  yres............
> HCI Event: Command Complete (0x0e) plen 4
    LE Set Advertising Data (0x08|0x0008) ncmd 1
    status 0x00

