
# Ploy - a role based job scheduler with local and remote shell support

Ploy is primarily intended to administer server clusters, but can can be used
to schedule any kind of computational jobs.

Typical scenarios are to install new software, to monitor log files, to upload
new versions of web sites, and to verify that backup jobs have been completing
successfully.

The Capistrano and Vlad tools for Ruby on Rails are designed for these kind of
jobs. Ploy is a lower level tool but forms a good foundation for creating
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
some npm 1.0.0 specific references to the coffee-script compiler because coffee-script
as of this writing otherwise fails with the npm 1.0.0 module system.)

Test that things are ok (see warning below):

    make test

**Warning**: it may be that some tests happen to want to run on the host
`example.com`. This should not be the case - such logic should be elsewhere,
but just in case it slips: The tests will either break because `example.com`
is an unknown host, or, if `example.com` has been pointed to a real server,
possibly create `tmp` folders, dump test files, and remove `tmp` folders on
your `example.com` server. This will naturally also happen locally when tests
are running, hence `make clean`.

## Coffee-Script

Ploy is written primarily in coffee-script, but that shouldn't change anything.
If, for some reason (including debugging), a javascript version is needed,
a javascript only module can be created in sub-folder using:

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
    

TODO: the jobs controller currently does not read the password-agent setting
to initialise the shell accordingly. See `test/passwords.coffee`,
`manual-test/password.coffee`, `lib/shell.coffee`, and `lib/password.coffee`.


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

See also `Actions`.

### jobs.runSiteSequential(jobs, [roles], [options], [callback])

Run job or jobs in a `site-sequential` schedule where one job
completes on a site before a new is started, but a new job can start
on one site before a previous job has finished on all other sites. `callback` is 
called once all jobs have completed on all sites.

`jobs.run` is a synonym for this function as this is normally the
desired behaviour.

See `jobs.run` for more details.

### jobs.runSequential(jobs, [roles], [options], [callback])

Run all jobs one after another in a `sequential` schedule such that jobs run
concurrently on all sites, but a new job is not started before the previous
job has completed on all sites. `callback` is called once all jobs have
completed on all sites.

See `jobs.run` for more details.

### jobs.runParallel(jobs, [roles], [options], [callback])

Runs all jobs in parallel on all sites. `callback` is called once
all job actions have completed.

See `jobs.run` for more details.

### jobs.run(jobs, [roles], [options], [callback])

Synonym for runSiteSequential.

The list of jobs being run is called a schedule.

The same job may appear multiple times in a schedule, and will then execute
multiple times.

When `jobs.run` is called, the schedule begins executing. The schedule has
completed when the callback is being called. This means that all scheduled
actions have of all jobs in the schedule have completed (successfully or
otherwise). Multiple schedules can be chained by starting new schedules with
`this.run` in the callback, or by using one of the related run functions.

Chained schedules run in the same batch. `this.shared` provide access to a batch global
shared state in all action functions and all schedule callbacks. `this.batch` provides
access to the globally unique batch identifier. All actions and schedules have unique
identifiers prefixed by the batch identifier. The identifiers are used extensively in
logging, and are also useful for creating temporary files.


Multiple actions within a single job always run in parallel.

`jobs` : job name or (nested) array of job names. Jobs run in order at each
site, but in parallel across different sites.

`roles` : optional name or (nested) array of role names. roles are just to restrict
the number of sites that will execute the schedule. If a given job in the schedule
matches the role ['www', 'db'], and `roles` is set to 'db', then only sites in the
`db` role will execute. Some jobs in the schedule may not execute at all. Because
all site names are also rules, we can restrict a job to a single site in this way.

`callback` : called with null or error count once all jobs have completed on
all sites. complete is called with a schedule object as this pointer giving
access to various functionality. See `Schedules` for more information about
the schedule object given by the `this` pointer in the callback.

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

## Schedules and Batches

### Schedule

A schedule is started by `jobs.run`, or one the related functions, and ends
when the callback is being called. See also `jobs.run`.

The schedule object is visible as `this` in the callback function given to
`jobs.run`, and as `this.schedule` in action objects.

### Chaining (`this.run`)

The schedule object can start new schedules in a chain
which serves the dual purpose of synchronising schedules and passing
information from previous schedules. Options like `roles`, `log` etc. are
inherited, but new options can be given to the `this.run` function.

### Action chaining

NOT SUPPORTED (but please tell how it goes): inside actions, it should be
possible to start chained schedules using `this.schedule.run`, but this has
not been tested. Clearly this will start a schedule before another schedule
has completed, and it may potentially start the schedule many times over since
actions are distributed to multiple sites - however, with some bookkeeping it
might be doable. One option could be to restrict schedules to the current site
name when run inside actions, another option 

Note that `jobs.run` can be called in a schedule callback which will provide
synchronisation, but will also start a new batch with separate state unlike
`this.run`.

### Batch

A batch is a context shared across chained schedules and allow chained
schedules to inherit options from parent schedules. The batch also provide a
globally unique identifier that prefixes all schedule identifiers in the
batch, and not least: access to global custom shared state across all
schedules, and all job actions in these schedules.

### Schedule Object
The schedule object (the this pointer in a `jobs.run` callback) has the
following methods and properties:

TODO:

  - `this.opts` should be implemented as `this.options`, like documented below.

Properties:

  - `this.batch` : a globally unique batch identifier string used to prefix all other identifiers.
  - `this.id` : a globally unique starting with batch id followed by a the schedule index separated by a dash.
  - `this.index` : the schedule index of this batch, starting with 1.
  - `this.issuer` : the prefix used for logging messages, which include the schedule id.
  - `this.jobs` : the flattened array of job names executing in this schedule, possibly with duplicates.
  - `this.name` : an optional schedule name from the schedule options for logging.
  - `this.options` : the options passed to `jobs.run` or `this.run`, and anything inherited from the batch.
  - `this.shared` : access to the batch global shared object for customised information sharing.
  - `this.type` : the schedule type, currently one of ['sequential', 'parallel', 'site-sequential']

