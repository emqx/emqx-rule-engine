
# emqx-rule-engine

MQTT Message Routing Rule Engine for EMQ X Broker.

## Concept

```
when
    <conditions> | <predicates>
then
    <action>;
```

Rule matching

```
rule "Rule Name"
  when
    rule match
  select
    para1 = val1
    para2 = val2
  then
    action(#{para2 => val1, #para2 => val2})
```

## Architecture


```
          |-----------------|
   P ---->| Message Routing |----> S
          |-----------------|
               |     /|\
              \|/     |
          |-----------------|
          |   Rule Engine   |
          |-----------------|
               |      |
            Backends  Bridges
```

## Rule

A rule consists of a SQL SELECT statement, a topic filter, and a rule action

## Action

Define a rule action in ADT:

```
action :: Application -> Resource -> Params -> IO ()
```

A rule action:

Module:function(Args)

## Design

```
Event | Message -> Rule Match -> Execute Action
```


## REST API

## CLI

rules list
rules show
rule-actions list

## License

Copyright (c) 2019 [EMQ Technologies Co., Ltd](https://emqx.io). All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");you may not use this file except in compliance with the License.You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.

