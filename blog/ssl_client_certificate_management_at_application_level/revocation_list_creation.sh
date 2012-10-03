# preparation
mkdir demoCA
touch demoCA/index.txt
echo 01 > demoCA/crlnumber

# SSL certificate revocation list creation
openssl ca -gencrl -keyfile ca.key -cert ca.crt -out ca_crl.pem

# client certificate addition to the crl
openssl ca -revoke client2.crt -keyfile ca.key -cert ca.crt

# after each addition, we must regenerate the crl
openssl ca -gencrl -keyfile ca.key -cert ca.crt -out ca_crl.pem

