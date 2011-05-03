## Schedule

A schedule is started by `jobs.run`, or one the related functions, and ends
when the callback is being called. See also `jobs.run`.

The schedule object is visible as `this` in the callback function given to
`jobs.run`.

### Batch

A batch is a context shared across chained schedules and allow chained
schedules to inherit options from parent schedules. The batch also provide a
globally unique identifier that prefixes all schedule identifiers in the
batch, and not least: access to global custom shared state across all
schedules, and all job actions in these schedules.

Unless jobs are chained, a single schedule activated by `jobs.run` is the
same as a single batch.

### Chaining Schedules (this.run)

The schedule object can start new schedules in a chain
which serves the dual purpose of synchronising schedules and passing
information from previous schedules. Options like `roles`, `log` etc. are
inherited, but new options can be given to the `this.run` function.

    ...
    jobs.add(...);
    ...
    jobs.run(['job1', 'job2'], 'deploy', function() {
      // callback when done
      this.runSequential(['job3', 'job4'], 'upgrade');
    });

Chaining inherits options and roles, but can change options as
needed, for example chaining the schedule from the default to sequential
and the roles from 'deploy' to 'upgrade').

### Schedule Object
The schedule object (the this pointer in a `jobs.run` callback) has the
following methods and properties:

**Properties**

- `this.batchid`: a globally unique batch identifier string used to prefix all other identifiers.    
- `this.id`: A globally unique id for this schedule invocation with the form:
    `batchid-scheduleindex`
- `this.index`: the schedule index of this batch, starting with 1.
- `this.issuer`: string uses as prefix for logging messages. It includes the schedule id and has the form:
    "[this.id] site.name"
- `this.jobs`: the flattened array of job names executing in this schedule, possibly with duplicates.
- `this.name`: an optional schedule name from the schedule options for logging.
- `this.options`: the options passed to `jobs.run` or `this.run`, and anything inherited from the batch.
- `this.shared`: access to the batch global shared object for customised information sharing.
- `this.type`: the schedule type, currently one of [`sequential`, `parallel`, `site-sequential`]

**Methods**

- `this.report(msg)`: customised logging when `log` or `report` options are true for the schedule.
- `this.debug(msg, [value])`: debug message and optional object inspection dump when `options.debug` is true.

**Chaining methods**

- `this.run`
- `this.runSiteSequential`
- `this.runSequential`
- `this.runParallel`

These are similar to the `jobs.run` family of functions and have access to the
sites and jobs of the original schedule that started the batch.
