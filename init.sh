#!/bin/bash

test -e /etc/bash-logger/log-to-influxdb2.sh || git clone https://gitlab.com/the-foundation/bash-logger.git /etc/bash-logger

echo ' ## auto-generated nginx config
upstream fluentbackend {
  server 127.0.0.1:7777;
  keepalive 32;
}
map $request_method $methloggable {
       # volatile;
#default       $statusloggable;
default       0;
POST          1;
OPTIONS       1;
GET           1;
PUT           1;
}
map $http_user_agent $ualoggable {
       # volatile;

~Pingdom 0;
~Amazon-Route53 0;
~kube-check 0;
default $methloggable;

}
map $status $statusloggable {
        #volatile;
#    ~^[36789]  0;
    200         1;
    204         0;
    301         0;
    302         0;
    499         0; ## client disconnected → HTTP/1.1" 499 → uptime monitors will quit on first keyword and produce tons of 499
    default    $ualoggable;
}
map $request_uri $urlregxloggable {
      #  volatile;
    (.*?)healthcheck(.*?) 0;
    (.*?)ip_info(.*?)     1;
    default $statusloggable;
    }
map $request_uri $loggable {
  /ping                      0;
  /healthcheck.html          0;
  /healthcheck               0;
  /healthcheck_full          1;
  /ip_info                   1;

  default $urlregxloggable;
}

map $status $errorloggable {
    499        0; ## client disconnected → HTTP/1.1" 499 → uptime monitors will quit on first keyword and produce tons of 499
    default    1;
}
access_log    /dev/stdout main if=$loggable;
#error_log    /dev/stderr warn if=$errorloggable;
error_log    /dev/stderr warn ;

server {
	listen 80 default_server;
	listen [::]:80 default_server;

	##location = /healthcheck {
	##	rewrite ^(.*[^/])$ $1/ permanent;
	##}
	#location /healthcheck {
	#	root /var/www/html;
	#}
    location = /healthcheck {    
        add_header Content-Type text/plain;
        return 200 'OK=ALIVE';
        }
    location /healthcheck/ {    
        add_header Content-Type text/plain;
        return 200 'OK=ALIVE';
        }
    access_log /dev/stdout;
    error_log /dev/stderr;
	# Everything is a 404
	location / {
		proxy_set_header Accept-Encoding "";
		proxy_set_header Authorization "";
		proxy_set_header Host "127.0.0.1";
		proxy_set_header Connection "";
        proxy_http_version 1.1;

		if ($request_method = POST) {
		    proxy_pass http://fluentbackend;
		}
		if ($request_method = GET) {
			root /var/www/html/healthcheck;
		}
        try_files $uri $uri/ =404;
    auth_basic "Restricted Content";
    auth_basic_user_file /etc/nginx/.htpasswd;
	}
        

	# You may need this to prevent return 404 recursion.
	location = /404.html {
		internal;
	}
}
' > /etc/nginx/http.d/default.conf

nginx -T || echo failed nginx conf
nginx -t || sleep 2
nginx -t || exit 1


test -e /config || mkdir /config
test -e /config/fluentd.conf || ( 
    [[ -z "$FLUENTBASECONF" ]] || echo "$FLUENTBASECONF"|base64 -d > /config/fluentd.conf
)

[[ -z "$AUTHPW" ]] && { 
    AUTHPW=$(for rounds in $(seq 1 24);do cat /dev/urandom |tr -cd '[:alnum:]_\-.'  |head -c48;echo ;done|grep -e "_" -e "\-" -e "\."|grep ^[a-zA-Z0-9]|grep [a-zA-Z0-9]$|tail -n1)
    echo "WARN: you did not set the AUTHPW environment aka the password for the write user ..using temporary value $AUTHPW" 
echo -n ; } ;

[[ -z "$AUTHPW" ]]           && { echo "NO UNAUTHENTICATED MODE ALLOWED..EXITING..";                                        sleep 1;exit 2 ; } ;
test -e /config/fluentd.conf || { echo "/config/fluentd.conf missing .. mount as volume OR set FLUENTBASECONF ...EXITING..";sleep 1;exit 2 ; } ;

htpasswd -bBc /etc/nginx/.htpasswd write "$AUTHPW"

AUTHPW=$(for rounds in $(seq 1 24);do cat /dev/urandom |tr -cd '[:alnum:]_\-.'  |head -c48;echo ;done|grep -e "_" -e "\-" -e "\."|grep ^[a-zA-Z0-9]|grep [a-zA-Z0-9]$|tail -n1)




