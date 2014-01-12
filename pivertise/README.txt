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
--- adv data sub-packet #2
1A       sub-packet is 25 octets long
FF       manufacturer-specific data
4C 00    Apple's manufacturer ID
02 15    ????
92 77 83 0A B2 EB 49 0F A1 DD 7F E3 8C 49 2E DE uuid
00 00    major
00 00    minor
C5       power level
--- end of data sub-packet #2
00       EOM / irrelevant?

