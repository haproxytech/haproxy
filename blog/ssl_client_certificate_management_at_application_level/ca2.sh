# certificate authority creation
openssl genrsa -out ca2.key 4096
openssl req -new -x509 -days 365 -key ca2.key -out ca2.crt

# client certificate creation
openssl genrsa -out client_company.key 1024
openssl req -new -key client_company.key -out client_company.csr
openssl x509 -req -days 365 -in client_company.csr -CA ca2.crt -CAkey ca2.key -set_serial 02 -out client_company.crt

