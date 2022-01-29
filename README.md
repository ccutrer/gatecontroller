Loft minisplit

192.168.85.206
001dc9835e29

opennuc.cutrer.network
2345
/LFS.img

docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware:delegated -v ~/src/gatecontroller:/opt/lua marcelstoer/nodemcu-build lfs-image gate.lst

mv -f LFS_float*.img LFS.img && ./server.rb

