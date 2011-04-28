# Polyshell - a role based job scheduler with local and remote shell support

Polyshell is primarily intended to administer server clusters, but can can be used
to schedule any kind of computational jobs.

Typical scenarios are to install new software, to monitor log files, to upload
new versions of web sites, and to verify that backup jobs have been completing
successfully.

The Capistrano and Vlad tools for Ruby on Rails are designed for these kind of
jobs. Polyshell is a lower level tool but forms a good foundation for creating
standard schedules such as deploying a new version of a web site pulled from
the latest source control branch.

The basic idea is to run a sequence of named jobs in a single batch such that
all jobs execute on all of their designated servers, concurrently, or in
sequence as needed, and such that all jobs do not necessarily run on exactly the
same servers.

Apart from built-in sequencing, running jobs can communicate and coordinate
through a batch specific shared global object, but the details are left to the user.

Sites are used to define a logical unit of configuration such that a physical
host can represent multiple sites - for example if a host both operates a
database and two different web domains.

Roles are used to name groups of sites in a server cluster. This makes it easy to
assign jobs to specific sites, and also to configure multiple sites consistently
with common settings.


## Installation

Download to some user local folder.

Enter folder and install locally (using npm 1.0.0):

    make install

(Or use npm 0.3.x directly without the makefile, not tested - notably the makefile has
some npm 1.0.0 specific references to the CoffeeScript compiler because CoffeeScript
as of this writing otherwise fails with the npm 1.0.0 module system.)

Test that things are ok (see warning below):

    make test

**Warning**: it may be that some tests happen to want to run on the host
`example.com`. This should not be the case - such logic should be elsewhere,
but just in case it slips: The tests may break because `example.com`
is an unknown host. If `example.com` has been pointed to a known host, the tests
might possibly create `tmp` folders, dump test files, and remove `tmp` folders on
your `example.com` server.

Tests normally dump files in a local tmp dir that is cleaned with `make clean`.

## CoffeeScript

Polyshell is written primarily in CoffeeScript, but that shouldn't change anything.
If, for some reason (including debugging), a JavaScript version is needed,
a JavaScript only module can be created in sub-folder using:

    make js

## Getting Started

A basic example running multiple shells on two sites; here two different locations
on the same host to simplify the setup.

Configure `.ssh/config` to point `example.com` to a real test server. You can
also remove the 'host: 'example.com' setting altogether to run on your local
system, or remove the host setting altogether to run in a local shell:

    jobs = require('..').jobs();

    jobs.sites.add('test', 'app-role', { host: 'example.com', testpath: 'tmp/jobstest/t1' });
    jobs.sites.add('test2', 'app-role', { host: 'example.com', testpath: 'tmp/jobstest/t2' });

    jobs.add('init', 'app-role', function() {
      this.shell.run("mkdir -p " + this.site.path, this.async());
      // Broadcast test file location to other jobs on the same site:
      this.shared[this.site.name] = { testfile: this.site.path + "/hello.test" };
    });

    jobs.add('hello', 'app-role', function() {
      this.shell.run("echo hello world > "
        + this.shared[this.site.name].testfile, this.async());
    });

    jobs.add('world', 'app-role', function() {
      this.shell.run([
        "echo grettings from: " + this.site.name + "running on host: " + this.site.host,
        "cat " + this.shared[this.site.name].testfile
      ]);
      this.report("message delivered");
    });

    // Run batch with logging enabled:
    jobs.run(['init', 'hello', 'world'], { log: true });

`this.shared` is an empty global object that can be seen by all jobs running
in the same batch. The init job sets up a site specific testfile property in
this space.

By default, jobs run in site-sequential mode. This means that on each site, one
job completes before the next is started, but jobs on different sites run in
parallel. Other schedules available such as `jobs.runParallel`.

Notice that we do not explicitly pass a callback to each function given to
`jobs.add`. For example, the `world` job does not need a callback and we could
easily forget to call it if given as argument. Instead we acquire a callback
with the function `this.async()` when one is needed. This makes it simpler to
write simple actions. This model also makes it possible acquire multiple
callbacks so we can wait on both a shell and a database call, for example.

To report errors in an action, either call `this.async()(error)`, or use
`this.fail(error)`. If error is null, the action will not fail. When the
async() callback is given to the shell, the shell takes care of reporting
errors to that callback, but other parts of the action may still use `fail`
until the action completes.

See also `test/jobs.coffee`, `test`, `envs.coffee`, and the `examples` folder
for more inspiration.

### Scheduling

The Polyshell job control scheduler is fairly simple. A schedule is an array of job
names which can be run in one the following modes: `sequential`, `atomic`,
`parallel`, or the default: `site-sequential` where different jobs may run at
the same time but each site will only see one of the jobs at a time. These
schedules can then be chained to more complex scenarios if needed, and the
same jobs can be reused in different schedules. This model is somewhat similar
to the various `node.js` async libraries like `seq`, `flow` and `async`, but
with role based job distribution, reporting, configuration, unique
identifiers, (remote) shell support, and password agents.

Polyshell has no dependency resolver, but it is possible to use Polyshell inside a
`Jakefile`, or similar tools. Because Polyshell does not try to schedule for you,
some other interesting options become possible. Polyshell job control provides a
shared object space and unique identifiers which enables the use locks and
event queues using `node.js` standard facilities such a `EventEmitter`. The
password agent facility of polyshell is one such example. Locking is well known
from database transaction coordination and provide a good scheduling
algorithm. This means that Polyshell jobs can take off in parallel, have jobs
attach to some contextual locks and wait for things to get done so they can
proceed. Polyshell does not directly provide such locking primitives (beyond the
password agent and cache), but they would be an obvious extension module.

### Passwords

Polyshell does not support ssh password based account login. It is assumed that ssh
will use ssh keys without passwords, or with passwords managed by an external
agent such as `ssh-agent`.

Polyshell does, however, support `sudo` password prompts after ssh login. In the
basic form a shell detects a sudo prompt and issues a silent prompt to the
user console.

Since many processes may target the same site, and many sites may have the
same admin password, it is convenient to cache a password across sites.

This works by creating a password cache object that is stored in all site
configurations that are supposed to share a `sudo` passwords. The shell object,
used to run remote (and local) commands, will look for a password cache when
it detects a `sudo` prompt. The shell will then either discover that there is
no password and prompt the user for one, or it will detect that there is a
password cached and try this once before prompting the user, or it will detect
that the cache is coordinating an ongoing password prompt issued by some other
process. In the latter case the shell will queue up in the cache waiting for a
response, then proceed as if it detected a cached password.

It is possible to create a password cache directly and store it in site
configurations, but it is simpler to call the `jobs.sharePassword` function.
This function also supports a preset password. It is really just a convenience
function so for more advanced scenarios use the source code for inspiration;
see `lib/password.coffee` and `lib/jobs.coffee`.
