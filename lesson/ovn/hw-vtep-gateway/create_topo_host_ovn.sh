#!/bin/bash -x

function add_vm1(){
  ip netns add vm1
  ovs-vsctl add-port br-int vm1 -- set interface vm1 type=internal
  ip link set vm1 address 02:ac:10:ff:01:30
  ip link set vm1 netns vm1
  ovs-vsctl set Interface vm1 external_ids:iface-id=inside-vm1
  pkill dhclient
  ip netns exec vm1 dhclient vm1
}

function add_vm2(){
  ip netns add vm2
  ovs-vsctl add-port br-int vm2 -- set interface vm2 type=internal
  ip link set vm2 address 02:ac:10:ff:01:31
  ip link set vm2 netns vm2
  ovs-vsctl set Interface vm2 external_ids:iface-id=inside-vm2
  pkill dhclient
  ip netns exec vm2 dhclient vm2
}

function add_vm4(){
  ip netns add vm4
  ovs-vsctl add-port br-int vm4 -- set interface vm4 type=internal
  ip link set vm4 address 02:ac:10:ff:01:33
  ip link set vm4 netns vm4
  ovs-vsctl set Interface vm4 external_ids:iface-id=vm4
  pkill dhclient
  ip netns exec vm4 dhclient vm4
}

function add_br_int(){
  ovs-vsctl add-br br-int -- set Bridge br-int fail-mode=secure
  ovs-vsctl set open . external-ids:ovn-remote=tcp:127.0.0.1:6642
  ovs-vsctl set open . external-ids:ovn-encap-type=geneve,vxlan
  ovs-vsctl set open . external-ids:ovn-encap-ip=192.168.110.3
  ovn-nbctl set-connection ptcp:6641:0.0.0.0
  ovn-sbctl set-connection ptcp:6642:0.0.0.0
}

add_br_int
stop_ovn_controller.sh
start_ovn_controller.sh

ovn-nbctl ls-add external-switch
ovn-nbctl lsp-add external-switch external-localnet
ovn-nbctl lsp-set-addresses external-localnet unknown
ovn-nbctl lsp-set-type external-localnet localnet
ovn-nbctl lsp-set-options external-localnet network_name=ext

#LOCAL_CHASSIS=`ovn-sbctl show | grep Chassis | awk '{print $2}' | sed 's/"//g'`

#ovn-nbctl lr-add router1
ovn-nbctl create Logical_Router name=router1 #options:chassis=$LOCAL_CHASSIS
ovn-nbctl ls-add inside
ovn-nbctl lrp-add router1 router1-inside 02:ac:10:ff:00:01 10.0.0.100/24
ovn-nbctl lsp-add inside inside-router1
ovn-nbctl lsp-set-type inside-router1 router
ovn-nbctl lsp-set-addresses inside-router1 02:ac:10:ff:00:01
ovn-nbctl lsp-set-options inside-router1 router-port=router1-inside
ovn-nbctl lsp-add inside inside-vm1
ovn-nbctl lsp-set-addresses inside-vm1 "02:ac:10:ff:01:30 10.0.0.1"
ovn-nbctl lsp-set-port-security inside-vm1 "02:ac:10:ff:01:30 10.0.0.1"

ovn-nbctl lsp-add inside inside-vm2
ovn-nbctl lsp-set-addresses inside-vm2 "02:ac:10:ff:01:31 10.0.0.2"
ovn-nbctl lsp-set-port-security inside-vm2 "02:ac:10:ff:01:31 10.0.0.2"

ovn-nbctl lsp-add inside inside-vtep-gateway
ovn-nbctl lsp-set-addresses inside-vtep-gateway "6c:b3:11:1c:cc:58 10.0.0.3"
ovn-nbctl lsp-set-port-security inside-vtep-gateway "6c:b3:11:1c:cc:58 10.0.0.3"
dhcptemp=`ovn-nbctl create DHCP_Options cidr=10.0.0.0/24 options="\"server_id\"=\"10.0.0.100\" \"server_mac\"=\"02:ac:10:ff:01:29\" \"lease_time\"=\"3600\" \"router\"=\"10.0.0.100\""`

ovn-nbctl lsp-add inside inside-vm3
ovn-nbctl lsp-set-addresses inside-vm3 "02:ac:10:ff:01:32 10.0.0.4"
ovn-nbctl lsp-set-port-security inside-vm3 "02:ac:10:ff:01:32 10.0.0.4"


ovn-nbctl lsp-set-dhcpv4-options inside-vm1 $dhcptemp
ovn-nbctl lsp-set-dhcpv4-options inside-vm2 $dhcptemp
ovn-nbctl lsp-set-dhcpv4-options inside-vm3 $dhcptemp
ovn-nbctl lsp-set-dhcpv4-options inside-vtep-gateway $dhcptemp

ovn-nbctl lrp-add router1 external-port 00:00:01:01:05:05 10.10.0.100/24
ovn-nbctl $OVN_NBDB lsp-add external-switch router-external-port \
          -- lsp-set-options router-external-port router-port=external-port \
          -- lsp-set-type router-external-port router \
          -- lsp-set-addresses router-external-port router

ovn-nbctl ha-chassis-group-add hagrp1
ovn-nbctl ha-chassis-group-add-chassis hagrp1 gw1 30
ovn-nbctl set Logical_Router_Port external-port ha-chassis-group=`ovn-nbctl --bare --columns _uuid find ha_chassis_group name=hagrp1`
ovn-nbctl $OVN_NBDB lr-nat-add router1 snat 10.10.0.100 10.0.0.0/22
ovn-nbctl lr-route-add router1 "0.0.0.0/0" 10.10.0.100


ovn-nbctl ls-add inside2
ovn-nbctl lrp-add router1 router1-inside2 02:ac:10:ff:00:02 10.0.1.100/24
ovn-nbctl lsp-add inside2 inside2-router1
ovn-nbctl lsp-set-type inside2-router1 router
ovn-nbctl lsp-set-addresses inside2-router1 02:ac:10:ff:00:02
ovn-nbctl lsp-set-options inside2-router1 router-port=router1-inside2

ovn-nbctl lsp-add inside2 vm4
ovn-nbctl lsp-set-addresses vm4 "02:ac:10:ff:01:33 10.0.1.2"
ovn-nbctl lsp-set-port-security vm4 "02:ac:10:ff:01:33 10.0.1.2"

ovn-nbctl lsp-add inside2 vm5
ovn-nbctl lsp-set-addresses vm5 "02:ac:10:ff:01:34 10.0.1.3"
ovn-nbctl lsp-set-port-security vm5 "02:ac:10:ff:01:34 10.0.1.3"

dhcptemp1=`ovn-nbctl create DHCP_Options cidr=10.0.1.0/24 options="\"server_id\"=\"10.0.1.100\" \"server_mac\"=\"02:ac:10:ff:01:29\" \"lease_time\"=\"3600\" \"router\"=\"10.0.1.100\""`
ovn-nbctl lsp-set-dhcpv4-options vm4 $dhcptemp1
ovn-nbctl lsp-set-dhcpv4-options vm5 $dhcptemp1


add_vm1
add_vm2
add_vm4

ovn-nbctl lsp-set-type inside-vtep-gateway vtep
ovn-nbctl lsp-set-options inside-vtep-gateway vtep-physical-switch=br0 vtep-logical-switch=ls0