#!/bin/bash
if lsmod | grep -q uvcvideo; then
    sudo modprobe -r uvcvideo
    echo "Camera OFF"
else
    sudo modprobe uvcvideo
    echo "Camera ON"
fi
