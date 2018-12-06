#!/bin/bash

# "optimized" for bash/Ubuntu

set -x
#VERBOSE="--verbose"

LOGFILE=/tmp/controller.log

declare -A ARGS
ARGS["SIDECAR_FOR"]=""

ERROR="false"
for arg in "$@"
do      
        case ${arg} in
        -sidecar-for=*)
                ARGS["SIDECAR_FOR"]=${arg##*=}
                shift
                ;;
        *)
                echo "unknown argument: $arg" >>$LOGFILE
		ERROR="true"
                ;;
        esac
done

if [ -z "${ARGS["SIDECAR_FOR"]}" ]; then
  echo "Need at least one argument: \"-sidecar-for=<service name>\""
  exit 1
fi

if [ ${ERROR} = "true" ]; then
  cat $LOGFILE
  exit 1
fi

# HAProxy Enterprise related variables
#CONF_TMP_DIR=/tmp/cfg
#CONF_PROD_DIR=/etc/hapee-1.8
#CONF_CERTS_DIRNAME=certs
#CONF_HAP_FILENAME=hapee-lb.cfg
#HAP_BINARY_PATH=/opt/hapee-1.8/sbin/
#HAP_BINARY_NAME=hapee-lb
#HAP_BINARY=${HAP_BINARY_PATH}/${HAP_BINARY_NAME}
#HAP_PIDFILE=/var/run/hapee-1.8/hapee-lb.pid
#HAP_SOCKET=/var/run/hapee-1.8/hapee-lb.sock
#HAP_USER=hapee-lb
#HAP_GROUP=hapee
#HAP_MODULES="module-path /opt/hapee-1.8/modules"

# HAPCE alpine 
CONF_TMP_DIR=/tmp/cfg
CONF_PROD_DIR=/etc/haproxy
CONF_CERTS_DIRNAME=certs
CONF_HAP_FILENAME=haproxy.cfg
HAP_BINARY_PATH=/usr/sbin
HAP_BINARY_NAME=haproxy
HAP_BINARY=${HAP_BINARY_PATH}/${HAP_BINARY_NAME}
HAP_PIDFILE=/var/run/haproxy/haproxy.pid
HAP_SOCKET=/var/run/haproxy/haproxy.sock
HAP_USER=nobody
HAP_GROUP=nobody
HAP_MODULES=

# common URLs
CURL='curl --silent '
CONSUL_SERVICE_URL="http://localhost:8500/v1/agent/service/${ARGS["SIDECAR_FOR"]}-sidecar-proxy"
CONSUL_ROOTCA_URL="http://localhost:8500/v1/agent/connect/ca/roots"
CONSUL_LEAF_CERT_URL="http://localhost:8500/v1/agent/connect/ca/leaf"

# this function triggers a reload of HAProxy
function do-reload() {
	pidof ${HAP_BINARY_NAME}
	CHECK=$?
	if [ $CHECK -eq 1 ]; then
		echo "Starting required" >>$LOGFILE
		${HAP_BINARY} -f ${CONF_PROD_DIR}/${CONF_HAP_FILENAME} -W 2>>$LOGFILE
	else
		echo "Reload required" >>$LOGFILE
		kill -SIGUSR2 $(cat ${HAP_PIDFILE})
	fi
}

# this function checks haproxy's configuration file integrity (including certificates)
# it returns 1 in case of error and 0 otherwise
function do-check() {
	${HAP_BINARY} -f ${CONF_TMP_DIR}/${CONF_HAP_FILENAME} -c
	return $?
}

