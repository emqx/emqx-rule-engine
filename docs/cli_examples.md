#Rule-Engine-CLIs

## Enable webhook

```shell
./bin/emqx_ctl plugins load emqx_web_hook
```

## Rules

### create

```shell
$ ./bin/emqx_ctl rules create 'steven_msg_to_http' 'message.publish' 'SELECT payload FROM "#" where user=Steven' '{"emqx_web_hook:forward_action": {"$resource": "web_hook:webhook1", "url": "http://www.baidu.com"}}' -d "Forward msgs from clientid=Steven to webhook"

Rule steven_msg_to_http:1555138068602953000 created
```

### show

```shell
$ ./bin/emqx_ctl rules show steven_msg_to_http:1555138068602953000

rule(id=steven_msg_to_http:1555138068602953000, name=steven_msg_to_http, for=message.publish, rawsql=SELECT payload FROM "#" where user=Steven, actions=<<"[{\"name\":\"emqx_web_hook:forward_action\",\"params\":{\"$resource\":\"web_hook:webhook1\",\"url\":\"http://www.baidu.com\"}}]">>, enabled=true, description=Forward msgs from clientid=Steven to webhook)
```

### list

```shell
$ ./bin/emqx_ctl rules list

rule(id=steven_msg_to_http:1555138068602953000, name=steven_msg_to_http, for=message.publish, rawsql=SELECT payload FROM "#" where user=Steven, actions=<<"[{\"name\":\"emqx_web_hook:forward_action\",\"params\":{\"$resource\":\"web_hook:webhook1\",\"url\":\"http://www.baidu.com\"}}]">>, enabled=true, description=Forward msgs from clientid=Steven to webhook)

```

### delete

```shell
$ ./bin/emqx_ctl rules delete 'steven_msg_to_http:1555138068602953000'

ok
```

## Actions

### list

```shell
$ ./bin/emqx_ctl rule-actions list

action(name=built_in:inspect_action, app=emqx_rule_engine, params=#{'$resource' => built_in}, description=Debug Action)
action(name=emqx_web_hook:forward_action, app=emqx_web_hook, params=#{'$resource' => web_hook,url => string}, description=Forward a MQTT message)
action(name=built_in:republish_message, app=emqx_rule_engine, params=#{'$resource' => built_in,from => topic,to => topic}, description=Republish a MQTT message)
```

### show

```shell
$ ./bin/emqx_ctl rule-actions show 'emqx_web_hook:forward_action'

action(name=emqx_web_hook:forward_action, app=emqx_web_hook, params=#{'$resource' => web_hook,url => string}, description=Forward a MQTT message)
```

## Resource

### create

```shell
$ ./bin/emqx_ctl resources create 'webhook1' 'web_hook' '{"url": "http://host-name/chats"}'

Resource web_hook:webhook1 created
```

### list

```shell
$ ./bin/emqx_ctl resources list

resource(id=web_hook:webhook1, name=webhook1, type=web_hook, config=#{}, attrs=undefined, description=)

```

### list all resources of a type

```shell
$ ./bin/emqx_ctl resources list -t 'web_hook'

resource(id=web_hook:webhook1, name=webhook1, type=web_hook, config=#{}, attrs=undefined, description=)

```

### show

```shell
$ ./bin/emqx_ctl resources show 'web_hook:webhook1'

resource(id=web_hook:webhook1, name=webhook1, type=web_hook, config=#{}, attrs=undefined, description=)
```

### delete

```shell
$ ./bin/emqx_ctl resources delete 'web_hook:webhook1'

ok
```

## Resources Types

### list

```shell
$ ./bin/emqx_ctl resource-types list

resource_type(name=built_in, provider=emqx_rule_engine, params=#{}, on_create={emqx_rule_actions,on_resource_create}, description=Debug resource type)
resource_type(name=web_hook, provider=emqx_web_hook, params=#{}, on_create={emqx_web_hook_actions,on_resource_create}, description=WebHook Resource)
```

### show

```shell
$ ./bin/emqx_ctl resource-types show built_in

resource_type(name=built_in, provider=emqx_rule_engine, params=#{}, on_create={emqx_rule_actions,on_resource_create}, description=Debug resource type)
```
