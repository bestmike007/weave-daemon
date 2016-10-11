FROM docker:1.11.2
MAINTAINER Yuanhai He <i@bestmike007.com>

ADD startup-script.sh /start
ENV WEAVE_VERSION=1.6.2 \
    DOCKER_VERSION=1.11.2
RUN curl -sSL -o /usr/local/bin/weave https://github.com/weaveworks/weave/releases/download/v${WEAVE_VERSION}/weave && \
    chmod a+x /usr/local/bin/weave /start && \
    apk add --no-cache iptables
ENTRYPOINT ["/start"]