# this function move haproxy's configuration from a temporary dir to the production one
function move-cfg() {
	SRC=$1
	DST=$2

	[ -z "${SRC}" ] && return 1
	[ -z "${DST}" ] && return 1

	#mv -f ${DST} ${DST}.old 2>>$LOGFILE
	mv -f ${SRC}/${CONF_HAP_FILENAME} ${DST}/${CONF_HAP_FILENAME} 2>>$LOGFILE
	[ ! -d ${DST}/${CONF_CERTS_DIRNAME} ] && mkdir -p ${DST}/${CONF_CERTS_DIRNAME}
	mv -f ${SRC}/${CONF_CERTS_DIRNAME}/* ${DST}/${CONF_CERTS_DIRNAME}/ 2>>$LOGFILE
	sed -i -e "s!${SRC}!${DST}!g" ${DST}/${CONF_HAP_FILENAME}

	return 0
}

### CERTIFICATES ###
declare -A CERTS

# this function watch for LEAF certificates changes and update local storage
# when required.
# it returns an integer with the number of certs that has been updated locally.
function check-certs() {
	local ret=0

	for cert in "${!CERTS[@]}"
	do
		CONSUL_LEAFCERT_JSON=$(${CURL} ${CONSUL_LEAF_CERT_URL}/${CERTNAME} 2>>$LOGFILE)
		SERIAL=$(jq -r .SerialNumber <<<${CONSUL_LEAFCERT_JSON})
		if [ "${CERTS[$cert]}" != "$SERIAL" ] || [ ! -s "${CONF_PROD_DIR}/${CONF_CERTS_DIRNAME}/${cert}.pem" ]; then
			save-leaf-cert $cert ${CONF_PROD_DIR}/${CONF_CERTS_DIRNAME}
			ret+=1
		fi
	done

	return $ret
}

function save-leaf-cert() {
	CERTNAME=$1
	DESTINATION_DIR=$2

	[ -z "${CERTNAME}" ] && return
	[ -z "${DESTINATION_DIR}" ] && return

	CONSUL_LEAFCERT_JSON=$(${CURL} ${CONSUL_LEAF_CERT_URL}/${CERTNAME} 2>>$LOGFILE)
	SERIAL=$(jq -r .SerialNumber <<<${CONSUL_LEAFCERT_JSON})
	jq -r .CertPEM <<<${CONSUL_LEAFCERT_JSON}       >  ${DESTINATION_DIR}/${CERTNAME}.pem
	jq -r .PrivateKeyPEM <<<${CONSUL_LEAFCERT_JSON} >> ${DESTINATION_DIR}/${CERTNAME}.pem
	sed -i -e 's/\\n/\n/g' -e '/^$/d' ${DESTINATION_DIR}/${CERTNAME}.pem

	# save cert serial in the list
	CERTS[${CERTNAME}]=$SERIAL
}
### END OF CERTIFICATES ###


### CONFIG ###
declare -A CONFIG
# initialize a new CONFIG array
function config-init() {
	# global variables
	CONFIG["TARGET_SERVICE_NAME"]=${ARGS["SIDECAR_FOR"]}
	CONFIG["PIDFILE"]=${HAP_PIDFILE}
	CONFIG["STATS_SOCKET"]=${HAP_SOCKET}
	CONFIG["CERTS_FOLDER"]="${CONF_TMP_DIR}/${CONF_CERTS_DIRNAME}"
	CONFIG["ACL_UNSECURED"]="acl UNSECURED dst_port 0"
	CONFIG["USER"]=${HAP_USER}
	CONFIG["GROUP"]=${HAP_GROUP}
	CONFIG["MODULES"]=${HAP_MODULES}

	# mandatory parameters provided by the consul API
	CONFIG["BIND_ADDRESS"]=""
	CONFIG["BIND_PORT"]=""
	CONFIG["LOCAL_SERVICE_ADDRESS"]=""
	CONFIG["LOCAL_SERVICE_PORT"]=""

	# custom parameters
	CONFIG["UNSECURED_BIND_PORT"]=""
	CONFIG["LOCAL_SERVICE_MODE"]="tcp"
	CONFIG["LOCAL_BACKEND_MODE"]="mode tcp"
	CONFIG["SYSLOG_SERVER"]="" 
	CONFIG["LOG_FORMAT"]="option tcplog"
	CONFIG["DEFAULTS_LOG"]=""
}

# collect data from consul to build the configuration
function config-getdata() {
	CONSUL_PROXY_JSON=$($CURL ${CONSUL_SERVICE_URL} 2>>$LOGFILE)
	echo $CONSUL_PROXY_JSON >>$LOGFILE

	CONFIG["BIND_ADDRESS"]=$(jq -r .Address <<<${CONSUL_PROXY_JSON})
	CONFIG["BIND_PORT"]=$(jq -r .Port <<<${CONSUL_PROXY_JSON})
	CONFIG["LOCAL_SERVICE_ADDRESS"]=$(jq -r .Proxy.LocalServiceAddress <<<${CONSUL_PROXY_JSON})
	CONFIG["LOCAL_SERVICE_PORT"]=$(jq -r .Proxy.LocalServicePort <<<${CONSUL_PROXY_JSON})

	# custom parameters
#CONFIG["AUTHORIZATIONFREE_BIND_PORT=$(jq -r .Config.authorizationfree_bind_port <<<${CONSUL_PROXY_JSON})
#if [ "${AUTHORIZATIONFREE_BIND_PORT}" = "null" ]; then
#	AUTHORIZATIONFREE_BIND_PORT=
#fi
	UNSECURED_BIND_PORT=$(jq -r .Proxy.Config.unsecured_bind_port <<<${CONSUL_PROXY_JSON})
	if [ "${UNSECURED_BIND_PORT}" != "null" ]; then
		CONFIG["UNSECURED_BIND_PORT"]="bind :${UNSECURED_BIND_PORT} name unsecured"
		CONFIG["ACL_UNSECURED"]="${CONFIG["ACL_UNSECURED"]} ${UNSECURED_BIND_PORT}"
	fi

	LOCAL_SERVICE_MODE=$(jq -r .Proxy.Config.local_service_mode <<<${CONSUL_PROXY_JSON})
	case ${LOCAL_SERVICE_MODE} in
	http)
		CONFIG["LOCAL_SERVICE_MODE"]="mode http"
		CONFIG["LOCAL_BACKEND_MODE"]="mode http"
		CONFIG["LOG_FORMAT"]="log-format \"%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs {%[var(txn.SpiffeUrl)]|%[var(txn.Authorized)]|%[var(txn.Reason)]} {%sslv|%sslc|%[ssl_fc_session_id,hex]|%[ssl_fc_is_resumed]|%[ssl_fc_sni]} %{+Q}r\""
		;;
	tcp|*)
		CONFIG["LOCAL_SERVICE_MODE"]="mode tcp"
		CONFIG["LOCAL_BACKEND_MODE"]="mode tcp"
		CONFIG["LOG_FORMAT"]="log-format \"%ci:%cp [%t] %ft %b/%s %Tw/%Tc/%Tt %B %ts %ac/%fc/%bc/%sc/%rc %sq/%bq {%[var(txn.SpiffeUrl)]|%[var(txn.Authorized)]|%[var(txn.Reason)]} {%sslv|%sslc|%[ssl_fc_session_id,hex]|%[ssl_fc_is_resumed]|%[ssl_fc_sni]}\""
		;;
	esac
	CONFIG["LOCAL_SERVICE_MODE"]="${CONFIG["LOCAL_SERVICE_MODE"]}
 tcp-request inspect-delay 30s
 #tcp-request content lua.authorize unless UNSECURED
 #tcp-request content capture var(txn.SpiffeUrl) len 64 if { var(txn.SpiffeUrl) -m found }
 #tcp-request content capture var(txn.Authorized) len 64 if { var(txn.Authorized) -m found }
 #tcp-request content capture var(txn.Reason) len 64 if { var(txn.Reason) -m found }
 tcp-request content reject #unless UNSECURED or { var(txn.Authorized) -m str true }
"
	SYSLOG_SERVER=$(jq -r .Proxy.Config.syslog_server <<<${CONSUL_PROXY_JSON})
	if [ "${SYSLOG_SERVER}" != "null" ]; then
		CONFIG["SYSLOG_SERVER"]="log ${SYSLOG_SERVER} local0 info
 log-tag sidecar-for-${ARGS["SIDECAR_FOR"]}"
		CONFIG["DEFAULTS_LOG"]="log global
 option httplog"
	fi
}

# write HAProxy Configuration
function config-write() {
	cat <<EOF >${CONF_TMP_DIR}/${CONF_HAP_FILENAME}
global
 maxconn            10000
 #user               ${CONFIG["USER"]}    # useless cause we're already started as ${CONFIG["USER"]} user
 #group              ${CONFIG["GROUP"]}   # useless cause we're already started as ${CONFIG["GROUP"]} user
 #chroot             /var/empty
 daemon
 tune.ssl.default-dh-param 1024
 pidfile            ${CONFIG["PIDFILE"]}
 stats socket       ${CONFIG["STATS_SOCKET"]} user ${CONFIG["USER"]} group ${CONFIG["GROUP"]} mode 660 level admin
 stats timeout      10m
 ca-base            ${CONFIG["CERTS_FOLDER"]}
 crt-base           ${CONFIG["CERTS_FOLDER"]}
 ${CONFIG["MODULES"]}
 lua-load /authorize.lua
 ${CONFIG["SYSLOG_SERVER"]}

resolvers consul
 nameserver consul 127.0.0.1:8600

defaults
 timeout client 30s
 timeout connect 250ms
 timeout server 30s
 option  redispatch 1
 retries 3
 option socket-stats
 option tcplog
 option dontlognull
 option dontlog-normal
 default-server init-addr none
 ${CONFIG["DEFAULTS_LOG"]}

frontend f_stats
 bind 0.0.0.0:1936
 mode http
 http-request set-log-level silent
 stats enable
 stats uri /
 stats show-legends
 stats show-desc ${CONFIG["TARGET_SERVICE_NAME"]} on ${CONFIG["PROXY_ID"]}
 option httpclose

# Proxied (local) service
frontend f_${CONFIG["TARGET_SERVICE_NAME"]}
 bind :${CONFIG["BIND_PORT"]} ssl ca-file ca.pem crt ${CONFIG["TARGET_SERVICE_NAME"]}.pem verify required name secured
 ${CONFIG["AUTHORIZATIONFREE_BIND_PORT"]}
 ${CONFIG["UNSECURED_BIND_PORT"]}
 ${CONFIG["ACL_UNSECURED"]}
 ${CONFIG["LOCAL_SERVICE_MODE"]}
 default_backend b_${CONFIG["TARGET_SERVICE_NAME"]}

backend b_${CONFIG["TARGET_SERVICE_NAME"]}
 ${CONFIG["LOCAL_BACKEND_MODE"]}
 server localhost ${CONFIG["LOCAL_SERVICE_ADDRESS"]}:${CONFIG["LOCAL_SERVICE_PORT"]} check

# upstreams:
EOF
}

# dump content of the CONFIG variable
function config-dump() {
	for a in ${!CONFIG[@]}
	do
		echo "$a: ${CONFIG[$a]}" >>$LOGFILE
	done
}
### END OF CONFIG ###


### UPSTREAM ###
declare -A UPSTREAM
function upstream-init() {
	# mandatory parameters provided by the consul API
	UPSTREAM["DESTINATION_NAME"]=""
	UPSTREAM["DESTINATION_SERVERS"]=""
	UPSTREAM["LOCAL_BIND_ADDRESS"]=""
	UPSTREAM["LOCAL_BIND_PORT"]=""

	# custom parameters
	UPSTREAM["DESTINATION_MODE"]="mode tcp"
	UPSTREAM["LOG_FORMAT"]="option tcplog"
	UPSTREAM["ADVANCED_CHECK"]="option tcp-check
tcp-check connect ssl"
}

function upstream-getdata() {
	# mandatory parameters provided by the consul API
	UPSTREAM["DESTINATION_NAME"]=$(jq -r .DestinationName <<<${1})
	UPSTREAM["LOCAL_BIND_ADDRESS"]=$(jq -r .LocalBindAddress <<<${1})
	UPSTREAM["LOCAL_BIND_PORT"]=$(jq -r .LocalBindPort <<<${1})
	DESTINATION_TYPE=$(jq -r .DestinationType <<<${1})
	case ${DESTINATION_TYPE} in
		"service")
		UPSTREAM["DESTINATION_SERVERS"]="server-template s_${UPSTREAM["DESTINATION_NAME"]} 20 _${UPSTREAM["DESTINATION_NAME"]}._tcp.service.consul ssl resolvers consul ca-file ca.pem crt ${CONFIG["TARGET_SERVICE_NAME"]}.pem check #no-tls-tickets"
		;;
		"connect")
		# FIXME: use SRV records instead of catalog API
		CONSUL_CATALOG_URL="http://localhost:8500/v1/catalog/service/${UPSTREAM["DESTINATION_NAME"]}-sidecar-proxy"
		CATALOG_UPSTREAM_JSON=$($CURL ${CONSUL_CATALOG_URL} 2>>$LOGFILE)

		for row in $(jq -c .[] <<<${CATALOG_UPSTREAM_JSON})
		do
			UPSTREAM["SERVICE_PORT"]=$(jq -r .ServicePort <<<${row})
		    UPSTREAM["DESTINATION_SERVERS"]="server-template s_${UPSTREAM["DESTINATION_NAME"]} 20 ${UPSTREAM["DESTINATION_NAME"]}.connect.consul:${UPSTREAM["SERVICE_PORT"]} ssl resolvers consul ca-file ca.pem crt ${CONFIG["TARGET_SERVICE_NAME"]}.pem check #no-tls-tickets"
		done
		;;
	esac

	# custom parameters
	DESTINATION_MODE=$(jq -r .destination_mode <<<${1})
	if [ "${DESTINATION_MODE}" = "http" ]; then
		UPSTREAM["DESTINATION_MODE"]="mode http"
		UPSTREAM["LOG_FORMAT"]="option httplog"
	fi

	ADVANCED_CHECK=$(jq -r .advanced_check <<<${1})
	case ${ADVANCED_CHECK} in
	redis)
		UPSTREAM["ADVANCED_CHECK"]="option redis-check"
		;;
	esac
}

# write the upstream configuration into the config file
function upstream-write() {
	cat <<EOF >>${CONF_TMP_DIR}/${CONF_HAP_FILENAME}

frontend f_${UPSTREAM["DESTINATION_NAME"]}
 bind ${UPSTREAM["LOCAL_BIND_ADDRESS"]}:${UPSTREAM["LOCAL_BIND_PORT"]}
 ${UPSTREAM["DESTINATION_MODE"]}
 ${UPSTREAM["LOG_FORMAT"]}
 default_backend b_${UPSTREAM["DESTINATION_NAME"]}

backend b_${UPSTREAM["DESTINATION_NAME"]}
 ${UPSTREAM["DESTINATION_MODE"]}
 ${UPSTREAM["ADVANCED_CHECK"]}
 ${UPSTREAM["DESTINATION_SERVERS"]}
EOF
}

# dump content of the UPSTREAM variable
function upstream-dump() {
	for a in ${!UPSTREAM[@]}
	do
		echo "$a: ${UPSTREAM[$a]}" >>$LOGFILE
	done
}
### END OF UPSTREAM ###


### MAIN ###

# this function generates an HAProxy configuration in $CONF_TMP_DIR and returns:
#  0 if no error happened
#  1 if anything was wrong
function generate-cfg() {
	echo "GENERATING NEW CONFIGURATION" >>$LOGFILE

	# clear CERTS array, to ensure we monitor only certs we need to
	for cert in "${!CERTS[@]}"
	do
		unset -v CERTS[$cert]
	done

	config-init
	config-getdata
	config-dump

	ERROR="false"
	echo "" >>$LOGFILE
echo "DEBUG: Checking Conf dir"
	[ -z "${CONF_TMP_DIR}" ] && return 1
	rm -rf  ${CONF_TMP_DIR}
	mkdir -p ${CONF_TMP_DIR}
	mkdir -p ${CONFIG["CERTS_FOLDER"]}

echo "DEBUG: Saving leaf cert"
	# get cert and key for target service
	save-leaf-cert ${CONFIG["TARGET_SERVICE_NAME"]} ${CONF_TMP_DIR}/${CONF_CERTS_DIRNAME}

	# get CA root certificate
	${CURL} ${CONSUL_ROOTCA_URL} | jq -r .Roots[0].RootCert | sed -e 's/\\n/\n/g' > ${CONF_TMP_DIR}/${CONF_CERTS_DIRNAME}/ca.pem

	# Write configuration to file
	config-write

	# configuring upstreams
	for row in $(jq -c .Proxy.Upstreams[] <<<${CONSUL_PROXY_JSON})
	do
		upstream-init
		upstream-getdata "${row}"
		upstream-dump
		upstream-write
	done

	return 0
}


# blocking loop wait for an update on the connect proxy configuration piece
HASH="0"
OLDHASH="0"
while true;
do
	TMPFILE=$(mktemp)
	${CURL} --include --max-time 10  ${VERBOSE} --output ${TMPFILE} ${CONSUL_SERVICE_URL}?hash=${HASH} >${TMPFILE}

	RETCODE=$?
	# 28 is the return code when curl wait for 'max-time'
	if [ ${RETCODE} -eq 28 ]; then
		sleep 1
		rm ${TMPFILE}
		check-certs
		[ $? -gt 0 ] && do-reload
		continue
	fi
	# any other code than 0 may indicates an error, so we don't want to apply anything
	if [ ${RETCODE} -ne 0 ]; then
		sleep 1
		rm ${TMPFILE}
		continue
	fi

	STATUSCODE=$(head -n 1 ${TMPFILE} | cut -d' ' -f 2)
	if [ "${STATUSCODE}" != "200" ]; then
		sleep 1
		OLDHASH=${HASH}
		rm ${TMPFILE}
		continue
	fi
		
	HASH=$(sed -n 's/^X-Consul-Contenthash: \(.*\)\r/\1/p' ${TMPFILE})
	if [ -z "${HASH}" ]; then
		sleep 1
		rm ${TMPFILE}
		continue
	fi

	# the configuration has not changed
	if [ "${OLDHASH}" = "${HASH}" ]; then
		sleep 1
		rm ${TMPFILE}
		continue
	fi

	rm ${TMPFILE}

	generate-cfg
	[ $? -ne 0 ] && continue
	do-check
	[ $? -ne 0 ] && continue
	move-cfg ${CONF_TMP_DIR} ${CONF_PROD_DIR}
	[ $? -ne 0 ] && continue

	echo "APPLYING NEW CONFIGURATION" >>$LOGFILE
	do-reload

	sleep 1
done

