#/usr/bin/bash

# Bifrost
# 
# Run this with proper provileges, ex, sudo

# Create a namespace
# Create two network interfaces and connect them
# Attach the interfaces to namespace nd host network
# Assign ip addresses
#
set -e

setup_ns() {
    NS="$1"
    IP="$2"
    IFACE="$3"

    echo "setup namespace"
    if [[ -z "$(ip netns list | grep $NS)" ]]; then
        ip netns add "$NS"
    fi

    echo "attach interface to namespace"
    ip link set "$IFACE" netns "$NS"

    echo "assign ip addres to the network interface in ns"
    ip netns exec "$NS" ip addr add "$IP" dev "$IFACE"

    echo "bring up the lo and network iface"
    ip netns exec "$NS" ip link set "$IFACE" up
    ip netns exec "$NS" ip link set lo up
}

link_ifaces() {
    ip link add "$1" type veth peer name "$2"
}

link_ifaces "veth0" "veth1"
setup_ns "ns1" "192.168.0.200/24" "veth0"
setup_ns "ns2" "192.168.0.201/24" "veth1"

# ip netns add ns1
# ip netns add ns2

# ip link add veth0 type veth peer name veth1

# attach veth1 to localnamespace
# ip link set veth1 netns ns1
# ip link set veth0 netns ns2

# E0IP="192.168.0.200/24"
# E1IP="192.168.0.201/24"

# ip netns exec ns1 ip addr add "$E1IP" dev veth1
# ip netns exec ns2 ip addr add "$E0IP" dev veth0

# bring interfaces up
# ip netns exec ns1 ip link set veth1 up
# ip netns exec ns1 ip link set lo up

# ip netns exec ns2 ip link set veth0 up
# ip netns exec ns2 ip link set lo up

echo "To exec into SHELL"
echo "doas ip netns exec ns1 bash"
echo "doas ip netns exec ns2 bash"
# ip netns exec localnamespace ping "$E0IP"
