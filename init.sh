#!/bin/bash

test -e /config/fluentd.conf || ( 
    [[ -z "$FLUENTBASECONF" ]] || echo "$FLUENTBASECONF"|base64 -d > /config/fluentd.conf
)

[[ -z "$AUTHPW" ]] && { 
    AUTHPW=$(for rounds in $(seq 1 24);do cat /dev/urandom |tr -cd '[:alnum:]_\-.'  |head -c48;echo ;done|grep -e "_" -e "\-" -e "\."|grep ^[a-zA-Z0-9]|grep [a-zA-Z0-9]$|tail -n1)
    echo "WARN: you did not set the AUTHPW environment aka the password for the write user ..using temporary value $AUTHPW" 
echo -n ; } ;

[[ -z "$AUTHPW" ]] && { echo "NO UNAUTHENTICATED MODE ALLOWED..EXITING..";         sleep 1;exit 2 ; } ;
test -e /config/fluentd.conf || { echo "/config/fluentd.conf missing .. mount as volume OR set FLUENTBASECONF ...EXITING..";sleep 1;exit 2 ; } ;

htpasswd -bBc /etc/nginx/.htpasswd write "$AUTHPW"

AUTHPW=$(for rounds in $(seq 1 24);do cat /dev/urandom |tr -cd '[:alnum:]_\-.'  |head -c48;echo ;done|grep -e "_" -e "\-" -e "\."|grep ^[a-zA-Z0-9]|grep [a-zA-Z0-9]$|tail -n1)


echo ' ## auto-generated nginx config
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	location /healthcheck {
		root /var/www/html;
	}
    acccess_log /dev/stdout;
    error_log /dev/stderr;
	# Everything is a 404
	location / {
		proxy_pass http://127.0.0.1:7777/;
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


echo starting fluent 
(
sleep 0.5
mkdir /var/cache/fluentd
chown fluentd:fluentd /var/cache/fluentd
while (true);do 
   fluentd -c /config/fluentd.conf;sleep 3
done ) & 

#echo starting caddy
#(sleep 0.5; cd /caddy;while (true);do caddy run ;sleep 1 ;done)
#(sleep 0.5; cd /caddy;while (true);do su -s /bin/bash -c "caddy run" caddy ;sleep 1 ;done)

echo starting nginx
(sleep 0.5; while (true);do nginx -g "daemon off;";sleep 1 ;done)