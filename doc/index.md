## Introduction

* [ReadMe](readme.html)
* [Getting Started](getting_started.html)

## API

* [Shell](api/shell.html)
* [Jobs](api/jobs.html)
* [Sites](api/sites.html)
* [Envs](api/envs.html)
* [Password](api/password.html)

## Invocation Objects

General concepts and objects made available to callbacks.

* [Action](api/action.html)
* [Schedule](api/schedule.html)

## Use

* `poly.shell` to run shell commands on remote (and local systems)
transparently.
* `poly.shell.upload` and friends to easily migrate files between the local
system and a remote system.
* `poly.sites` to configure many systems at once, both for login and
for custom settings.
* `poly.jobs` to schedule multiple jobs that depend on each other but
run as much in parallel as possible.
* `poly.password` directly, or more likely, indirectly via `poly.jobs`
to manage shared password logins.
* `poly.envs` for generic role based configurations other than site
management.

