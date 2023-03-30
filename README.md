TD-Agent Docker image , alpine based , http basic auth + /healtcheck endpoint 
===

## Status
[![Build](https://github.com/thefoundation-builder/ultra-td-agent/actions/workflows/build.yml/badge.svg)](https://github.com/thefoundation-builder/ultra-td-agent/actions/workflows/build.yml)


## Variables 
| Name | Thingy |
|--|--|
| `AUTHPW` | basic auth password for the write user |
| `FLUENTBASECONF` | base64 encoded fluentd config file when things are server-less/volume-less |


## Fluent Plugins
* fluent-plugin-mail
* fluent-plugin-snmp
* fluent-plugin-encrypt
* fluent-plugin-secure-forward
* fluent-plugin-s3
* fluent-plugin-influxdb-v2
* fluent-plugin-elasticsearch
* fluent-plugin-couch


---
`caddy` aka `crappy` was changed against nginx , their config-way is just too senseless to even read it

