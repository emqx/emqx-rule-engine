#Rule-Engine-APIs



## ENVs

APPSECRET="5bce2ce904d5f8:Mjg2ODA3NTU0MjAzNTAzMTU1ODI3MzE5Mzg3MTU3Mjk5MjA"

## Rules

### create
```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules' -d \
'{"name":"test-rule","for":"message.publish","rawsql":"select * from \"t/a\"","actions":[{"name":"built_in:inspect_action","params":{"a":1}}],"description":"test-rule"}'

{"code":0,"data":{"actions":[{"name":"built_in:inspect_action","params":{"a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120126626615666","name":"test-rule","rawsql":"select * from \"t/a\""}}

## with a resource id in the action args
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules' -d \
'{"name":"test-rule","for":"message.publish","rawsql":"select * from \"t/a\"","actions":[{"name":"built_in:inspect_action","params":{"$resource":"built_in:test-resource","a":1}}],"description":"test-rule"}'

{"code":0,"data":{"actions":[{"name":"built_in:inspect_action","params":{"$resource":"built_in:test-resource","a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120233443199609","name":"test-rule","rawsql":"select * from \"t/a\""}}
```

### show
```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules/test-rule:1555120233443199609'

{"code":0,"data":{"actions":[{"name":"built_in:inspect_action","params":{"$resource":"built_in:test-resource","a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120233443199609","name":"test-rule","rawsql":"select * from \"t/a\""}}
```

### list

```shell
$ curl -v --basic -u $APPSECRET -k http://localhost:8080/api/v3/rules

{"code":0,"data":[{"actions":[{"name":"built_in:inspect_action","params":{"a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120126626615666","name":"test-rule","rawsql":"select * from \"t/a\""},{"actions":[{"name":"built_in:inspect_action","params":{"$resource":"built_in:test-resource","a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120233443199609","name":"test-rule","rawsql":"select * from \"t/a\""}]}
```

### delete

```shell
$ curl -XDELETE -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules/test-rule:1555120233443199609'

{"code":0}
```



## Actions

### list

```shell
$ curl -v --basic -u $APPSECRET -k http://localhost:8080/api/v3/actions

{"code":0,"data":[{"app":"emqx_rule_engine","description":"Debug Action","name":"built_in:inspect_action","params":{"$resource":"built_in"}},{"app":"emqx_rule_engine","description":"Republish a MQTT message","name":"built_in:republish_action","params":{"$resource":"built_in","from":"topic","to":"topic"}}]}
```

### list all actions of a resource type

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resource_types/built_in/actions'

{"code":0,"data":[{"app":"emqx_rule_engine","description":"Debug Action","name":"built_in:inspect_action","params":{},"type":"built_in"},{"app":"emqx_rule_engine","description":"Republish a MQTT message","name":"built_in:republish_action","params":{"from":"topic","to":"topic"},"type":"built_in"}]}
```



### list all actions of a hook type

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/actions?for=message.publish'

{"app":"emqx_rule_engine","description":"Republish a MQTT message","name":"built_in:republish_action","params":{"from":"topic","to":"topic"},"type":"built_in"}]}

$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/actions?for=$messages'

{"code":0,"data":[{"app":"emqx_rule_engine","description":"Debug Action","for":"$any","name":"built_in:inspect_action","params":{},"type":"built_in"},{"app":"emqx_rule_engine","description":"Republish a MQTT message","for":"message.publish","name":"built_in:republish_action","params":{"from":"topic","to":"topic"},"type":"built_in"},{"app":"emqx_web_hook","description":"Forward Messages to Web Server","for":"message.publish","name":"web_hook:publish_action","params":{"$resource":"web_hook"},"type":"web_hook"}]}

$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/actions?for=$events'

{"code":0,"data":[{"app":"emqx_web_hook","description":"Forward Events to Web Server","for":"$events","name":"web_hook:event_action","params":{"$resource":"web_hook","template":"json"},"type":"web_hook"},{"app":"emqx_rule_engine","description":"Debug Action","for":"$any","name":"built_in:inspect_action","params":{},"type":"built_in"}]}


```



### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/actions/built_in:inspect_action'

{"code":0,"data":{"app":"emqx_rule_engine","description":"Debug Action","name":"built_in:inspect_action","params":{"$resource":"built_in"}}}
```



## Resource Types

### list

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resource_types'

{"code":0,"data":[{"description":"Debug resource type","name":"built_in","params":{},"provider":"emqx_rule_engine"}]}
```

### list all resources of a type

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resource_types/built_in/resources'

{"code":0,"data":[{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"built_in:test-resource","name":"test-resource","type":"built_in"}]}
```

### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resource_types/built_in'

{"code":0,"data":{"description":"Debug resource type","name":"built_in","params":{},"provider":"emqx_rule_engine"}}
```



## Resources

### create

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources' -d \
'{"name":"test-resource", "type": "built_in", "config": {"a":1}, "description": "test-rule"}'

{"code":0,"data":{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"built_in:test-resource","name":"test-resource","type":"built_in"}}
```

### list

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources'

{"code":0,"data":[{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"built_in:test-resource","name":"test-resource","type":"built_in"}]}
```



### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources/built_in:test-resource'

{"code":0,"data":{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"built_in:test-resource","name":"test-resource","type":"built_in"}}
```



### delete

```shell
$ curl -XDELETE -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources/built_in:test-resource'

{"code":0}
```

## Rule example using webhook

``` shell

$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources' -d \
'{"name":"webhook1", "type": "web_hook", "config": {"url": "http://127.0.0.1:9910", "headers": [{"key":"token", "value":"axfw34y235wrq234t4ersgw4t"}], "method": "POST"}, "description": "web hook resource-1"}'

curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules' -d \
'{"name":"connected_msg_to_http","for":"client.connected","rawsql":"select * from \"#\"","actions":[{"name":"web_hook:event_action","params":{"$resource": "web_hook:webhook1", "template": {"client": "${client_id}", "user": "${username}", "c": {"u": "${username}", "e": "${e}"}}}}],"description":"Forward connected events to webhook"}'

```

Start a `web server` using `nc`, and then connect to emqx broker using a mqtt client with username = 'Shawn':

```shell
nc -l 127.0.0.1 9910

POST / HTTP/1.1
content-type: application/json
content-length: 80
te:
host: 127.0.0.1:9910
connection: keep-alive
token: axfw34y235wrq234t4ersgw4t

{"client":"clientId-E7EYzGa6HK","user":"Shawn","c":{"u":"Shawn","e":null}}

```