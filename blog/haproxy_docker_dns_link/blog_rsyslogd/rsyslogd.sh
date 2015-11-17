#!/bin/bash

rsyslogd -f /rsyslogd.conf

# haproxy logs
mkdir /var/log/haproxy
touch /var/log/haproxy/traffic /var/log/haproxy/events /var/log/haproxy/errors

tail -F /var/log/haproxy/*

