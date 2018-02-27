#!/bin/sh

[ -n "${DEBUG}" ] && set -x

# first start
if [ ! -f /haproxy.conf.previous ]; then
  echo "$0: First configuration"
  cp /haproxy.conf /haproxy.conf.previous
  haproxy -f /haproxy.conf
  exit 0
fi

# configuration update occured
CHECK=$(diff -u -p /haproxy.conf.previous /haproxy.conf | egrep -c "^[-+]backend ")

# we trigger a reload only when backends have been removed or added
if [ ${CHECK} -gt 0 ]; then
  if [ -S /haproxy.sock ]; then
    echo "show servers state" | socat /haproxy.sock - > /haproxy.serverstates
  fi
  echo "$0: Backend(s) has(ve) been added or removed, need to reload the configuration"
  haproxy -f /haproxy.conf -sf $(cat /haproxy.pid)
fi

cp /haproxy.conf /haproxy.conf.previous
