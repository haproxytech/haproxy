FROM ubuntu:trusty
MAINTAINER Baptiste Assmann <bassmann@haproxy.com>

EXPOSE 8514/udp

ADD rsyslogd.conf /
ADD rsyslogd.sh /

ENTRYPOINT ["/rsyslogd.sh"]

