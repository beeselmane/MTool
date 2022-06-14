#!/bin/bash

set -x

ulimit -c unlimited

if [[ `arch` == "arm64" ]]; then
    echo "Dumping core for arch \"arm64\""
    `dirname $0`/badcode-aarch64
elif [[ `arch` == "i386" ]]; then
    echo "Dumping core for arch \"x86_64\""
    `dirname $0`/badcode-x86_64
else
    echo "Unsupported arch!"
    false
fi

