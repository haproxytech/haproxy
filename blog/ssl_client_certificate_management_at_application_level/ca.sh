# certificate authority creation
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt

# server certificate creation
openssl genrsa -out server.key 1024
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt

# client certificate creation
openssl genrsa -out client1.key 1024
openssl genrsa -out client2.key 1024
openssl req -new -key client1.key -out client1.csr
openssl req -new -key client2.key -out client2.csr
openssl x509 -req -days 365 -in client1.csr -CA ca.crt -CAkey ca.key -set_serial 02 -out client1.crt
openssl x509 -req -days 365 -in client2.csr -CA ca.crt -CAkey ca.key -set_serial 03 -out client2.crt

# expired client certificate creation
sudo date -s "Mon Oct  1 14:22:07 CEST 2012"
openssl genrsa -out client_expired.key 1024
openssl req -new -key client_expired.key -out client_expired.csr
openssl x509 -req -days 1 -in client_expired.csr -CA ca.crt -CAkey ca.key -set_serial 04 -out client_expired.crt
sudo ntpdate pool.ntp.org

