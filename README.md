opennuc.cutrer.network
2345
/LFS.img

docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware:delegated -v ~/src/gatecontroller:/opt/lua marcelstoer/nodemcu-build lfs-image gate.lst

mv -f LFS_float*.img LFS.img && ./server.rb

