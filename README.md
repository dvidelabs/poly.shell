
# Ploy - a role based job scheduler with local and remote shell support

Ploy is primarily intended to administer server clusters, but can can be used
to schedule any kind of computational jobs.

Typical scenarios are to install new software, monitor log files, upload new
versions of web sites and verifying that backup jobs have run correctly.

The Capistrano and Vlad tools for Ruby on Rails are designed for this kind of
jobs. Ploy is a lower level tool where Vlad like configurations are possible
as extension modules.

The basic idea is to assign one or more roles to each server such that we
can easily make the same configuration settings on multiple servers and also
to easily assign specific jobs to multiple servers in one go.

Ploy uses the concept of sites, where a site is seen as a physical location
where a shell can run. One server, or host, can have multiple sites. In
reality, a site is simply a configuration unit that can represent anything,
but when using the built in shell support in Ploy jobs, it helps to think of
sites as something with an ssh shell, or with a local shell.

## Installation

Download to some user local folder.

Enter folder and install locally (using npm 1.0.0):

    make install

Test that things are ok:

    make test

*Warning*: it may be that some tests happen to want to run on the host
`example.com` since things change occasionally (they ought to be in a separate
suite not covered by `make test`). If this is the case, tests will either break
or, if `example.com` has been pointed to a real server, possibly dump test
files and remove tmp dirs on your server.

## Coffee-Script

Ploy is written primarily in coffee-script, but that shouldn't change anything.
If, for some reason (including debugging), a javascript version is needed,
a javascript only module can be created in sub-folder using:

    make js

## Scheduling

The Ploy job control scheduler is fairly simple. A schedule is an array of job
names which can be run in `sequence`, in `parallel`, or the default:
`site-sequential` where different jobs may run at the same time but each site
will only see one of the jobs at a time. These schedules can then be chained
to more complex scenarios if needed, and the same jobs can easily be reused in
different schedules. This model is somewhat similar to the various `node.js`
async libraries like `seq`, `flow` and `async`, but with role based job
distribution, reporting, configuration, unique identifiers, (remote) shell
support, and password agents.

Ploy has no dependency resolver, but it is not difficult to use Ploy inside a
`Jakefile`, or similar tools. Because Ploy does not try to schedule for you,
some other interesting options become possible. Ploy job control provides a
shared object space and unique identifiers which makes it easy to add locks
and event queues using `node.js` standard facilities such a `EventEmitter`.
Locking is well known from database scheduling and provide a very good
scheduling algorithm. This means that Ploy jobs can take of in parallel attach
to some locks and wait for things to get done so they can proceed. Ploy does
not directly provide such locking primitives, but they would be an obvious
extension module.

## Usage

A very basic example:

    jobs = require('ploy').jobs();

    jobs.sites.add('test', 'app-role', { host: 'example.com' });

    jobs.add 'hello', 'app-role', function() {
      this.shell.run "touch hello.test"
    }

    jobs.add 'world', 'app-role', function() {
      this.shell.run "echo world > hello.test"
    }

    jobs.run ['hello', 'world']

It is recommended to configure `~/.ssh/config` to point `example.com` to some
real test server with appropriate keys.

See `test/jobs.coffee`, `test`, `envs.coffee`, and the `examples` folder
for more inspiration.

### Passwords

Ploy does not (as of this writing) support ssh password login. It is expected that
ssh uses ssh keys without passwords, or with sshagent, or a similar password manager.

Ploy does have a password manager for sudo passwords though. It is possible to
configure multiple sites to share a single password cache such that when the
first server asks for passwords, all other concurrent actions will hold,
waiting for user input, and then proceed once the password has been entered
once.

TODO: details about how to configure password sharing and sudo behaviour.

## API

### jobs.add(jobname, [roles], [actions])

Adds actions to a new or an existing named job. The job is not run, only
made available to the job schedulers `job.run` function.

If no role is given, the `jobname` is used as the role.

If no action is given, the job is made known but will not do anything. This
will silence errors about missing jobs. Actions can be added by calling
`jobs.add` again with the same name.

`roles` are used to identify the sites that are allowed to run the job. When
the job is subsequently run, the job will either run on all sites, or on a
subset given by the restricting roles passed to the `job.run` function.

Roles cannot be added to existing actions, only restricted, when running.
However, sites may be added by including them in roles after a job has been
created, and new actions may be added in new roles.

