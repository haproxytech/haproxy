# HAProxy configuration for ALOHA Load-Balancer
#
# HAProxy 1.5 and above required
#
# RDP, TSE, remote app, RDS load-balancing and persistence
#
# Copyright Exceliance
# v 1.0 - August 7th, 2013
#
# required information:
# <ALOHA_#1_NAME>               : 
# <ALOHA_#1_IP_ADDRESS>         : 
# <ALOHA_#2_NAME>               : 
# <ALOHA_#2_IP_ADDRESS>         : 
# <VIRTUAL_IP_FOR_RDS_SERVICES> : 
# <APP_#1_SERVER_NAME>          : 
# <APP_#1_SERVER_IP>            : 
# <APP_#2_SERVER_NAME>          : 
# <APP_#2_SERVER_IP>            : 
# end of required information

#######################################
# RDS load-balancing with persistence #
#######################################
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

# RDP / TSE configuration
frontend ft_rdp
  mode tcp
  bind <VIRTUAL_IP_FOR_RDS_SERVICES>:3389 name rdp
  timeout client 1h
  option tcpka
  option tcplog
  log global
  # wait up to 5s for an RDP cookie in the request
  tcp-request inspect-delay 5s
  tcp-request content accept if RDP_COOKIE
  default_backend bk_rdp
 
backend bk_rdp
  mode tcp
  balance leastconn
  # RDP servers must be turned to "token redirection mode"
  persist rdp-cookie
  timeout server 1h
  timeout connect 4s
  option redispatch
  option tcpka
  option tcplog
  log global
  # sticky persistence
  stick-table type string len 32 size 10k expire 1d peers aloha
  stick on rdp_cookie(mstshash)
  # Server farm
  server tse1 10.0.0.23:3389 weight 10 check
  server tse2 10.0.0.24:3389 weight 10 check

