# server PEM file creation (order matters)
cat server.crt >  server.pem
cat server.key >> server.pem

# certificate authority concatenation (order doesn't matters)
cat ca.crt > ca.pem
cat ca2.crt >> ca.pem

