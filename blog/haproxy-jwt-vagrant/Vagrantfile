# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
 
  config.vm.define "server1" do |server|
    server.vm.box = "ubuntu/xenial64"
    server.vm.hostname = "server1"
    server.vm.network "private_network", ip: "192.168.50.20"
    server.vm.provision "shell", path: "init.sh"
    server.vm.synced_folder "pem/", "/etc/haproxy/pem"
    server.vm.synced_folder "haproxy/", "/etc/haproxy"
  end
 
end
