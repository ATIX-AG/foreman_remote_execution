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

- As a user I want to be able to create a template to run some command for a given remote execution provider for a specific job

- As a user these command templates should be audited and versioned

- As a user I want to be able to define inputs into the template that consist of user input at execution time.  I should be able to use these inputs within my template.

- As a user I want to be able to define an input for a template that uses a particular fact about the host being executed on at execution time.

- As a user I want to be able to define an input for a template that uses a particular smart variable that is resolved at execution time.

- As a user I want to be able to define a description of each input in order to help describe the format and meaning of an input.

- As a user I want to be able to specify default number of tries per command template.

- As a user I want to be able to specify default retry interval per command template.

- As a user I want to be able to specify default splay time per command template.

- As a user I want to setup default timeout per command template.

- As a user I want to preview a rendered command template for a host (providing needed inputs)


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
  description: string
  ==
  has_one :command_template
}


ConfigTemplate "1" --> "N" Taxonomy
ConfigTemplate "1" --> "N" ConfigTemplateInput
ConfigTemplate "1" --> "N" Audit

class Taxonomy
class Audit

{% endplantuml %}


Scenarios
---------
**Creating a command template**

1. given I'm on new template form
1. I select from a list of existing job names or fill in a new job name
1. I select some option to add an input
  1. Give the input a name
  1. Select the type 'user input'
  1. Give the input a description (space separated package list)
1. I select from a list of known providers (ssh, mco, salt, ansible)
1. I am shown an example of how to use the input in the template
1. I am able to see some simple example for the selected provider??
1. I fill in the template
1. I select one or more organizations and locations (if enabled)
1. I click save


**Creating a smart variable based input**

1. given i am creating or editing a command template
1. I select to add a new input
  1. Give the input a name
  1. Define a smart variable name


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

- As a user I expect to see a the description of an input whenever i am being requested to
  provide the value for the input.

- As a user I want to be able to re-invoke the jobs based on
  success/failure of previous task

Scenarios
---------

**Fill in target for a job**

1. when I'm on job invocation form
1. then I can specify the target of the job using the scoped search
syntax
1. the target might influence the list of providers available for the
invocation: although, in delayed execution and dynamic targeting the
current list of providers based on the hosts might not be final and
we should count on that.

**Fill in template inputs for a job**

1. given I'm on job invocation form
1. when I choose the job to execute
1. then I'm given a list of providers that I have enabled and has a
template available for the job
1. and each provider allows to choose which template to use for this
invocation (if more templates for the job and provider are available)
1. and every template has input fields generated based on the input
defined on the template (such as list of packages for install package
job)

**Fill in job description for the execution**

1. given I'm on job invocation form
1. there should be a field for task description, that will be used for
listing the jobs
1. the description value should be pregenerated based on the job name
and specified input (something like "Package install: zsh")

**Fill in execution properties of the job**

1. when I'm on job invocation form
1. I can override the default values for number of tries, retry
  interval, splay time, timeout, remote user...
1. the overrides are common for all the templates

**Set the execution time into future** (see [scheduling](design#scheduling)
  for more scenarios)

1. when I'm on a job invocation form
1. then I can specify the time to start the execution at (now by
default)
1. and I can specify if the targeting should be calculated now or
postponed to the execution time

**Run a job from host detail**

1. given I'm on a host details page
1. when I click "Run remote command"
1. then a user dialog opens with job invocation form, with pre-filled
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
  - targeting with scoped search or bookmark_id
  - job name to run
  - templates to use for the job
  - inputs on per-template basis
  - execution properties as overrides for the defaults coming from the template
  - ``start_at`` value for execution in future
  - in case of the start_at value, if the targeting should be static
    vs. dynamic
  - whether to wait for the job or exit after invocation (--async
    option)

**Re-invoke a job**

1. given I'm in job details page
1. when I choose re-run
1. then a user dialog opens with job invocation form, with prefiled
targeting parameters from the previous execution
1 and I can override all the values (including targeting, job,
templates and inputs)

**Re-invoke a job for failed hosts**

1. given I'm in job details page
1. when I choose re-run
1. then a user dialog opens with job invocation form, with prefiled
targeting parameters from the previous execution
1 and I can override all the values (including targeting, job,
templates and inputs)
1. I can choose in the targeting to only run on hosts that failed with
the job previously

**Edit a bookmark referenced by pending job invocation**

1. given I have a pending execution task which targeting was created
from a bookmark
2. when I edit the bookmark
3. then I should be notified about the existence of the pending tasks
with ability to update the targeting (or cancel and recreate the
invocation)

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
}

