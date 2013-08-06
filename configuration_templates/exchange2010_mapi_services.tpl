# HAProxy configuration for ALOHA Load-Balancer
# Microsoft Exchange 2010 RPC services load-balancing
#
# Copyright Exceliance
# v 1.0 - August 6th, 2013
#
# required information:
# <ALOHA_#1_NAME>                         : 
# <ALOHA_#1_IP_ADDRESS>                   : 
# <ALOHA_#2_NAME>                         : 
# <ALOHA_#1_IP_ADDRESS>                   : 
# <CAS_#1_SERVER_NAME>                    : 
# <CAS_#1_SERVER_IP>                      : 
# <CAS_#2_SERVER_NAME>                    : 
# <CAS_#2_SERVER_IP>                      : 
# <VIRTUAL_IP_FOR_EXCHANGE_2010_SERVICES> : 
# <CLIENT_ACCESS_TCP_PORT>                : 
# <ADDRESS_BOOK_TCP_PORT>                 :
# end of required information

############################################
# exchange 2010 TCP RPC mapi configuration #
############################################
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
  peer <ALOHA_#2_NAME> <ALOHA_#1_IP_ADDRESS>:1023

### client ip based persistence ###
backend sourceip
  stick-table type ip size 10k peers aloha

### 3 ports moniroting for server <CAS_#1_SERVER_NAME>
listen chk_<CAS_#1_SERVER_NAME>
  bind 127.0.0.1:1001
  mode http
  monitor-uri /check
  monitor fail if { nbsrv lt 3 }
  default-server inter 3s fall 2 rise 2
  server <CAS_#1_SERVER_NAME>_endpointmapper <CAS_#1_SERVER_IP>:135 check 
  server <CAS_#1_SERVER_NAME>_clientaccess <CAS_#1_SERVER_IP>:<CLIENT_ACCESS_TCP_PORT> check 
  server <CAS_#1_SERVER_NAME>_addressbook  <CAS_#1_SERVER_IP>:<ADDRESS_BOOK_TCP_PORT> check

### 3 ports moniroting for server <CAS_#2_SERVER_NAME>
listen chk_<CAS_#2_SERVER_NAME>
  bind 127.0.0.1:1002
  mode http
  monitor-uri /check
  monitor fail if { nbsrv lt 3 }
  default-server inter 3s fall 2 rise 2
  server <CAS_#2_SERVER_NAME>_endpointmapper <CAS_#2_SERVER_IP>:135 check 
  server <CAS_#2_SERVER_NAME>_clientaccess <CAS_#2_SERVER_IP>:<CLIENT_ACCESS_TCP_PORT> check 
  server <CAS_#2_SERVER_NAME>_addressbook  <CAS_#2_SERVER_IP>:<ADDRESS_BOOK_TCP_PORT> check

### exchange 2010 endpoint mapper service ###
backend bk_exchange2010_endpointmapper
  balance leastconn
  mode tcp
  log global
  option tcplog
  timeout server 600s
  timeout connect 5s
  stick on src table sourceip
  option httpchk HEAD /check HTTP/1.0
  default-server inter 1s rise 1 fall 1 on-marked-down shutdown-sessions
  server <CAS_#1_SERVER_NAME> <CAS_#1_SERVER_IP>:135 check addr 127.0.0.1 port 1001 observe layer4
  server <CAS_#2_SERVER_NAME> <CAS_#2_SERVER_IP>:135 check addr 127.0.0.1 port 1002 observe layer4

frontend ft_endpointmapper
  bind <VIRTUAL_IP_FOR_EXCHANGE_2010_SERVICES>:135 name endpointmapper
  mode tcp
  log global
  option tcplog
  timeout client 600s
  default_backend bk_exchange2010_endpointmapper

### exchange 2010 client access service ###
backend bk_exchange2010_clientaccess
  balance leastconn
  mode tcp
  log global
  option tcplog
  timeout server 600s
  timeout connect 5s
  option httpchk HEAD /check HTTP/1.0
  stick on src table sourceip
  default-server inter 1s rise 1 fall 1 on-marked-down shutdown-sessions
  server <CAS_#1_SERVER_NAME> <CAS_#1_SERVER_IP>:<CLIENT_ACCESS_TCP_PORT> check addr 127.0.0.1 port 1001 observe layer4
  server <CAS_#2_SERVER_NAME> <CAS_#2_SERVER_IP>:<CLIENT_ACCESS_TCP_PORT> check addr 127.0.0.1 port 1002 observe layer4

frontend ft_clientaccess
  bind <VIRTUAL_IP_FOR_EXCHANGE_2010_SERVICES>:<CLIENT_ACCESS_TCP_PORT> name clientaccess
  mode tcp
  log global
  option tcplog
  timeout client 600s
  default_backend bk_exchange2010_clientaccess

### exchange 2010 address book service ###
backend bk_exchange2010_addressbook
  balance leastconn
  mode tcp
  log global
  option tcplog
  timeout server 600s
  timeout connect 5s
  option httpchk HEAD /check HTTP/1.0
  stick on src table sourceip
  default-server inter 1s rise 1 fall 1 on-marked-down shutdown-sessions
  server <CAS_#1_SERVER_NAME> <CAS_#1_SERVER_IP>:<ADDRESS_BOOK_TCP_PORT> check addr 127.0.0.1 port 1001 observe layer4
  server <CAS_#2_SERVER_NAME> <CAS_#2_SERVER_IP>:<ADDRESS_BOOK_TCP_PORT> check addr 127.0.0.1 port 1002 observe layer4

frontend ft_addressbook
  bind <VIRTUAL_IP_FOR_EXCHANGE_2010_SERVICES>:<ADDRESS_BOOK_TCP_PORT> name addressbook
  mode tcp
  log global
  option tcplog
  timeout client 600s
  default_backend bk_exchange2010_addressbook

