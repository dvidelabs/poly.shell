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
created, and new actions may be added in new roles. (This is unlike adding and
updating site configurations that effect immediately on sites in the given
roles.)

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

    jobs.add('upload-web', 'web', function() {
      cb = this.async();
      this.shell.run("scripts/deploy.sh", cb);
    }
    jobs.add('upload-web', 'web', function() {
      cb = this.async();
      this.shell.run("scripts/backup.sh", cb);
    }
    jobs.add('upgrade-web', 'web', function() {
      cb = this.async();
      this.shell.run("scripts/upgrade.sh", cb);
    }
    jobs.runSequential(['upload-web', 'upgrade-web'], 'web',
      { breakOnError: true },
      function(err) {
        if(err)
        // not part of Polyshell
        email(this.site.adminemail, "backups failed");
    });

Note that we could just have called the above actions in single script, but by
splitting it up, we can wait for all web servers to complete their backups and site uploads
before switching over all servers to the new site version.
By having backup in a separate action we get better error reporting without risking not
running it along with the upgrade.

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

### jobs.runAtomic(jobs, [roles], [options], [callback])

Runs a job on one site at a time. Starts a new job when that last matching
site has completed the current job. Job actions within a single job on a single site
run concurrently. `callback` is called once all jobs have
completed on all sites.

See `jobs.run` for more details.

### jobs.runSequential(jobs, [roles], [options], [callback])

Run jobs one after another in a `sequential` schedule such that a single job
runs concurrently on all matching sites, but also such that no two jobs
overlap across all sites. `callback` is called once all jobs have completed on
all sites.

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
shared state in all action functions and all schedule callbacks. `this.batchid` provides
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

`options`:

- `options.roles`: optional role filter to restrict number of affected sites.
- `options.name`: optional schedule name for logging.
- `options.desc` : optional schedule description for logging.
- `options.breakOnError`: if true terminate action sequence on a site that fails.
- `options.allowMissingJob`: if true allow missing jobs without throwing an exception.
- `options.report`: if true enable custom report output, even when `options.log` disabled.
- `options.debug`: if true enable custom debug output - independent of `options.log`.
- `options.quiet`: if true suppress error messages, overridden by `options.log`.

### jobs.sharePassword(roles, [password])

Assigns a common password cache to all sites currently in the given `roles`.
Any sites added to a role subsequently will not automatically be included.
This is in line with how site configurations normally work, but unlike how
`jobs.add` use late binding of role names, so watch out for that.

The optional `password` argument will set a password in the cache such
the the user is not prompted if the password match.

`jobs.sharedPassword` can be called multiple times to have different
password agents for different sites. Any existing caches will be replaced.

Many other scenarios are possible, but then password agents must be created
manually and stored manually in the `passwordCache` property of relevant
sites, possibly using a custom merge function for updating site
configurations. This is beyond the scope of this documentation.
