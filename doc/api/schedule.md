## Schedule

A schedule is started by `jobs.run`, or one the related functions, and ends
when the callback is being called. See also `jobs.run`.

The schedule object is visible as `this` in the callback function given to
`jobs.run`, and as `this.schedule` in action objects.

### Chaining (`this.run`)

The schedule object can start new schedules in a chain
which serves the dual purpose of synchronising schedules and passing
information from previous schedules. Options like `roles`, `log` etc. are
inherited, but new options can be given to the `this.run` function.

### Batch

A batch is a context shared across chained schedules and allow chained
schedules to inherit options from parent schedules. The batch also provide a
globally unique identifier that prefixes all schedule identifiers in the
batch, and not least: access to global custom shared state across all
schedules, and all job actions in these schedules.

### Schedule Object
The schedule object (the this pointer in a `jobs.run` callback) has the
following methods and properties:

**Properties**

  - `this.batchid` :
  
      a globally unique batch identifier string used to prefix all other identifiers.
      
  - `this.id` :

      A globally unique id for this schedule invocation with the form:
      `batchid-scheduleindex`
      
  - `this.index` :
  
      the schedule index of this batch, starting with 1.
      
  - `this.issuer` :
  
      the prefix used for logging messages, which include the schedule id with the form
      [`this.id`] `site.name`
      
  - `this.jobs` :
  
      the flattened array of job names executing in this schedule, possibly with duplicates.
      
  - `this.name` :
  
      an optional schedule name from the schedule options for logging.
      
  - `this.options` :
  
      the options passed to `jobs.run` or `this.run`, and anything inherited from the batch.
      
  - `this.shared` :
  
      access to the batch global shared object for customised information sharing.
        
  - `this.type` :
  
      the schedule type, currently one of [`sequential`, `parallel`, `site-sequential`]

**Methods**

  - `this.report(msg)` :
  
      customised logging when `log` or `report` options are true for the schedule.
      
  - `this.debug(msg, [value])` :
  
      debug message and optional object inspection dump when `options.debug` is true.

**Chaining methods**

  - `this.run`
  - `this.runSiteSequential`
  - `this.runSequential`
  - `this.runParallel`

These are similar to the `jobs.run` family of functions and have access to the
sites and jobs of the original schedule that started the batch.
