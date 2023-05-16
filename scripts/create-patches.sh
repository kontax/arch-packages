#!/bin/bash
# create-patches.sh
#
# Description: Loop through package groups and see which files exist within 
# a parent folder location already. If so, create a patch based on it.


DEPS={
    "base": [],
    "desktop": ["base"],
    "laptop": ["desktop"],
    "dev": ["desktop"],
    "sec": ["desktop"],
    "vmware": ["desktop"]
}

for group in $[@DEPS]:
    for dep in $[@group]:
        \diff -U0 $orig $new > $new.patch
