
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

    jobs.sites.add('test', 'app-role', { host: 't1.example.com' });
    jobs.sites.add('test2', 'app-role', { host: 't2.example.com' });

    jobs.add('init', 'app-role', function() {
      this.shell.run("mkdir -p tmp");
    });
    
    jobs.add('hello', 'app-role', function() {
      this.shell.run("echo hello world > tmp/hello.test");
    });

    jobs.add('world', 'app-role', function() {
      this.shell.run("cp tmp/hello.test tmp/world.test");
    });

    jobs.run(['init', 'hello', 'world'], { log: true });

      // run jobs on hosts t1.example.com and t2.example.com
      // with logging enabled

It is recommended to configure `~/.ssh/config` to point `example.com` to some
real test server with appropriate ssh keys.

See also `test/jobs.coffee`, `test`, `envs.coffee`, and the `examples` folder
for more inspiration.

### Passwords

Ploy does not (as of this writing) support ssh password login. It is assumed that
ssh will use ssh keys without passwords, or with sshagent, or a similar password agent.

Ploy does, however, have a password agent for sudo passwords. It is possible
to configure multiple sites to share a single password cache such that when
the first remote shell process asks for a password, all other concurrent
actions will hold, waiting for user input, and then proceed once the password
has been entered.

Two processes may race to ask for a password, in which case the user
is prompted twice. Processes may also jam the about with noise making it difficult to
enter a password. For these reasons, it is helpful to create a job specific to acquiring
a password and the schedule other jobs after that.

TODO: this is experimental: passwords may not interact correctly with the job controller
as of this writing, but the general idea is:

    ploy = require('ploy');
    jobs = ploy.jobs();
    sites = jobs.sites;
    
    sites.add('host1', { host: "h1.example.com" });
    sites.add('host2', { host: "h2.example.com" });
    
    // now all current hosts in the hub-zero role will share passwords
    sites.add(['host1', 'host2'], 'hub-zero', { 'password-agent': ploy.password.agent(); });
    

TODO: the jobs controller currently does not read the password-agent setting to initialise the
shell accordingly.


## API

### jobs.add(jobname, [roles], [actions])

Adds actions to a new or an existing named job. The job is not run, only
made available to the job schedulers `job.run` function.

If no role is given, the `jobname` is used as the role.

If no action is given, the job is made known but will not do anything. This
will silence errors about missing jobs. Actions can be added by calling
`jobs.add` again with the same name.

`roles` : used to identify the sites that are allowed to run the job. When
the job is subsequently run, the job will either run on all sites, or on a
subset given by the restricting roles passed to the `job.run` function.

Roles cannot be added to existing actions, only restricted, when running.
However, sites may be added by including them in roles after a job has been
created, and new actions may be added in new roles.

Example roles (arrays are flattened before use):

    "www"
    ["test", "deploy"]
    ["db", ["test", "deploy"], []]

`actions` : an optional function or (nested) array of functions that all run
in parallel on all sites that match the given role list.

An action is a function that does some work. By default it runs to completion
or starts or things that it does not wait for, but it can request a callback
function one or more times by calling the `this.async()` function. `this`
points to an action object with several other useful features including
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

options:

  - `options.roles` : optional role filter to restrict number of affected sites.
  - `options.name` : optional schedule name for logging
  - `options.desc` : optional schedule description for logging
  - `options.breakOnError` = true : terminates action sequence on a site that fails.
  - `options.allowMissingJob` = true : allow missing jobs without throwing an exception.
  - `options.report` = true : enable custom report output, even when opts.log disabled.
  - `options.debug` = true : enable custom debug output - independent of opts.log
  - `options.quiet` = true : suppress error messages, overridden by opts.log.

## Environments

### envs()

    envs = require('ploy').envs();

Creates a generic role based environments collection useful for various
purposes. See `sites()` for an example use of the `envs()` api.

## Sites

A site is a name that maps to configurations settings which typically include
a host domain, a user, and possibly a local path. A site may be local (no host
domain), or remote. `.ssh/config` is typically used to map a host to a real
remote host with ssh keys.

Note: here we focus on the actual api for managing sites. There are specific
settings which are significant in specific contexts which will not be covered
here, since a site can be used many ways.

For the job controller `jobs()`, site configurations have two important
purposes: one is to identify which sites a job will target by matching role
names, and the other is to automatically initialise local and remote shells
using settings in the site configuration object. The host setting is the most
important: if present, .ssh/config can be used to provide access to the given
host, and if absent, a local shell is assumed. See `Shell` and `jobs()` for
more details.

### `sites()`

Creates a collection of environment objects indexed by name and organised
by roles.

    sites = require('ploy').sites();

