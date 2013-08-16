# HAProxy configuration for ALOHA Load-Balancer
#
# HAProxy 1.5 and above required
#
# Tomcat application server load-balancing with cookie and 
# url parameter persistence
#
# Copyright Exceliance
# v 1.0 - August 7th, 2013
#
# required information:
# <ALOHA_#1_NAME>              : 
# <ALOHA_#1_IP_ADDRESS>        : 
# <ALOHA_#2_NAME>              : 
# <ALOHA_#2_IP_ADDRESS>        : 
# <VIRTUAL_IP_FOR_APPLICATION> : 
# <APP_#1_SERVER_NAME>         : 
# <APP_#1_SERVER_IP>           : 
# <APP_#2_SERVER_NAME>         : 
# <APP_#2_SERVER_IP>           : 
# <APP_SERVER_TCP_PORT>        : 
# <APPLICATION_COOKIE_NAME>    : 
# <HEALTH_CHECK_URL>           : 
# end of required information

#########################################################
# tomcat application server load-balancing with advance #
# persistence (cookie + URL)                            #
#########################################################
defaults
  option  http-server-close
  option  dontlognull
  option  redispatch
  option  contstats
  retries 3
  timeout connect 5s
  timeout http-keep-alive 1s
  timeout http-request 15s
  timeout queue 30s
  timeout tarpit 1m
  backlog 10000

### persistence synchronisation ###
peers aloha
  peer <ALOHA_#1_NAME> <ALOHA_#1_IP_ADDRESS>:1023
  peer <ALOHA_#2_NAME> <ALOHA_#2_IP_ADDRESS>:1023

### application entry point ###
frontend ft_application
  bind <VIRTUAL_IP_FOR_APPLICATION>:80 name http
  mode http
  log global
  option httplog
  timeout client 25s
  maxconn 1000
  default_backend bk_application

### application server farm with persistence ###
backend bk_application
  balance roundrobin
  mode http
  log global
  option httplog
  option forwardfor
  stick-table type string len 40 size 1M expire 30m peers aloha
  stick store-response set-cookie(<APPLICATION_COOKIE_NAME>)
  stick on cookie(<APPLICATION_COOKIE_NAME>)
  stick on url_param(<APPLICATION_COOKIE_NAME>,;)
  option httpchk HEAD <HEALTH_CHECK_URL>
  timeout server 25s
  default-server inter 3s rise 2 fall 3
  server <APP_#1_SERVER_NAME> <APP_#1_SERVER_IP>:<APP_SERVER_TCP_PORT> maxconn 1000 weight 10 check
  server <APP_#2_SERVER_NAME> <APP_#2_SERVER_IP>:<APP_SERVER_TCP_PORT> maxconn 1000 weight 10 check

