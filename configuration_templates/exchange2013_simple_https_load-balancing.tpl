# HAProxy configuration for ALOHA Load-Balancer
# Microsoft Exchange 2013 HTTPS services with SSL bridging, the
# simple way (1 frontend and 1 backend)
#
# Copyright Exceliance
# v 1.0 - August 19th, 2013
#
# required information:
# <CAS_#1_SERVER_NAME>                    : 
# <CAS_#1_SERVER_IP>                      : 
# <CAS_#2_SERVER_NAME>                    : 
# <CAS_#2_SERVER_IP>                      : 
# <VIRTUAL_IP_FOR_EXCHANGE_2013_SERVICES> : 
# <SSL_CERTIFICATE_NAME>                  : 
# <WEBMAIL_VIRTUAL_HOST>                  : 
# end of required information

##################################################
# exchange 2013 HTTPS services with SSL bridging #
##################################################

######## Default values for all entries till next defaults section
defaults
  option  http-server-close  # set Connection: close to inspect all HTTP traffic
  option  dontlognull        # Do not log connections with no requests
  option  redispatch         # Try another server in case of connection failure
  option  contstats          # Enable continuous traffic statistics updates
  retries 3                  # Try to connect up to 3 times in case of failure 
  timeout connect 5s         # 5 seconds max to connect or to stay in queue
  timeout http-keep-alive 1s # 1 second max for the client to post next request
  timeout http-request 15s   # 15 seconds max for the client to send a request
  timeout queue 30s          # 30 seconds max queued on load balancer
  timeout tarpit 1m          # tarpit hold tim
  backlog 10000              # Size of SYN backlog queue

frontend ft_exchange_https
  bind <VIRTUAL_IP_FOR_EXCHANGE_2013_SERVICES>:80 name http
  bind <VIRTUAL_IP_FOR_EXCHANGE_2013_SERVICES>:443 name https crt <SSL_CERTIFICATE_NAME>
  mode http
  log global
  option httplog
  capture request header User-Agent len 64
  capture request header Host len 32
  log-format %ci:%cp\ [%t]\ %ft\ %b/%s\ %Tq/%Tw/%Tc/%Tr/%Tt\ %ST\ %B\ %CC\ %CS\ %tsc\ %ac/%fc/%bc/%sc/%rc\ %sq/%bq\ %hr\ %hs\ {%sslv/%sslc/%[ssl_fc_sni]/%[ssl_fc_session_id]}\ %{+Q}r
  timeout client 25s
  maxconn 1000
  http-request redirect scheme   https code 302 if !{ ssl_fc }
  http-request redirect location /owa/ code 302 if { hdr(Host) <WEBMAIL_VIRTUAL_HOST> } { path / }
  default_backend bk_exchange_https

backend bk_exchange_https
  balance roundrobin
  mode http
  log global
  option httplog
  option forwardfor
  default-server inter 3s rise 2 fall 3
  timeout server 25s
  server <CAS_#1_SERVER_NAME> <CAS_#1_SERVER_IP>:443 maxconn 1000 weight 10 ssl check
  server <CAS_#2_SERVER_NAME> <CAS_#2_SERVER_IP>:443 maxconn 1000 weight 10 ssl check





