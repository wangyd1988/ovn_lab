#!/bin/bash -x

/usr/share/ovn/scripts/ovn-ctl start_northd

ovn-nbctl set-connection ptcp:6641:0.0.0.0
ovn-sbctl set-connection ptcp:6642:0.0.0.0

ovn-nbctl ls-add internal1-switch
ovn-nbctl ls-add internal2-switch
ovn-nbctl ls-add external-switch

ovn-nbctl lsp-add external-switch external-localnet
ovn-nbctl lsp-set-addresses external-localnet unknown
ovn-nbctl lsp-set-type external-localnet localnet
ovn-nbctl lsp-set-options external-localnet network_name=ext

ovn-nbctl lr-add R1
ovn-nbctl lrp-add R1 internal1-port 00:00:01:01:02:03 192.168.1.1/24
ovn-nbctl lrp-add R1 internal2-port 00:00:01:01:02:04 192.168.2.1/24

ovn-nbctl lrp-add R1 external-port 00:00:01:01:02:05 10.20.0.100/24

ovn-nbctl $OVN_NBDB lsp-add internal1-switch r1-internal1-port \
          -- lsp-set-options r1-internal1-port router-port=internal1-port \
          -- lsp-set-type r1-internal1-port router \
          -- lsp-set-addresses r1-internal1-port router

ovn-nbctl $OVN_NBDB lsp-add internal2-switch r1-internal2-port \
          -- lsp-set-options r1-internal2-port router-port=internal2-port \
          -- lsp-set-type r1-internal2-port router \
          -- lsp-set-addresses r1-internal2-port router

ovn-nbctl $OVN_NBDB lsp-add external-switch r1-external-port \
          -- lsp-set-options r1-external-port router-port=external-port \
          -- lsp-set-type r1-external-port router \
          -- lsp-set-addresses r1-external-port router


dhcptemp1=`ovn-nbctl create DHCP_Options cidr=192.168.1.0/24 options="\"server_id\"=\"192.168.1.1\" \"server_mac\"=\"00:00:01:01:02:03\" \"lease_time\"=\"360000\" \"router\"=\"192.168.1.1\""`
dhcptemp2=`ovn-nbctl create DHCP_Options cidr=192.168.2.0/24 options="\"server_id\"=\"192.168.2.1\" \"server_mac\"=\"00:00:01:01:02:04\" \"lease_time\"=\"360000\" \"router\"=\"192.168.2.1\""`

ovn-nbctl lsp-add internal1-switch vm1
ovn-nbctl lsp-set-addresses vm1 "00:00:01:01:02:0a 192.168.1.3"
ovn-nbctl lsp-set-dhcpv4-options vm1 $dhcptemp1

ovn-nbctl lsp-add internal2-switch vm2
ovn-nbctl lsp-set-addresses vm2 "00:00:01:01:02:0b 192.168.2.3"

ovn-nbctl lsp-add internal1-switch vm3
ovn-nbctl lsp-set-addresses vm3 "00:00:01:01:02:08 192.168.1.4"

ovn-nbctl lsp-add internal2-switch vm4
ovn-nbctl lsp-set-addresses vm4 "00:00:01:01:02:09 192.168.2.4"


ovn-nbctl lsp-add internal1-switch internal1-l2gateway
ovn-nbctl lsp-set-addresses internal1-l2gateway "02:ac:10:ff:01:03 192.168.1.5" "02:ac:10:ff:01:04 192.168.1.6"
ovn-nbctl lsp-set-type internal1-l2gateway l2gateway
ovn-nbctl lsp-set-dhcpv4-options internal1-l2gateway $dhcptemp1
ovn-nbctl lsp-set-options internal1-l2gateway network_name=ext1 l2gateway-chassis=gw

ovn-nbctl lsp-add internal2-switch internal2-l2gateway
ovn-nbctl lsp-set-addresses internal2-l2gateway "02:ac:10:ff:01:05 192.168.2.5" "02:ac:10:ff:01:06 192.168.2.6"
ovn-nbctl lsp-set-type internal2-l2gateway l2gateway
ovn-nbctl lsp-set-dhcpv4-options internal2-l2gateway $dhcptemp2
ovn-nbctl lsp-set-options internal2-l2gateway network_name=ext2 l2gateway-chassis=gw