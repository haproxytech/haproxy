# HAProxy configuration for ALOHA Load-Balancer
# Microsoft Exchange 2010 HTTPS services without SSL acceleration
#
# Copyright Exceliance
# v 1.0 - August 6th, 2013
#
# required information:
# <ALOHA_#1_NAME>                         : 
# <ALOHA_#1_IP_ADDRESS>                   : 
# <ALOHA_#2_NAME>                         : 
# <ALOHA_#2_IP_ADDRESS>                   : 
# <CAS_#1_SERVER_NAME>                    : 
# <CAS_#1_SERVER_IP>                      : 
# <CAS_#2_SERVER_NAME>                    : 
# <CAS_#2_SERVER_IP>                      : 
# <VIRTUAL_IP_FOR_EXCHANGE_2010_SERVICES> : 
# end of required information

#########################################################
# exchange 2010 HTTPS services with no SSL acceleration #
#########################################################
defaults
  option  dontlognull
  option  redispatch
  option  contstats
  retries 3
  timeout client  600s
  timeout connect   5s
  timeout queue    30s
  timeout server  600s
  timeout tarpit   60s
  backlog 10000

### persistence synchronisation ###
peers aloha
  peer <ALOHA_#1_NAME> <ALOHA_#1_IP_ADDRESS>:1023
  peer <ALOHA_#2_NAME> <ALOHA_#2_IP_ADDRESS>:1023

### client ip based persistence ###
backend sourceip
  stick-table type ip size 10k peers aloha

### HTTPS services forwarding ###
backend bk_exchange_https
  balance leastconn
  mode tcp
  log global
  option tcplog
  timeout server 600s
  timeout connect 5s
  stick on src table sourceip
  default-server inter 3s rise 2 fall 3
  server <CAS_#1_SERVER_NAME> <CAS_#1_SERVER_IP>:443 check
  server <CAS_#2_SERVER_NAME> <CAS_#2_SERVER_IP>:443 check

frontend ft_exchange_https
  bind <VIRTUAL_IP_FOR_EXCHANGE_2010_SERVICES>:443 name https
  mode tcp
  log global
  option tcplog
  timeout client 600s
  default_backend bk_exchange_https

### HTTP configuration to forward users to HTTPS ###
frontend ft_exchange_http
  bind <VIRTUAL_IP_FOR_EXCHANGE_2010_SERVICES>:80 name http
  mode http
  log global
  option httplog
  timeout client         25s
  timeout http-request   15s
  timeout http-keep-alive 1s
  maxconn 1000
  redirect location /owa/ code 302 if     { path / }
  redirect scheme   https code 302 unless { ssl_fc }