Methods:

  - `report(msg)` : customised logging when `log` or `report` options are true for the schedule.
  - `debug: (msg, [value])` : debug message and optional object inspection dump
                              when `options.debug` is true.

The schedule object also has the following chaining methods:

  - `this.run`
  - `this.runSiteSequential`
  - `this.runSequential`
  - `this.runParallel`

These are similar to the `jobs.run` family of functions and have access to the
sites and jobs of the original schedule that started the batch.

## Actions

An action is an anonymous function with no arguments that is added to a job
using the `job.add` method:

    jobs = require('ploy').jobs();

    jobs.add 'rollback', function() {
      this.report "this function is the rollback action"
    }

A job can have multiple actions in different roles. This can, for example, be
used to add OS specific actions:

    jobs = require('ploy').jobs();
    jobs.sites.add('d1', 'debian', { host: 'd1.example.com' });
    jobs.sites.add('d2', 'debian', { host: 'd2.example.com' });
    jobs.sites.add('c1', 'centos', { host: 'c1.example.com' });
    
    jobs.add('sysupdate', ['debian'], function() {
      // ...
    });
    jobs.add('sysupdate', ['centos'], function() {
      // ...
    });
    // update all debian systems every Wednessday
    if(isWednessday())
      jobs.run(['sysupdate'], 'debian');
    // update all systems every second thursday of very month
    if(isSecondThurdayOfMonth())
      jobs.run(['sysupdate']);

If we want to add multiple actions that execute together concurrently, this
can be done by adding using the same roles in subsequent calls to `job.add`,
or by providing an array of functions to `jobs.add`.

When a job is executing, none, some, or all of the actions may execute
depending on available sites and role restrictions given to the executing
schedule.

A single site may execute multiple (different) actions for a single job
invocation, but a single action will at most execute once per site per job
invocation. If the same job is invoked multiple times, such as an archiving
snapshot job might, the action will run again on the same site on next job
invocation. The next invocation will have a fresh action id.

Because a job invocation may be fragmented into multiple actions executing on
the same site, an action invocation is also called a job fragment. Fragments
are those actions that are actively executing on a site in a given job
invocation.

Each action invocation has a non-repeatable globally unique identifier. Two
actions in the same job will have different identifiers. The same action on
different sites will have different identifiers. The same action on the same
site in two different job invocations will have different identifiers.

To get some less unique identifiers, a combination of `this.batch`,
`this.site.name` and `this.job` may provide the necessary means for
communication across actions in, for example, the file system, a database, or
in the `this.shared` object.

Action identifiers are used to tag log messages such as action is now starting
on this site... Custom logging with identifier tag is available through the
`this.report` and `this.debug` functions inside actions.

### Action Object

The object referenced by `this` inside actions is called the action object, and has
the following methods and properties:

TODO: Changes needed on source code (documentation is correct, in principle).

  - `this.index`should be `this.fragment.
  - `this.total` should be `this.fragments.
  - `this.index` should be implemented as `_ctx.actioncount` (like documented below).
  - `this.opts` should be `this.options`.
  - `this.sched` should be `this.schedule`.
  
**Properties:**

  - `this.batch` : a globally unique identifier for this batch, used to prefix action id.
  - `this.fragment` : a number between 1 and `total`. The same action may have different fragment
                 numbers on different invocations, but it is unique for the current job
                 invocation on the current site.
                 Logging use (this.fragment/this.fragments) in job start msg if total > 1.
  - `this.fragments` : total number of actions (fragments) running in this job invocation on this site.
  - `this.id` : a globally unique action invocation id, prefixed by batch id and schedule index.
  - `this.issuer` : the prefix used for logging, including the `id`.
  - `this.index` : the action invocation index of this batch, starting with 1.
  - `this.job` : name of the currently executing jobs (but not which invocation within the schedule).
  - `this.options` : direct and inherited schedule options. 
  - `this.schedule` : a reference to the current schedule object, for example `this.sched.id`.
  - `this.shared` : a batch global shared object for customised information sharing.
  - `this.shell` : the shell object configured with data from site config and
              schedule options such as `options.log`. Run local or remote shells using `this.shell.run`.
              See also `Shell`.
  - `this.site` : the site configuration object, for example `this.site.name`.

**Methods:**

  - `this.debug: (msg, [value])` : debug message and optional object inspection dump when `debug` option is true.
  - `this.report(msg)` : customised logging when `log` or `report` options are true for the schedule.

**Flow and Error Control:**

  - 'this.async()' : call "callback = `this.async()`" (while `this` is still valid!!) to get a callback function that **must**
                must be called once with null or an error. The callback can, for example be passed to
                `this.shell.run(cmd, callback) to prevent the action from completing before the shell does.
                `async()` can be called multiple times, each returned callback must be called once, for example
                to capture completion of concurrent shell executions.
                `async` must not be called again after the last returned callback has been called and the
                action has returned.
  - 'this.fail(err) : report an error without allocating a callback. `fail` may also be called with null.
                `fail` should not be called after the action has returned.


If a callback from `async()` has been called with an error, or fail has been
called at least once with an error, the action will fail. Depending on
schedule `options.breakOnError` this may stop the schedule prematurely, but
concurrent actions will not stop.

**Chaining:**

TODO:

  - `this.schedule.run` : (and friends, see `Schedule`)
     - in theory, chained schedules can also start inside actions,
      but this has not been tested. See also Schedule Chaining.

## Shell
TODO


## Passwords
TODO
## sudo
