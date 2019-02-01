#!/bin/bash

CONF_ARCHIVE="conf-files.tar.xz"

# Package config files
if [ -f $CONF_ARCHIVE ]; then
    rm $CONF_ARCHIVE
fi
tar -cf $CONF_ARCHIVE -C ../conf/ .

# Set checksums
CHKSUM=$(sha256sum $CONF_ARCHIVE | awk '{ print $1 }')
sed -i "s/sha256sums.*/sha256sums=($CHKSUM)/g" PKGBUILD

# Build the package
#cd build && aur chroot

# TODO: Add the built packages to the remote repo
# scp *.pkg.tar.xz $SERVER
# update server ...

# Clean up
# cd .. && rm -r build
