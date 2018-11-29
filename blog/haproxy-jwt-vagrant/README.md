# HAProxy - JWT

Demonstrates verifying OAuth 2 JSON web tokens in HAProxy using Lua code.

Set up:

1. Replace the pem/pubkey.pem with the public key from your authentication server.
1. Create the environment with Vagrant:

```
vagrant up
```

1. Get a JSON web token (JWT) from your authenticatoin server.
1. Make requests to https://192.168.50.20/api/hamsters and attach the JWT in the Authorization header. You should get a successful response.

## Troubleshooting

Check that the haproxy service is running:

```
sudo systemctl status haproxy
```

You can check if the haproxy.cfg file is valid with this command:

```
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

Debug the incoming requests with:

```
sudo haproxy -d -f /etc/haproxy/haproxy.cfg
```

SSH into the VM with `vagrant ssh` and and make sure the node.js website is running:

```
cd /vagrant/web
docker-compose build
sudo docker-compose up -d
```