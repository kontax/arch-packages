#!/bin/bash
# Copies necessary files to a build folder in orer to run the PKGBUILD

# Make a build folder
mkdir build

# Copy the AUR files to it
cp PKGBUILD couldinho-base.install couldinho-desktop.install -t build

# Copy the rest of the files over, without their directory structure
find ../etc -type f -exec cp -t build/ {} +

