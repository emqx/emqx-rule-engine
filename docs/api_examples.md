#Rule-Engine-APIs



## ENVs

APPSECRET="5bce2ce904d5f8:Mjg2ODA3NTU0MjAzNTAzMTU1ODI3MzE5Mzg3MTU3Mjk5MjA"

## Rules

### create
```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules' -d \
'{"name":"test-rule","for":"message.publish","rawsql":"select * from \"t/a\"","actions":[{"name":"default:debug_action","params":{"a":1}}],"description":"test-rule"}'

{"code":0,"data":{"actions":[{"name":"default:debug_action","params":{"a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120126626615666","name":"test-rule","rawsql":"select * from \"t/a\""}}

## with a resource id in the action args
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules' -d \
'{"name":"test-rule","for":"message.publish","rawsql":"select * from \"t/a\"","actions":[{"name":"default:debug_action","params":{"$resource":"debug_resource_type:test-resource","a":1}}],"description":"test-rule"}'

{"code":0,"data":{"actions":[{"name":"default:debug_action","params":{"$resource":"debug_resource_type:test-resource","a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120233443199609","name":"test-rule","rawsql":"select * from \"t/a\""}}
```

### show
```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/rules/test-rule:1555120233443199609'

{"code":0,"data":{"actions":[{"name":"default:debug_action","params":{"$resource":"debug_resource_type:test-resource","a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120233443199609","name":"test-rule","rawsql":"select * from \"t/a\""}}
```

### list

```shell
$ curl -v --basic -u $APPSECRET -k http://localhost:8080/api/v3/rules

{"code":0,"data":[{"actions":[{"name":"default:debug_action","params":{"a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120126626615666","name":"test-rule","rawsql":"select * from \"t/a\""},{"actions":[{"name":"default:debug_action","params":{"$resource":"debug_resource_type:test-resource","a":1}}],"description":"test-rule","enabled":true,"id":"test-rule:1555120233443199609","name":"test-rule","rawsql":"select * from \"t/a\""}]}
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

{"code":0,"data":[{"app":"emqx_rule_engine","description":"Debug Action","name":"default:debug_action","params":{"$resource":"debug_resource_type"}},{"app":"emqx_rule_engine","description":"Republish a MQTT message","name":"default:republish_message","params":{"$resource":"debug_resource_type","from":"topic","to":"topic"}}]}
```



### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/actions/default:debug_action'

{"code":0,"data":{"app":"emqx_rule_engine","description":"Debug Action","name":"default:debug_action","params":{"$resource":"debug_resource_type"}}}
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

{"code":0,"data":[{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","name":"test-resource","type":"debug_resource_type"}]}
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

{"code":0,"data":{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","name":"test-resource","type":"debug_resource_type"}}
```

### list

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources'

{"code":0,"data":[{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","name":"test-resource","type":"debug_resource_type"}]}
```



### show

```shell
$ curl -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources/debug_resource_type:test-resource'

{"code":0,"data":{"attrs":"undefined","config":{"a":1},"description":"test-rule","id":"debug_resource_type:test-resource","name":"test-resource","type":"debug_resource_type"}}
```



### delete

```shell
$ curl -XDELETE -v --basic -u $APPSECRET -k 'http://localhost:8080/api/v3/resources/debug_resource_type:test-resource'

{"code":0}
```

