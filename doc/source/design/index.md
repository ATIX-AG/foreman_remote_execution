---
layout: page
title: Design
countheads: true
toc: true
comments: true
---

Remote Execution Technology
===========================

User Stories
------------

- As a user I want to run commands in parallel across large number of
hosts

- As a user I want to run commands on a host in a different network
  segment (the host doesn't see the Foreman server/the Foreman server
  doesn't see the host directly)

- As a user I want to manage a host without installing an agent on it
  (just plain old ssh)

- As a community user I want to already existing remote execution
  technologies in combination with the Foreman

Design
------

### Ssh Single Host Push

{% plantuml %}
actor User
participant "Foreman Server" as Foreman
participant "Foreman Proxy" as Proxy
participant "Host" as Host

autonumber
User -> Foreman : UserCommand
Foreman -> Proxy : ProxyCommand
Proxy -> Host : SshCommand
Activate Host
Host --> Proxy : ProgressReport[1, Running]
Host --> Proxy : ProgressReport[2, Running]
Proxy --> Foreman : AccumulatedProgressReport[1, Running]
Host --> Proxy : ProgressReport[3, Running]
Host --> Proxy : ProgressReport[4, Finished]
Deactivate Host
Proxy --> Foreman : AccumulatedProgressReport[2, Finished]
{% endplantuml %}

UserCommand:

  * hosts: [host.example.com]
  * template: install-packages-ssh
  * input: { packages: ['vim-X11'] }

ProxyCommand:

  * host: host.example.com
  * provider: ssh
  * input: "yum install -y vim-X11"

SshCommand:

  * host: host.example.com
  * input: "yum install -y vim-X11"

ProgressReport[1, Running]:

  * output: "Resolving depednencies"

ProgressReport[2, Running]:

  * output: "installing libXt"

AccumulatedProgressReport[1, Running]:

  * output: { stdout: "Resolving depednencies\ninstalling libXt" }

ProgressReport[3, Running]:

  * output: "installing vim-X11"

ProgressReport[4, Finished]:

  * output: "operation finished successfully"
  * exit_code: 0

AccumulatedProgressReport[2, Finished]:

  * output: { stdout: "installing vim-X11\noperation finished successfully", exit_code: 0 }
  * success: true

### Ssh Single Host Pull

{% plantuml %}
actor User
participant "Foreman Server" as Foreman
participant "Foreman Proxy" as Proxy
participant "Host" as Host

autonumber
User -> Foreman : UserCommand
group Optional
  Foreman -> Proxy : EnforceCheckIn
  Proxy -> Host : EnforceCheckIn
end
Host -> Proxy : CheckIn
Proxy -> Foreman : CheckIn
Foreman --> Proxy : ProxyCommand
Proxy --> Host : Script
Activate Host
Host -> Proxy : ProgressReport[1, Running]
Host -> Proxy : ProgressReport[2, Running]
Proxy -> Foreman : AccumulatedProgressReport[1, Running]
Host -> Proxy : ProgressReport[3, Running]
Host -> Proxy : ProgressReport[4, Finished]
Deactivate Host
Proxy -> Foreman : AccumulatedProgressReport[2, Finished]
{% endplantuml %}

UserCommand:

  * hosts: [host.example.com]
  * template: install-packages-ssh
  * input: { packages: ['vim-X11'] }

ProxyCommand:

  * host: host.example.com
  * provider: ssh
  * input: "yum install -y vim-X11"

Script:

  * input: "yum install -y vim-X11"

ProgressReport[1, Running]:

  * output: "Resolving depednencies"

ProgressReport[2, Running]:

  * output: "installing libXt"

AccumulatedProgressReport[1, Running]:

  * output: { stdout: "Resolving depednencies\ninstalling libXt" }

ProgressReport[3, Running]:

  * output: "installing vim-X11"

ProgressReport[4, Finished]:

  * output: "operation finished successfully"
  * exit_code: 0

AccumulatedProgressReport[2, Finished]:

  * output: { stdout: "Resolving depednencies\ninstalling libXt", exit_code: 0 }
  * success: true

### Ssh Multi Host

{% plantuml %}
actor User
participant "Foreman Server" as Foreman
participant "Foreman Proxy" as Proxy
participant "Host 1" as Host1
participant "Host 2" as Host2

autonumber
User -> Foreman : UserCommand
Foreman -> Proxy : ProxyCommand[host1]
Foreman -> Proxy : ProxyCommand[host2]
Proxy -> Host1 : SshCommand
Proxy -> Host2 : SshCommand
{% endplantuml %}

UserCommand:

  * hosts: *.example.com
  * template: install-packages-ssh
  * input: { packages: ['vim-X11'] }

ProxyCommand[host1]:

  * host: host-1.example.com
  * provider: ssh
  * input: "yum install -y vim-X11"

ProxyCommand[host2]:

  * host: host-2.example.com
  * provider: ssh
  * input: "yum install -y vim-X11"

{% info_block %}
we might want to optimize the communication between server and
the proxy (sending collection of ProxyCommands in bulk, as well as
the AccumulatedProgerssReports). That would could also be utilized
by the Ansible implementation, where there might be optimization
on the invoking the ansible commands at once (the same might apply
to mcollective). On the other hand, this is more an optimization,
not required to be implemented from the day one: but it's good to have
this in mind
{% endinfo_block %}

### MCollective Single Host

{% plantuml %}
actor User
participant "Foreman Server" as Foreman
participant "Foreman Proxy" as Proxy
participant "AMQP" as AMQP
participant "Host" as Host

autonumber
User -> Foreman : UserCommand
Foreman -> Proxy : ProxyCommand
Proxy -> AMQP : MCOCommand
AMQP -> Host : MCOCommand
Activate Host
Host --> AMQP : ProgressReport[Finished]
Deactivate Host
AMQP --> Proxy : ProgressReport[Finished]
Proxy --> Foreman : AccumulatedProgressReport[Finished]
{% endplantuml %}

UserCommand:

  * hosts: [host.example.com]
  * template: install-packages-mco
  * input: { packages: ['vim-X11'] }

ProxyCommand:

  * host: host.example.com
  * provider: mcollective
  * input: { agent: package, args: { package => 'vim-X11' } }

MCOCommand:

  * host: host.example.com
  * input: { agent: package, args: { package => 'vim-X11' } }

ProgressReport[Finished]:

  * output: [ {"name":"vim-X11","tries":1,"version":"7.4.160-1","status":0,"release":"1.el7"},
              {"name":"libXt","tries":1,"version":"1.1.4-6","status":0,"release":"1.el7"} ]

AccumulatedProgressReport[Finished]:

  * output: [ {"name":"vim-X11","tries":1,"version":"7.4.160-1","status":0,"release":"1.el7"},
              {"name":"libXt","tries":1,"version":"1.1.4-6","status":0,"release":"1.el7"} ]
  * success: true

### Ansible Single Host

{% plantuml %}
actor User
participant "Foreman Server" as Foreman
participant "Foreman Proxy" as Proxy
participant "Host" as Host

autonumber
User -> Foreman : UserCommand
Foreman -> Proxy : ProxyCommand
Proxy -> Host : AnsibleCommand
Activate Host
Host --> Proxy : ProgressReport[Finished]
Deactivate Host
Proxy --> Foreman : AccumulatedProgressReport[Finished]

{% endplantuml %}

UserCommand:

  * hosts: [host.example.com]
  * template: install-packages-ansible
  * input: { packages: ['vim-X11'] }

ProxyCommand:

  * host: host.example.com
  * provider: ansible
  * input: { module: yum, args: { name: 'vim-X11', state: installed } }

AnsibleCommand:

  * host: host.example.com
  * provider: ansible
  * input: { module: yum, args: { name: 'vim-X11', state: installed } }

ProgressReport[Finished]:

  * output: { changed: true,
              rc: 0,
              results: ["Resolving depednencies\ninstalling libXt\ninstalling vim-X11\noperation finished successfully"] }

AccumulatedProgressReport[Finished]:

  * output: { changed: true,
              rc: 0,
              results: ["Resolving depednencies\ninstalling libXt\ninstalling vim-X11\noperation finished successfully"] }
  * success: true


Command Preparation
===================

User Stories
------------

- ?As a user I want to be able to specify default number of tries per command. # Command preparation?

- ?As a user I want to be able to specify default retry interval per command. # Command preparation?

- ?As a user I want to be able to specify default splay time per command. # Command preparation?

- ?As a user I want to setup default timeout per command. # Command preparation?


Design
------

{% plantuml %}

class ConfigTemplate {
  name:string
  template: string
  job_name: string
  retry_count: integer
  retry_interval: integer
  splay: integer
  provider_type: string
  ==
  has_many :taxonomies
  has_many :inputs
  has_many :audits
}

class ConfigTemplateInput {
  name: string
  required: bool
  input_type: USER_INPUT | FACT | SMART_VARIABLE
  fact_name: string
  smart_variable_name: string
  ==
  has_one :command_template
}


class ProxyCommand {
  rendered_template: string
  ==
  has_one :config_template
  has_one :audit
  has_one :host
}


ConfigTemplate -* Taxonomy
ConfigTemplate -* ConfigTemplateInput
ConfigTemplate -* Audit
ProxyCommand -> ConfigTemplate
ProxyCommand -> Audit

class Taxonomy
class Audit

{% endplantuml %}


Command Invocation
===================

User Stories
------------

- As a user I would like to invoke a job on a single host

- As a user I would like to invoke a job on a set of hosts, based on
  search filter

- As a user I want to be able to reuse existing bookmarks for job
  invocation

- As a user, when setting a job in future, I want to decide if the
  search criteria should be evaluated now or on the execution time

- As a user I want to reuse the target of previous jobs for next execution

- As a CLI user I want to be able to invoke a job via hammer CLI

- As a user, I want to be able to invoke the job on a specific set of hosts
  (by using checkboxes in the hosts table)

- As a user, when planning future job execution, I want to see a
  warning with the info about unreachable hosts

- As a user I want to be able to override default values like (number
  of tries, retry interval, splay time, timeout, remote user...) when I plan an execution of command.

Scenarios
---------

**Fill in template inputs for a job**

1. given I'm on job invocation form
1. when I choose the job to execute
1. then I'm given a list of providers that I have enabled and has a
template available for the job
1. and each provider allows to choose which template to use for this
invocation (if more templates for the job and provider are available)
1. and every template has input fields generated based on the input
defined on the template (such as list of packages for install package job)

**Fill in target for a job**

1. when I'm on job invocation form
1. then I can specify the target of the job using the scoped search
syntax

**Fill in execution properties of the job**

1. when I'm on job invocation form
1. I can override the default values for number of tries, retry
  interval, splay time, timeout, remote user... on per-template basis

**Set the exeuction time into future** (see [scheduling](design#scheduling)
  for more scenarios)

1. when I'm on a job invocation form
1. then I can specify the time to start the execution at (now by
default)
1. and I can specify if the targeting should be calculated now or
postponed to the execution time

**Run a job from host detail**

1. given I'm on a host details page
1. when I click "Run remote command"
1. then a user dialog opens with job invocation form, with prefiled
targeting pointing to this particular host

**Run a job from host index**

1. given I'm on a host index page
1. when I click "Run remote command"
1. then a user dialog opens with job invocation form, with prefiled
targeting using the same search that was used in the host index page

**Invoke a job with single remote execution provider**

1. given I have only one provider available in my installation
1. and I'm on job invocation form
1. when I choose the job to execute
1. then only the template for this provider is available to run and
asking for user inputs

**Invoke a job with hammer**

1. given I'm using CLI
1. then I can run a job with ability to specify:
  - targeting with scoped search
  - job name to run
  - templates to use for the job
  - inputs on per-template basis
  - execution properties on per-template basis
  - ``start_at`` value for execution in future
  - whether to wait for the job or exit after invocation (--async option)

**Re-invoke a job**

1. given I'm in job details page
1. when I choose re-run
1. then a user dialog opens with job invocation form, with prefiled
targeting parameters from the previous execution
1 and I can override all the values (including targeting, job,
templates and inputs)

**Edit a bookmark referenced by pending job invocation**

1. given I have a pending execution task which targeting was created
from a bookmark
2. when I edit the bookmark
3. then I should be notified about the existence of the pending tasks
with ability to update the targeting (or cancel and recreate the invocation)

Design
------

Class diagram of Foreman classes

{% plantuml %}

class Bookmark {
  name:string
  query:string
  controller:string
  public:bool
  owner_id:integer
  owner_type:string
}

class Targeting {
  query: string
  dynamic: bool
  ==
  has_many :targets
  has_one :command_execution
}

class Host
class User

class TemplateInvocation {
  inputs
  tries
  retry_interval
  splay
  remote_user
}

class JobInvocation {
} 

class ExecutionTask {
  start_at: datetime
}

Bookmark "1" <- "N" Targeting
Targeting "M" <-> "N" Host : (polymorphic)
Targeting "N" --> "1" User
JobInvocation "1" --> "1" Targeting
JobInvocation "1" <-- "N" TemplateInvocation
TemplateInvocation "N" --> "1" JobTemplate
JobInvocation "1" <-- "N" ExecutionTask

{% endplantuml %}

Query is copied to Targeting, we don't want to propagate any later
changes to Bookmark to already planned job executions.

We can store link to original bookmark to be able to
compare changes later.

For JobInvocation we forbid later editing of Targeting.


Command Execution
=================

User Stories
------------

- As a user I want to be able to cancel command which hasn't been started yet.

- As a user I want to be able to cancel command which is in progress. # some providers might not support this? therefore next user stories

- As a developer I want to specify whether cancellation of running commands is possible.

- As a user I want to see if I'm able to cancel the command.

- As a user I want job execution to fail after timeout limit.

Design
------

Class diagram of Foreman classes

{% plantuml %}

class JobTemplate {
  InstallPackage, Exec, RestartService

  // default values for job template
  retry: integer
  retry_interval: integer
  timeout: integer
  splay: integer

  plan(target, input) - creates JobExecution
}
note top of JobTemplate: InstallPackage, Exec, Restart service\nare just example names of instances\nwill be covered in JobPreparation design

class Host {
  get_provider(type)
}

class JobExecution {
  target: n:m to host_groups/bookmarks/hosts
  input: $input_abstraction values clone

  state: $JobState
  started_at: datetime
  canceled_at datetime
  provider: SSH | MCollective

  retry: integer
  retry_interval: integer
  timeout: integer
  splay: integer

  targeting_id: integer

  cancel()
}

abstract class ProxyCommand {
  job_execution_id: integer
  host_id: integer
  type: string
  state: $JobState
  started_at: datetime
  canceled_at datetime
  timeout_at datetime
  tried_count: integer
  cancel()
  {abstract} support_cancel?()
  {abstract} proxy_endpoint()
  plan()
}

class SSHProxyCommand {
  {static} support_cancel?()
  proxy_endpoint():string
}

class MCollectiveProxyCommand {
  {static} support_cancel?()
  proxy_endpoint():string
}

enum JobState {
PLANNED
STARTED
FINISHED
}

JobTemplate - JobExecution : n:m
JobExecution <-- ProxyCommand
Host <-- ProxyCommand

ProxyCommand <|-- SSHProxyCommand
ProxyCommand <|-- MCollectiveProxyCommand

{% endplantuml %}

JobExecution will be probably later replaced by Scheduler that
will schedule ProxyCommands (could be responsible for batch jobs,
retrying on failure, timeouts)

We should take facts from Foreman rather gather them during runtime (different result than expected when planning, performance)

Open questions
--------------


Reporting
=========

User Stories
------------

Design
------

Scheduling
==========

User Stories
------------

Design
------

Katello Workflow Integration
============================

User Stories
------------

Design
------

Security
========

User Stories
------------

Design
------

Orchestration
=============

User Stories
------------

Design
------
