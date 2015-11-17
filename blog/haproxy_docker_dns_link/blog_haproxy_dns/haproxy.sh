#!/bin/bash

if [ -f /etc/haproxy/haproxy.cfg ]; then
	dnsmasq --no-dhcp-interface= --port 53 --interface=lo --cache-size=0 --listen-address=127.0.0.1 --pid-file=/var/run/dnsmasq.pid --user=root --max-cache-ttl=0 --local-ttl=0
	while true
	do
		inotifywait -qq -e modify /etc/hosts
		kill -HUP $(cat /var/run/dnsmasq.pid)
	done &
	haproxy -db -f /etc/haproxy/haproxy.cfg
else
	haproxy -vv
fi

