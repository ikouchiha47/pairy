#/usr/bin/bash

# Bifrost
# 
# Run this with proper provileges, ex, sudo

# Create a namespace
# Create two network interfaces and connect them
# Attach the interfaces to namespace nd host network
# Assign ip addresses
#

ip netns add localnamespace
ip link add veth0 type veth peer name veth1

# attach veth1 to localnamespace
ip link set veth1 netns localnamespace
# IP=$(ip -o -4 addr show scope global | awk '{print $2, $4}' | grep -E 'enp|wlp' | cut -d' ' -f2 | sed 's/\s//g')

E0IP="192.168.0.200/24"
E1IP="192.168.0.201/24"

ip addr add "$E0IP" dev veth0
ip netns exec localnamespace ip addr add "$E1IP" dev veth1

# bring interfaces up
ip link set veth0 up
ip netns exec localnamespace ip link set veth1 up
ip netns exec localnamespace ip link set lo up

echo "ip netns exec localnamespace ip link set veth1 up"
# ip netns exec localnamespace ping "$E0IP"
