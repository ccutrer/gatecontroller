
To build and update the firmware:

First, checkout https://github.com/nodemcu/nodemcu-firmware

Then from the `nodemcu-firmware` directory, run this to build the base firmware:
```
docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware marcelstoer/nodemcu-build build
```

Then from the same `nodemcu-firmware` directory, run this to build the LFS image:
```
docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware:delegated -v ~/src/gatecontroller:/opt/lua marcelstoer/nodemcu-build lfs-image gate.lst
```

Then run `mv -f LFS_float*.img LFS.img && ./server.rb` from the `gatecontroller` directory


Then send this via MQTT to `homie/<device>/$ota_update`:
```
opennuc.cutrer.network
2345
/LFS.img
```

(you may want to send `true` to `homie/<device>/$debug` first)
