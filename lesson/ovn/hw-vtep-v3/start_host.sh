#!/bin/bash -x

docker run -d -it --name vtep5700 --network host --privileged -v /root/ovn_lab/lesson/ovn/hw-vtep-v3/:/root/ovn_lab ovn_lab:v2 bash
