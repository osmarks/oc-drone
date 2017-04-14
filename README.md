# oc-drone
Simple EEPROM image for OpenComputers drones, supporting automatic internet-based update, chatbox control and easy extension.

`drone.lua` should be minified before you flash it onto the EEPROM, or it will not fit. `drone_extras.lua` is downloaded on-the-fly and can be any size.

## Required drone hardware
If any of these are NOT inside your drone be prepared to encounter weird errors:
+ Navigation Upgrade
+ Camera Upgrade (Computronics)
+ Radar Upgrade (Computronics)
+ Chat Upgrade (Computronics)
+ Internet Card