We use the term `site` loosely to reference a site name, the configuration
object of a site, or the physical location represented by the name.

Note: `sites()` creates a generic environments collection with role support.
The environments collection can by used for a number of other purposes:

    sites = require('ploy').sites();

    // the above is equivalent to:

    envs = require('ploy').envs();

### sites.add(names, [roles], [config])


    sites = require('ploy').sites()

    sites.add 'example', 'test', { host: 'test.example.com' }
    sites.add 'host1', { host: 'www1.example.com' }
    sites.add 'host2', { host: 'www2.example.com' }
    sites.add 'host1-admin', { host: 'www1.example.com', port: 8000, path: "sites/admin" }
    sites.add 'local'

Sites are always organised into roles. In the above example the sites are
already added to the roles given by their own name. The `example` site is also
added to the `test` role.

We can add more roles later:

    sites.add(['host1', 'host2'], ['www', 'deploy']);
    sites.add(['host1-admin', 'local'], 'admin');

`names` : a site name, or a (nested) array of sites names to be created or updated.
It is valid to add to an existing site. (Nesting is just a convenience with no significance.)

`roles` : optional role name or (nested) array of role names. (Nesting is  just a convenience
with no significance.). sites are assigned to the listed roles if any. This makes it possible
to reference a group of sites by a single name. A site always belong to a role with the same
name as the site name to make it easy to target specific sites in functions that only
accept role names.

`config` : an optional configuration object (or environment if you like) that
is applied to all to all listed sites. The config is **not** assigned to
roles. Only those sites currently listed will receive the configuration. If a
site already exists, the configuration object will be extended by adding new
names to the old object, but entirely overwriting old data where the top-level
names conflict. Configurations are always cloned so the input object will
never be changed by modifying a site, and sites added simultaneously will have
separate copies.

A configuration object always has a property named 'name' which is identical to
the site name. It cannot be overridden, but it can be changed after calling `sites.get()`.


    sites = require('ploy').sites();

    sites.add('foo', { name: "bar", x: "1" });
    sites.get('foo');
      // => { name: "foo", "x: "1" }

    sites.add(['site1', 'site2'], { x: "1", y: "2" });
    
    sites.get('site1');
      // => { name: "site1", x: "1", y: "2" }
    sites.get('site2');
      // => { name: "site2", x: "1", y: "2" }

    sites.add('site2',
      { z: 3, info: { tags: [ "test", "online" ], timeout: 4000 } });
    
    sites.get('site1')
      // => { name: "site1", x: "1", y: "2" }
    sites.get('site2')
      // => { name: "site2", x: "1", y: "2", z: 3,
      //      info: { tags: [ "test", "online" ], timeout: 4000 } }
  
    sites.add('site2', { info: { tags: [ "busy" ] } });
    
    sites.get('site1');
      // => { name: "site1", x: "1", y: "2" }
    sites.get('site2');
      // => { name: "site2", x: "1", y: "2", z: 3, info: { tags: [ "busy" ] } }

### sites.get(name)

Returns a copy of the configuration currently stored for the named site, or null if
the site is not present.

`name` : name of site.

    sites = require('ploy').sites()
    
    sites.add('ex', 'www', { host: "app.example.com" });
    sites.get('ex');
      // => { name: 'ex', x: "1", y: "2" }
    sites.get('www');
      // => null
    sites.get('app.example.com');
      // => null
    sites.get(sites.list('www').shift());
      // => { name: 'ex', x: "1", y: "2" }

    Any changes to an object returned by get will not have any effect on the configuration stored
    in the sites collection.

### sites.list(roles, [filter])

Returns an array of matching site names. The result can be an empty array, an array
with one element, or a flat array with more elements. There will be no duplicate
site names.

`roles` : a role name or a (nested) array of role names. All sites existing in at least
one of the roles will be returned. If `roles` is empty or null, an empty array is
returned.

`filter` : an optional role name or a (nested) array of role names similar to
`roles`. If present a site must exist in both roles and filter in order to be
include in the result set. The filter is used by the job controller to
restrict the number of sites a job would normally target.

### sites.update(inroles, [roles], [config])

A shorthand for `sites.add(sites.list(inroles), roles, config);

Updates all sites in the given `inroles` simulatanously, but will
not create any new sites.

### job.sites

Sites are used by the job controller. The job controller automatically
creates a sites collection if one is not being passed when the job controller
is created:

    jobs = require('ploy').jobs();
    sites = jobs.sites;

or, to share sites between different job controllers:

    ploy = require('ploy');
    sites = ploy.sites();
    
    jobs = ploy.jobs(sites);
      // sites === jobs.sites
      
    jobs2 = ploy.jobs(sites);
      // sites === jobs2.sites

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
