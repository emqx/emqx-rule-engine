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

{"code":0,"data":[{"app":"emqx_rule_engine","description":"Debug Action","name":"built_in:inspect_action","params":{"$resource":"built_in"}},{"app":"emqx_rule_engine","description":"Republish a MQTT message","name":"built_in:republish_message","params":{"$resource":"built_in","from":"topic","to":"topic"}}]}
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