class Host
class User

class TemplateInvocation {
  inputs
}

class JobInvocation {
  tries
  retry_interval
  splay
  remote_user
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

Open questions
--------------

* should we unify the common inputs in all templates to specify them
only once or scoping the input by template?

* Maybe an inputs catalog (with both defined name and semantic) might
help with keeping the inputs consistent across templates/providers


Command Execution
=================

User Stories
------------

- As a user I want to be able to cancel command which hasn't been started yet.

- As a user I want to be able to cancel command which is in progress
  (if supported by specific provider…)

- As a user I want job execution to fail after timeout limit.

- As a user I want to job execution to be re-tried
  based on the tries and retry interval values given in the invocation

- As a user I want to job execution on multiple hosts to be spread
  using the splay value

- As a user I want the job execution to be performed as a user that
  was specified on the job invocation

- As a user I want an ability to retry the job execution when the host
  checks in (support of hosts that are offline by the time the
  execution).

Scenarios
---------

**Cancel pending bulk task: all at once**

1. given I've set a job to run in future on multiple hosts
1. when I click 'cancel' on the corresponding bulk task
1. then the whole task should be canceled (including all the sub-tasks
on all the hosts)

**Cancel pending bulk task: task on specific host**

1. given I've set a job to run in future on multiple hosts
1. when I show the task representation on a host details page
1. when I click 'cancel' on the task
1. then I should be offered whether I should cancel just this
instance or the whole bulk task on all hosts

**Fail after timeout**

1. given I've invoked a job
1. when the job fails to start in given specified timeout
1. then the job should be marked as failed due to timeout

**Retried task**

1. given I've invoked a job
1. when the job fails to start at first attemt
1. then the executor should wait for retry_timeout period
1. and it should reiterate with the attempt based on the tries number
1. and I should see the information about the number of retries

Design
------

Class diagram for jobs running on multiple hosts

{% plantuml %}


class Host {
  get_provider(type)
}

class BulkExecutionTask {
  state: $TaskState
  start_at: datetime
  started_at: datetime
  ended_at datetime
  cancel()
}

class ExecutionTask {
  retry: integer
  retry_interval: integer
  timeout: integer
  splay: integer
  type: string
  state: $TaskState
  started_at: datetime
  start_at: datetime
  tried_count: integer
  ended_at datetime
  {abstract} support_cancel?()
  {abstract} proxy_endpoint()
  cancel()
}

abstract class ProxyCommand {
}

class SSHProxyCommand {
  {static} support_cancel?()
  proxy_endpoint():string
}

class MCollectiveProxyCommand {
  {static} support_cancel?()
  proxy_endpoint():string
}

BulkExecutionTask "N" -> "1" JobInvocation
BulkExecutionTask "1" <-- "N" ExecutionTask
TemplateInvocation "N" -> "1" JobInvocation
TemplateInvocation "1" <--- "N" ExecutionTask
ExecutionTask "1" -- "1" ProxyCommand
ExecutionTask "1" -- "1" Host

ProxyCommand <|-- SSHProxyCommand
ProxyCommand <|-- MCollectiveProxyCommand

{% endplantuml %}

Class diagram for jobs running a single host

{% plantuml %}

class Host {
  get_provider(type)
}

class ExecutionTask {
  retry: integer
  retry_interval: integer
  timeout: integer
  splay: integer
  type: string
  state: $TaskState
  started_at: datetime
  start_at: datetime
  tried_count: integer
  ended_at datetime
  cancel()
  {abstract} support_cancel?()
  {abstract} proxy_endpoint()
  plan()
  cancel()
}

class ProxyCommand {
}

ExecutionTask "N" -> "1" JobInvocation
TemplateInvocation "N" -> "1" JobInvocation
TemplateInvocation "1" <- "N" ExecutionTask
ExecutionTask "1" -- "1" ProxyCommand
ExecutionTask "1" -- "1" Host
{% endplantuml %}

We should take facts from Foreman rather gather them during runtime (different result than expected when planning, performance)

Open questions
--------------
1. Splay Time versus Splay Count
  * Count would allow for better adjustments for performance tolerance
  * Time would fit into maintenance windows better
  * How would either of these be implemented?

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
