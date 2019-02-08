#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
GIT_ROOT=$(git -C $DIR rev-parse --show-toplevel)
CONF_ARCHIVE="$GIT_ROOT/pkg/conf-files.tar.xz"

# Package config files
if [ -f $CONF_ARCHIVE ]; then
    rm $CONF_ARCHIVE
fi
tar -cf $CONF_ARCHIVE -C $GIT_ROOT/conf/ .

# Set checksums
CHKSUM=$(sha256sum $CONF_ARCHIVE | awk '{ print $1 }')
sed -i "s/sha256sums.*/sha256sums=($CHKSUM)/g" "$GIT_ROOT/pkg/PKGBUILD"

# Build the package
if [ -d build ]; then
    rm -r build
fi
mkdir build
cp *.install PKGBUILD conf-files.tar.xz -t build
cd build && aur chroot

# TODO: Add the built packages to the remote repo
# scp *.pkg.tar.xz $SERVER
# update server ...

# Clean up
# cd .. && rm -r build
