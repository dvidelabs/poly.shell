## Actions

An action is an anonymous function with no arguments that is added to a job
using the `jobs.add` method:

    jobs = require('poly').jobs();

    jobs.add('rollback', function() {
      this.report("this function is the rollback action");
    });

A job can have multiple actions in different roles. This can, for example, be
used to add OS specific actions:

    jobs = require('poly').jobs();
    jobs.sites.add('d1', 'debian', { host: 'd1.example.com' });
    jobs.sites.add('d2', 'debian', { host: 'd2.example.com' });
    jobs.sites.add('c1', 'centos', { host: 'c1.example.com' });
    
    jobs.add('sysupdate', ['debian'], function() {
      // ...
    });
    jobs.add('sysupdate', ['centos'], function() {
      // ...
    });
    date = new Date();
    if(date.getDay() === "Tuesday")
      jobs.run('sysupdate');
    else
      jobs.run('sysupdate', 'debian');

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

To get some less unique identifiers, a combination of `this.batchid`,
`this.site.name` and `this.job` may provide the necessary means for
communication across actions in, for example, the file system, a database, or
in the `this.shared` object.

Action identifiers are used to tag log messages such as action is now starting
on this site... Custom logging with identifier tag is available through the
`this.report` and `this.debug` functions inside actions.

### Action Object

The object referenced by `this` inside actions is called the action object, and has
the following methods and properties:

**Properties**

- `this.batchid`:
    a globally unique identifier for this batch, used to prefix action id.
  `this.count`:
    the action invocation index of this batch, starting with 1. The index is
    unique to this action within the current batch.
- `this.fragment`:
    a number between 1 and `fragments`. The same action may have a different fragment
    number on a different site, but it is unique for the current job
    invocation on the current site.
    Logging use the job name suffix `(fragment/fragments)` when there is more than
    one fragment.
- `this.fragments`:
    the total number of actions (fragments) running in this job invocation on this site.
- `this.id`:
    the action id is globally is unique for this invocation. It has the form:
    `batchid-scheduleindex-actionindex`.
- `this.issuer`:
    the issuer is a string used for logging. It has the form:
    `[batchid-scheduleindex-actionindex] sitename`
- `this.index`:
    index of this action within the current schedule. Used as the third value in
    the `this.id` string.
- `this.jobname`:
    name of the currently executing jobs (but not which invocation within the schedule).
- `this.options`:
    direct and inherited schedule options.
- `this.shared`:
    a batch global shared object for customised information sharing.
- `this.shell`:
    the shell object configured with data from site config and
    schedule options such as `options.log`. Run local or remote shells using `this.shell.run`.
    See also `Shell`.
- `this.site`:
    the site configuration object, for example used to access the site name through: `this.site.name`.

**Methods**

- `this.debug(msg, [value])`:
    debug message and optional object inspection dump when `debug` option is true.
- `this.report(msg)`:
    customised logging when `log` or `report` options are true for the schedule.

**Flow and Error Control**

- `this.async() => callback(err)`:
    acquires a callback function: "callback = `this.async()`" that can be
    called by asynchronous functions, for example `this.shell.run(cmd, callback)`.
    `async()` may be called multiple times to coordinate multiple
    async methods in the action. Each acquired callback **must** be called
    exactly once, either with null or an error. `this.async()` must not be
    called after the action has returned unless there are uncalled callbacks
    acquired by other calls to `this.async()` with the same `this` reference.
- `this.fail(err)`:
    report an error for synchronous actions that do not need a callback.
    Can be called with null which has no effect. Synchronous method may, as an
    alternative, acquire a callback with `this.async()` and call the returned
    callback with an error code. `fail` is simply shorthand for this.

If a callback from `async()` has been called with an error, or fail has been
called at least once with an error, the action will fail. Depending on
schedule `options.breakOnError` this may stop the schedule prematurely, but
concurrent actions will not stop.