###echo '
###{ 
###auto_https disable_redirects
###log
###}
###:80, :44444 {
###
####    http_port 80
###    # Debug
###    {$DEBUG}
###    # HTTP/3 support
####    servers {
####        protocol {
####            experimental_http3
####        }
####    }
###
###@auth {
###    not path /lists
###}
###
###basicauth * {
###	write '$(caddy hash-password --plaintext $AUTHPW)'
###}
###
#### add this directive
###handle_path /healthcheck {
###    root * /var/www/html
###    file_server
###}
###route {
###reverse_proxy :7777
###
###}
###
###}
###
###
###log
###
###' > /caddy/Caddyfile 


#URL=$1
#BUCKET=$2
#INSECURE=$3
#TAG=$4
#AUTH=$5
#HOST=$6
#SEVERITY=$7


influx_possible="yes"
[[ -z "$INFLUXTAG" ]]       && INFLUXTAG=fluentd
[[ -z "$INFLUXURL" ]]       && influx_possible="no"
[[ -z "$INFLUXAUTH" ]]      && influx_possible="no"
[[ -z "$INFLUXINSECURE" ]]  && INFLUXINSECURE=INSECURE

[[ -z "$INFLUXBUCKET" ]]    && INFLUXBUCKET="syslog"
[[ -z "$INFLUXHOST" ]]      && INFLUXHOST=fluentd.influx.lan
[[ -z "$SEVERITY" ]]        && SEVERITY=info

test -e /etc/bash-logger/log-to-influxdb2.sh || influx_possible="no"

echo "INFLUX_POSSIBLE=$influx_possible"

[[ -z "$INFLUXURL" ]]       && echo NO INFLUX URL
[[ -z "$INFLUXAUTH" ]]       && echo NO INFLUX AUTH

echo $(date) starting fluent 
(
sleep 0.5
mkdir /var/cache/fluentd
chown fluentd:fluentd /var/cache/fluentd


while (true);do 

   [[ "$influx_possible" = "yes" ]] || fluentd -c /config/fluentd.conf;
   [[ "$influx_possible" = "yes" ]] && ( 
    echo "logging fluent 2 influx"
	test -e /tmp/err.agent || mkfifo /tmp/err.agent
	test -e /tmp/out.agent || mkfifo /tmp/out.agent
	(   
        (
        agenterrinflux_opts=" $INFLUXURL $INFLUXBUCKET TRUE ${INFLUXTAG}_agent ${INFLUXAUTH} ${INFLUXHOST} error"
		 tail -qF /tmp/err.agent |cat| bash /etc/bash-logger/log-to-influxdb2.sh $agenterrinflux_opts  ) &
    LOGGER_AGENT_ERR_PID=$?
    agentoutinflux_opts=" $INFLUXURL $INFLUXBUCKET TRUE ${INFLUXTAG}_agent ${INFLUXAUTH} ${INFLUXHOST} ${SEVERITY}"
	fluentd -c /config/fluentd.conf 2>/tmp/err.agent  | bash /etc/bash-logger/log-to-influxdb2.sh $agentoutinflux_opts
    kill $LOGGER_AGENT_ERR_PID
    ) ## end influx
   
   sleep 3
done ) & 

#echo starting caddy
#(sleep 0.5; cd /caddy;while (true);do caddy run ;sleep 1 ;done)
#(sleep 0.5; cd /caddy;while (true);do su -s /bin/bash -c "caddy run" caddy ;sleep 1 ;done)
#nginx -T


echo $(date) starting nginx

	sleep 0.5; while (true);do
   [[ "$influx_possible" = "yes" ]] || nginx -g "daemon off;";
   [[ "$influx_possible" = "yes" ]] && ( 
	test -e /tmp/err.nginx || mkfifo /tmp/err.nginx
	test -e /tmp/out.nginx || mkfifo /tmp/out.nginx
    (  
        (   
        errinflux_opts=" $INFLUXURL $INFLUXBUCKET TRUE ${INFLUXTAG}_nginx ${INFLUXAUTH} ${INFLUXHOST} error"
		tail -qF /tmp/err.nginx ||cat| bash /etc/bash-logger/log-to-influxdb2.sh $errinflux_opts  ) &
    LOGGER_NGINX_ERR_PID=$?;
    outinflux_opts=" $INFLUXURL $INFLUXBUCKET TRUE ${INFLUXTAG}_nginx ${INFLUXAUTH} ${INFLUXHOST} ${SEVERITY}"
	echo "logging nginx 2 influx"
	nginx -g "daemon off;"  2>/tmp/err.nginx | bash /etc/bash-logger/log-to-influxdb2.sh $outinflux_opts 
	kill $LOGGER_NGINX_OUT_PID $LOGGER_NGINX_ERR_PID
   )

 sleep 2   ;done 

