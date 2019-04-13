#Rule-Engine-CLIs

## Rules

### create
```shell
$ ./bin/emqx_ctl rules create 'steven_msg_to_http' 'message.publish' 'SELECT payload FROM "#" where user=Steven' '{"emqx_web_hook:forward_action": {"$resource": "web_hook:webhook1", "url": "http://www.baidu.com"}}' -d "Forward msgs from clientid=Steven to webhook"

Rule steven_msg_to_http:1555136538740282000 created
```

### show
```shell
$ ./bin/emqx_ctl rules show steven_msg_to_http:1555136538740282000

rule(steven_msg_to_http:1555136538740282000, name=steven_msg_to_http, for=message.publish, rawsql=SELECT payload FROM "#" where user=Steven, actions=['emqx_web_hook:forward_action'], enabled=true, description=Forward msgs from clientid=Steven to webhook)
```

### list

```shell
$ curl -v --basic -u $APPSECRET -k http://localhost:8080/api/v3/rules

{"code":0,"data":[{"actions":["default:debug_action"],"description":"Rule for debug","enabled":true,"id":"inspect:1554792545782692586","name":"inspect","rawsql":"select * from t1"}]}
```

### delete

```shell
$ curl -XDELETE -v --basic -u $APPSECRET -k http://localhost:8080/api/v3/rules/inspect:1554792545782692586

{"code":0}
```



## Actions

### list

```shell
$ curl -v --basic -u $APPSECRET -k http://localhost:8080/api/v3/actions

{"code":0,"data":[{"app":"emqx_rule_engine","description":"Debug Action","name":"default:debug_action","params":{}},{"app":"emqx_rule_engine","description":"Republish a MQTT message","name":"default:republish_message","params":{"from":"topic","to":"topic"}}]}
```



### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/actions/default:debug_action'

{"code":0,"data":{"app":"emqx_rule_engine","description":"Debug Action","name":"default:debug_action","params":{}}}
```



## Resource Types

### list

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resource_types'

{"code":0,"data":[{"description":"Debug resource type","name":"debug_resource_type","params":{},"provider":"emqx_rule_engine"}]}
```

### list all resources of a type

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resource_types/debug_resource_type/resources'

{"code":0,"data":[{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","type":"debug_resource_type"}]}
```

### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resource_types/debug_resource_type'

{"code":0,"data":{"description":"Debug resource type","name":"debug_resource_type","params":{},"provider":"emqx_rule_engine"}}
```



## Resources

### create

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources' -d \
'{"name":"test-resource", "type": "debug_resource_type", "config": {"a":1}, "description": "test-rule"}'

{"code":0,"data":{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","type":"debug_resource_type"}}
```

### list

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources'

{"code":0,"data":[{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","type":"debug_resource_type"}]}
```



### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources/debug_resource_type:test-resource'

{"code":0,"data":{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","type":"debug_resource_type"}}
```



### delete

```shell
$ curl -XDELETE -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources/debug_resource_type:test-res'

{"code":0}
```

