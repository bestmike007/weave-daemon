FROM docker:1.11
MAINTAINER Yuanhai He <i@bestmike007.com>

COPY startup-script.sh /start
RUN curl -sSL -o /usr/local/bin/weave git.io/weave && \
    chmod a+x /usr/local/bin/weave /start && \
    apk add --no-cache iptables && \
    cat /usr/local/bin/weave | grep -e ^SCRIPT_VERSION | cut -d'"' -f 2

ENTRYPOINT ["/start"]
