FROM alpine

ADD ./init-scripts /tmp/init-scripts
VOLUME /tmp/init-scripts
