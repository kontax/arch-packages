#!/bin/bash
comm -3 \
    <(find conf -type f | sed 's/^conf\///g' | sort) \
    <(grep -E "^[[:space:]]+install -Dm" pkg/PKGBUILD | awk '{print $4}' | sort)