Example roles (arrays are flattened before use):

    "www"
    ["test", "deploy"]
    ["db", ["test", "deploy"], []]

`actions` is an optional function or array of functions that all run in parallel
on all sites that match the given role list.

An action is a function does some work. By default it runs to completion or
starts or things that it does not wait for, but it can request a callback
function one or more times by calling the `this.async()` function.
`this` points to an action object with several other useful features including
`this.shell.run`:

    jabs.add('upload-web', 'web', function() {
      cb = this.async();
      this.shell.run("scripts/deploy.sh", cb);
    }
    jabs.add('upload-web', 'web', function() {
      cb = this.async();
      this.shell.run("scripts/backup.sh", cb);
    }
    jabs.add('upgrade-web', 'web', function() {
      cb = this.async();
      this.shell.run("scripts/upgrade.sh", cb);
    }
    jobs.runSequential(['upload-web', 'upgrade-web'], 'web',
      { breakOnError: true },
      function(err) {
        if(err)
        // not part of Ploy
        email(this.site.adminemail, "backups failed");
    });

Note that we could just have called the above actions in single script, but by
splitting it up, we can wait for all web servers to complete their backups and site uploads
before switching over all servers to the new site version.
By having backup in a separate action we get better error reporting without risking not
running it along with the upgrade.

TODO: it seems that we need more sequential ops: one that runs only one job at a time
in rotation on all matching sites before proceeding to each job, and one the
ensures a job has completed on all sites before starting the next job.

When a job is added multiple times, each action is associated with those roles
given when added to the job. In effect a job becomes a cluster of actions that
run together, but not necessarily in the same place, but always at the same
time.

When a job is run, each action will at most run once on each site, even if the
same site appear in multiple roles matching the same action of the job.
However, if the `jobname` is listed multiple times in the array given to
`jobs.run`, the job actions will run multiple times on any matching site.

Actions within a single job always run in parallel, regardless of the schedule
used to run multiple jobs.

### jobs.runSiteSequential(jobs, [roles], [options], [callback])
Run job or jobs in a site-sequential schedule where one job
completes on a site before a new is started, but a new job can start
on one site before it has finished on all other sites. `callback` is 
called once all jobs have completed on all sites.

`jobs.run` is a synonym for this function.

See `jobs.run` for more details.

### jobs.runSequential(jobs, [roles], [options], [callback])

Run all jobs one after another so only one site at time will be
running any job actions. `callback` is called once all jobs have
completed on all sites.

TODO: we need another version that run jobs in parallel on all sites, but
does not start any new jobs before all current jobs has started.
This should be runSequential, the other should be runIsolated.

See `jobs.run` for more details.

### jobs.runParallel(jobs, [roles], [options], [callback])

Runs all jobs in parallel on all sites. `callback` is called once
all job actions have completed.

See `jobs.run` for more details.

### jobs.run(jobs, [roles], [options], [callback])

Synonym for runSiteSequential.

Multiple actions within a single job always run in parallel.

`jobs`  : job name or (nested) array of job names.
              Jobs run in order at each site, but
              in parallel across different sites.

`callback` : called with null or error count once all jobs have completed on
all sites. complete is called with a schedule object as this pointer giving
access to various functionality.

TODO: It seems that we need a site specific callback also.

options:

  - `options.roles` : optional role filter to restrict number of affected sites.
  - `options.name` : optional schedule name for logging
  - `options.desc` : optional schedule description for logging
  - `options.breakOnError` = true : terminates action sequence on a site that fails.
  - `options.allowMissingJob` = true : allow missing jobs without throwing an exception.
  - `options.report` = true : enable custom report output, even when opts.log disabled.
  - `options.debug` = true : enable custom debug output - independent of opts.log
  - `options.quiet` = true : suppress error messages, overriden by opts.log.

### jobs.add ...
TODO

### jobs.sites.add ...
TODO
A site is a name that maps to configurations settings which typically include
a host domain, a user, and a local path. A site may be local (no host domain),
or remote. `.ssh/config` is typically used to map a host to a real remote host
with ssh keys.

...

### jobs.sites.update ...
TODO

### jobs.sites.list ...
TODO

## Actions
TODO
### Action Objects
...

## Schedules

### Schedule Object
TODO ...

## Shell
TODO


## Passwords
TODO
## sudo
