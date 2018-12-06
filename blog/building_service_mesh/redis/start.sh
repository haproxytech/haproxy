#!/bin/sh

set -e
set -x

redis-server &

MYIP=$(hostname -i)

[ -z "${SERVICENAME}" ] && exit 1

cat <<EOF >/etc/consul.d/services.json
{
  "service": {
    "name": "${SERVICENAME}",
    "port": 6379,
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [],
          "config": {}
        }
      }
    }
  },
  "primary_datacenter":"dc1",
  "acl_default_policy":"deny",
  "acl_down_policy":"extend-cache",
  "acl_token":"agenttoken"
}
EOF

cat /etc/consul.d/services.json

/controller.sh -sidecar-for=${SERVICENAME} &

exec su -l nobody -s /bin/bash -c "consul agent -data-dir=/tmp/consul -node=$HOSTNAME -node-id=$(uuidgen) -bind=0.0.0.0 \
                -enable-script-checks \
                -config-dir=/etc/consul.d -retry-join consul-server"

