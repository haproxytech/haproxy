Building a Service Mesh with HAProxy and Consul
===============================================

This repo contains a PoC of connecting HAProxy with Consul Connect version 1.3.0 and above.

The solution is composed by 2 scripts:
* controller.sh: used to monitor events in consul and to generate HAProxy's configuration accordingly.
* authorize.lua: used perform the authorization calls to consul for any new incoming connection.

In order to work, you must of course have a consul server in the infrastructure, that will maintain the service mesh configuration.

Then, you need to prepare your application servers with the following components:
* your application
* consul agent
* haproxy + the scripts above

As an example, please find below an integration of the components in a Docker container executing a nodejs application:

```
FROM alpine:latest

ARG CONSUL_VER=

# consul related
RUN echo "Installing consul v${CONSUL_VER}" \
&&  apk add --no-cache unzip openssl util-linux su-exec curl jq drill \
&&  mkdir /usr/src \
&&  cd /usr/src \
&&  wget -q https://releases.hashicorp.com/consul/${CONSUL_VER}/consul_${CONSUL_VER}_linux_amd64.zip \
&&  unzip -o consul_${CONSUL_VER}_linux_amd64.zip \
&&  mv consul /usr/bin/ \
&&  mkdir /tmp/consul /etc/consul.d \
&&  chown nobody:nobody /tmp/consul \
&&  rm -rf /usr/src/* \
&&  apk del unzip openssl

# haproxy related
RUN echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
&&  apk add --no-cache haproxy@edge \
&&  apk add --no-cache lua5.3-ossl lua5.3-socket socat lua5.3-cjson openssl iproute2 bash \
&&  chown -R nobody:nobody /etc/haproxy \
&&  mkdir /var/run/haproxy \
&&  chown nobody:nobody /var/run/haproxy
COPY controller.sh authorize.lua /

# application related
RUN mkdir /www \
&&  apk add --no-cache nodejs
COPY www.js /www/www.js
COPY node_modules /www/node_modules/

# entrypoint
COPY start.sh /
ENTRYPOINT [ "/start.sh" ]
```

The start.sh script introduce above is also very important, since it configures consul and starts up all the services:
* the application
* consul
* the HAProxy controller

An example of such script is included in the repo too.
It embeds configuration for a sidecar which:
* expose the 'www' local application on the external network
* expose a remote 'redis' service on the loopback, to be consumed by the local 'www' service

Docker-compose usage
====================

Run the following commands in that order:
```
docker-compose up -d consul-server
sleep 10
docker-compose exec consul-server curl --request PUT --header "X-Consul-Token: mastertoken" --data '{ "ID": "agenttoken", "Name": "Agent Token", "Type": "client", "Rules": "node \"\" { policy = \"write\" } service \"\" { policy = \"write\" }" }' http://localhost:8500/v1/acl/create
sleep 1
docker-compose up -d www redis
```

By default, the ACL will deny the traffic. In order to allow 'www' to contact 'redis', you must create the relevant intention in consul-server UI.

Usage
=====

controller.sh takes a single argument: '-sidecar-for=<service name>'.
It is mainly a loop, with a blocking query on the consul connect API endpoint waiting for events (timeout set to 10s for retries).
Once an event happens, the controller will parse the JSON returner by Consul and generate the relevant HAProxy configuration. It then parses the Upstream list and add the relevant frontend/backend corresponding to the remote service this local service has to access.
The main loop, also ensure that the SSL certificate for the local service is still valid, if not, it will update it.


