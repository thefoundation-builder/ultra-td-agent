FROM alpine
# Work path
WORKDIR /scripts


# Installing dependencies
#RUN apk --update add --no-cache ruby ruby-irb su-exec nginx caddy bash curl nano
RUN apk --update add --no-cache ruby ruby-irb su-exec bash curl nano
# Creating user Fluentd
RUN addgroup fluentd && \
        adduser -s /bin/false -G fluentd -S -D fluentd
# Installing Fluentd + plugins S3 & ES

RUN apk --update add --no-cache --virtual .build-deps build-base libc-dev ruby-dev && \
  echo 'gem: --no-document' >> /etc/gemrc && \ 
        gem install oj && \
        gem install json && \
        gem install fluentd && \
        apk del  .build-deps

RUN apk --update add --no-cache --virtual .build-deps build-base libc-dev ruby-dev && \
        gem install fluent-plugin-elasticsearch && \
        gem install fluent-plugin-encrypt fluent-plugin-mail  fluent-plugin-snmp  fluent-plugin-secure-forward && \
        gem install nokogiri && \
 fluent-gem install fluent-plugin-s3 && \
 fluent-gem install fluent-plugin-couch --no-document && \
 fluent-gem install fluent-plugin-influxdb-v2 --no-document && \
        apk del  .build-deps

#        gem install fluent-plugin-collectd-influxdb && \
#        gem install fluent-plugin-collectd-concat && \
RUN apk --update add --no-cache bash curl nano jq nginx git apache2-utils coreutils procps 


## setup 

RUN mkdir /caddy  && sed 's~/ash$~/bash~' -i /etc/passwd
EXPOSE 80/tcp 24224 24224/udp 514 514/udp
COPY init.sh /
RUN chmod +x /init.sh
ENTRYPOINT [ "/init.sh" ]
RUN mkdir -p /var/www/html/healthcheck && ( echo "OK=ALIVE" > /var/www/html/healthcheck/index.html ;cp /var/www/html/healthcheck/index.html /var/www/html/healthcheck.html ) 
HEALTHCHECK CMD curl -s 127.0.0.1/healthcheck
VOLUME /config
RUN git clone https://gitlab.com/the-foundation/bash-logger.git /etc/bash-logger
COPY nginx-status2influx.sh /etc/nginx-status2influx.sh
RUN date > /etc/_BUILDTIME

