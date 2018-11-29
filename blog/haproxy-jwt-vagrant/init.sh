#!/bin/bash

add-apt-repository ppa:vbernat/haproxy-1.8
apt update
apt install -y software-properties-common git build-essential libssl-dev lua5.3 liblua5.3-dev lua-json haproxy
cp -rf /usr/share/lua/5.2/json /usr/share/lua/5.3/
cp /usr/share/lua/5.2/json.lua /usr/share/lua/5.3/

# Set up chroot
groupadd haproxy && useradd -g haproxy haproxy

# Add Lua 5.3 modules to PATH
ln -s /usr/include/lua5.3/* /usr/include

# Install luaossl - Lua OpenSSL library
cd /tmp
git clone https://github.com/wahern/luaossl.git
cd luaossl
make && make install

# Install luasocket - Lua Socket library
cd /tmp
git clone https://github.com/diegonehab/luasocket.git
cd luasocket
make && make install-both

# Copy local Lua files
cp /vagrant/haproxy/lib/base64.lua /usr/local/share/lua/5.3/

systemctl start haproxy

# Install Docker
if [ ! $(which docker) ]; then
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update
  sudo apt install -y docker-ce
  sudo curl -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
else
  echo "docker already installed."
fi

# Start web app
cd /vagrant/web
docker-compose build
docker-compose up -d
