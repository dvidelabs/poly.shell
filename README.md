# Poly.shell
*- distributed shell job control with role based configuration for Node.js*

Poly.shell is primarily intended to administer server clusters, but it
can also be used to schedule other kinds of distributed computation, or
to just run simple shell commands.

Typical scenarios are to install new software, to monitor log files, to upload
new versions of web sites, and to verify that backup jobs have been completing
successfully.

The Capistrano and Vlad tools for Ruby on Rails are designed for these kind of
jobs. Poly.shell is a lower level tool but forms a good foundation for performing
standard routines such as deploying a new version of a web site pulled from
the latest source control branch.

The basic idea is to define a set of named jobs with actions that can run
in sequence, in parallel, or some variation thereof, on multiple local and
remote sites using role names to aid configuration.

Poly.shell can also be used as a convenient way to quickly run system
local shell commands:

    require('poly').shell().run("touch IWasHere");

or to run commands on a single remote system:

    require('poly').shell('example.com').run("ls");
    
Poly.shell can also run multiple jobs in different roles:

    poly = require('poly');
    jobs = poly.jobs();
    sites = jobs.sites;
    
    sites.add('my-local-site', ['role-x', 'role-y']);
    sites.add('my-remote-site-1', 'role-x', { host: 'app1.example.com' });
    sites.add('my-remote-site-2', ['role-x', 'role-y'], { host: 'app2.example.com' });
    
    jobs.add('job-a', 'role-x', function() {
      this.shell.run("echo hello > " + this.site.name + ".flag", this.async());
      var x = this.shared.visited || [];
      x.push(this.site.name);
      this.shared.visited = x;
    });
    
    jobs.add('job-b', 'role-y', function() {
      //...
    });
    
    jobs.run(['job-a', 'job-b'], function() {
      console.log "all jobs done";
      console.log this.shared.visited;
    });

Here we created 3 different local and remote sites where jobs can
run. We use the shell to access the remote systems and the role names
to decide which jobs to run where.

Because the same job runs on multiple sites there are different ways
to synchronise. The default is to start the first job in parallel on
all matching sites and each site will go on to the next job as soon as
its current job invocation is complete, like a relay race.

There are different run schedules (parallel, atomic, ...), and
`jobs.run` can be restricted to only run jobs on sites with certain
roles. Whenever a site does not have a role that match the next job,
the site will skip that job and immediately proceed with the next job
listed.

## Resources

Repository:

<https://github.com/dvidelabs/poly.shell>

Online Documentation:

<http://dvidelabs.github.com/poly.shell/>

## Installation

To install latest public release with npm:

    npm install -g poly
    
Or download or clone from github to some user local folder.
Enter folder and install using npm:

    npm install

Or globally with npm 1.0.0:

    npm install -g

Test that things are ok (see warning below):

    make test

Note, the following tests run on a remote system example.com that is
supposed to be configured .ssh/config to match a suitable server.

**Don't use this on production systems!!! **

    make rtest

Tests normally dump files in a local tmp dir that is cleaned with `make clean`.
Remote tests are not cleaned up, please inspect the test files in the `rtest` folder.

## CoffeeScript

Poly.shell is written primarily in CoffeeScript, but that shouldn't change anything.
If, for some reason (including debugging), a JavaScript version is needed,
a JavaScript only module can be created in sub-folder using:

    make js

## Passwords

Poly.shell does not support ssh password based account login. It is assumed that ssh
will use ssh keys without passwords, or with passwords managed by an external
agent such as `ssh-agent`.

Poly.shell does, however, support `sudo` password prompts after ssh login. In the
basic form a shell detects a sudo prompt and issues a silent prompt to the
user console.

Since many processes may target the same site, and many sites may have the
same admin password, it is convenient to cache a password across sites.

This works by creating a password cache object that is stored in all site
configurations that are supposed to share a `sudo` passwords.

Shells can detect when another shell is prompting for a password and wait for
the user to enter the password, and otherwise start a password prompt when no
valid password is cached.

## Scheduling

The Poly.shell job control scheduler is fairly simple. A schedule is an
array of job names which can be run in one the following modes:
`sequential`, `atomic`, `parallel`, or the default: `site-sequential`
where different jobs may run at the same time but each site will only
see one of the jobs at a time. These schedules can then be chained to
more complex scenarios if needed, and the same jobs can be reused in
different schedules. This model is somewhat similar to the various
Node.js async libraries like `seq`, `flow` and `async`, but with
role based job distribution, reporting, configuration, unique
identifiers, (remote) shell support, and password agents.

Poly.shell has no dependency resolver, but it is possible to use
Poly.shell inside a `Jakefile`, or in similar tools, or even in a
web framework like `Express`.

Locking primitives can be added, for example by using Node.js
EventEmitter objects in the shared context, or in site configurations
for example. The password cache and agent does something similar.
Locking provides a good algorithm for scheduling transactions.

