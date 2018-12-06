FROM redis:alpine

ARG CONSUL_VER=

# consul related
RUN echo "Installing consul v${CONSUL_VER}" \
&&  apk add --no-cache unzip wget openssl util-linux su-exec curl jq drill \
&&  mkdir -p /usr/src \
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
&&  apk add --no-cache haproxy@edge lua5.3-ossl@edge lua5.3-socket@edge lua5.3-cjson@edge openssl@edge \
&&  apk add --no-cache socat iproute2 bash \
&&  chown -R nobody:nobody /etc/haproxy \
&&  mkdir /var/run/haproxy \
&&  chown nobody:nobody /var/run/haproxy
COPY start.sh controller.sh authorize.lua /

# entrypoint
WORKDIR /
RUN chmod +x start.sh
ENTRYPOINT [ "/start.sh" ]
