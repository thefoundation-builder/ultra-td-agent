#!/bin/bash
## logger that sends STDIN to influxdb2 http(s):// endpoints with optional TOKEN auth
date -u +%s > /dev/shm/.nginx_status_start_time
## STAGE:PREPARE
URL=$1
BUCKET=$2
INSECURE=$3
TAG=$4
AUTH=$5
HOST=$6
SEVERITY=$7


[[ -z "$URL" ]]                && echo "FAILED:NO_URL_GIVEN"
[[ -z "$URL" ]]                && exit 1

[[ -z "$BUCKET" ]]             && echo "FAILED:NO_BUCKET_GIVEN"
[[ -z "$BUCKET" ]]             && exit 1

[[ -z "$TAG" ]]                && echo "FAILED:NO_TAG_GIVEN"
[[ -z "$TAG" ]]                && exit 1


[[ -z "$AUTH" ]]               || TOK="$AUTH"
[[ -z "$SEVERITY" ]]           || SEVPART=",severity=$SEVERITY"
[[ -z "$HOST" ]]               || MYHOST="$HOST"
[[ -z "$HOST" ]]               && MYHOST="$(hostname -f)"

[[ "$INSECURE" = "INSECURE" ]] &&  SSLPART=" -k "

#while IFS='' read line;do 
function gen_influx_value() {
   stampd=$(date +%s)
   stampn=$(date +%N)
   [[ -z "$stampn" ]] && stampn=000000000
   echo "$1"',tag="'$TAG'",host='"$MYHOST$SEVPART"' value='"$2"' '"$stampd$stampn"
echo -n ; } ;

while (true);do 

#    msg=$(echo -n "$line"|jq -R -s '.' )
(
nginx_stats=$(curl -s 127.0.0.1/nginx_status)

[[ -z "$nginx_stats" ]] || (
gen_influx_value nginx_active_connections   $(echo "$nginx_stats" | awk '/^Active connections:/{print $3}')
#echo accepts handled requests

secondsrun=$(( $(date -u +%s) - $(cat /dev/shm/.nginx_status_start_time)  ))
[[ "$secondsrun" = "0" ]] && secondsrun=1 # prevent zero division

gen_influx_value nginx_connections_accepted $( echo "$nginx_stats"|head -n3|tail -n1|cut -d" " -f2);
gen_influx_value nginx_connections_handled  $( echo "$nginx_stats"|head -n3|tail -n1|cut -d" " -f3);
gen_influx_value nginx_connections_requests $( echo "$nginx_stats"|head -n3|tail -n1|cut -d" " -f4);
gen_influx_value nginx_stats_per_second_requests    $(( $( echo "$nginx_stats"|head -n3|tail -n1|cut -d" " -f2) / $secondsrun )) ;
gen_influx_value nginx_stats_per_second_connections $(( $( echo "$nginx_stats"|head -n3|tail -n1|cut -d" " -f4) / $secondsrun )) ;

gen_influx_value nginx_reading $(echo "$nginx_stats" | awk '/^Reading:/{print $2}')
gen_influx_value nginx_writing $(echo "$nginx_stats" | awk '/^Reading:/{print $4}')
gen_influx_value nginx_waiting $(echo "$nginx_stats" | awk '/^Reading:/{print $6}')

)| curl -s --retry-delay 30 --retry 3 -X POST   $SSLPART --header "Authorization: Token $TOK"  "$URL"'/api/v2/write?bucket='"$BUCKET"'&precision=ns' -s  --data-binary @/dev/stdin ;

) # end empty stats


sleep 42
done
