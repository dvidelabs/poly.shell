_ = require 'underscore'
util = require './util'
shell = require('./shell').shell

_fmt = { indent: "    ", sep: ", " }

_fmtMsg = (msg, trailingnl) ->
  msg = msg.toString()
  msg = if msg.length > 20 or msg.indexOf('\n') >= 0
    "\n" + util.indentMsg(msg, _fmt)
  else " " + msg
  if trailingnl
    msg += '\n'
  msg

_fmtLst = (lst, trailingnl) ->
  msg = util.formatList(lst, _fmt)
  if trailingnl
    msg += '\n'
  msg

_reportSchedule = (sched, sites, actioncount) ->
  unless sched.opts.log
    return
  roles = sched.opts.roles
  jobs = sched.jobs
  type = sched.type
  id = sched.id
  name = if sched.opts.name then " (#{sched.opts.name})" else ""
  headerln = "[#{id}] :#{name} scheduling #{type} jobs:\n"
  jobsln = _fmtLst jobs, true
  restrictln = ""
  if sites.length
    matchln = "  matching #{actioncount} actions (total) distributed over sites:\n"
    siteln = _fmtLst sites
  else
    matchln = "  schedule did not match any actions on any sites"
    siteln = ""
  if roles
    restrictln = "  restricted to roles:\n    #{_.flatten([roles]).join(', ')}\n"
  console.log "#{headerln}#{jobsln}#{restrictln}#{matchln}#{siteln}"

_prepareBatch = (type, jobs, opts_in, complete) ->
  if typeof opts_in is 'function'
    complete = opts_in
    opts_in = null
  complete ?= ->
  opts_in ?= {}
  ctx = @_ctx or {}
  unless ctx.batch
    ctx.batch = util.uid(6)
    ctx.starttime = new Date()
    ctx.actioncount = 0
    ctx.schedulecount = 0
    ctx.shared ?= {}
    ctx.opts ?= {}
    console.log "[#{ctx.batch}] starting new batch; #{ctx.starttime}"
  ++ctx.schedulecount
  # ctx.opts carries over options for the next schedule,
  # but are never used directly
  
  opts = _.clone _.extend(ctx.opts, opts_in)
  jobs = _.flatten([jobs])
  name = if opts.name then " (#{opts.name})" else ""
  issuer = "[#{ctx.batch}-#{ctx.schedulecount}] :#{name} #{type}"

  sched = {
    _ctx: ctx
    report: (msg) ->
      if ctx.log
        console.log "#{issuer} job schedule completion : reporting:#{_fmtMsg(msg)}"
    shared: ctx.shared
    batch: ctx.batch
    type
    opts
    jobs
    index: ctx.schedulecount
    id: "#{ctx.batch}-#{ctx.schedulecount}"
    }
  _complete = (args...) ->
    complete.apply sched, args
    if opts.log
      errors = if args.length then args[0] else null
      emsg = if errors then "with #{errors} errors" else "successfully"
      console.log "#{issuer} job schedule completed #{emsg}"
  sched._complete = _complete
  return sched

class Job
  constructor: (@name, @sites) ->
    @_actions = []

  addAction: (roles, actions) ->
    @_actions.push [roles, actions]
    return null

  # Returns a map of sites to actions, possibly restricted by a filter role set.
  # Note: the map may be outdated if roles are modified subsequently.
  siteActions: (filter = null) ->
    map = {}
    for a in @_actions
      for site in @sites.list(a[0], filter)
          util.pushmap map, site, a[1]
    for site, actions of map
      map[site] = _.flatten actions
    return map

  # Run all actions for a single site concurrently.
  runSiteActions: (sched, site, actions, cb) ->
    config = @sites.get(site)
    n = actions.length
    return cb null, site unless n
    i = 0
    total = n
    for action in actions
      ++i
      if total == 1
        name = @name
      else
        name = @name + '(' + i + '/' + total + ')'
      e = null
      ctx = sched._ctx
      ++ctx.actioncount
      id = "#{ctx.batch}-#{sched.index}-#{ctx.actioncount}"
      issuer = "[#{id}] #{site}"      
      actionObj = {
        _ctx : ctx, _sched: sched,
        shared: ctx.shared, batch: ctx.batch, id, 
        report : (msg) ->
          console.log "#{issuer} : reporting: #{_fmtMsg(msg)}"      
        index: i, total, job: name, site: config, shell: shell(config) }
      _cb = (err) ->
        if err
          e ?= []
          e.push err
          console.log  "#{issuer} : failed job: #{name} with error:#{_fmtMsg(err)}" if ctx.log
        else
          console.log  "#{issuer} : completed job: #{name}" if ctx.log
        cb(e, actionObj) unless --n
      console.log  "#{issuer} : starting job: #{name}" if ctx.log
      config.log = sched.opts.log
      config.name = issuer
      action.call actionObj, _cb
    return null

  # Using a queue per site (`actionmap`) makes it easier
  # to extend the per site action sequence at both ends.
  # {cb} is called once per site with actions in the given job
  chainJobActions: (actionmap, sched, cb) ->
    siteactions = @siteActions(sched.opts.roles)
    for site, actions in siteactions
      _cb = (err) ->
        next = undefined
        unless err and sched.opts.breakOnError
          next = actionmap[site].shift()
        if next
          next()
        else
          cb err, site
      # be careful to modify array in place
      util.pushmap actionmap, site, actions, ->
        @runSiteActions sched, site, actions, _cb

# Jobs require a sites collection to manage the configuration
# of sites that jobs can run on.
# Sites can be defined using the Environments class
# where each environment name represents a site.
# A site env is used to initialize Shell objects such
# that local and remote hosts can be accessed.
#
class Jobs
  
  constructor: (@sites) ->
 
    @_jobs = {}

  _findJob: (sched, jobname) ->
    if job = @_jobs[jobname]
      return job
    throw new Error "job #{jobname} not found" unless sched.opts.allowMissingJob
    console.log "[#{sched.batch}] ignoring undefined job #{jobname}" if sched.opts.log
    return null
  
  
  # Adds actions to a new or existing named job.
  #
  # If no role is given, the jobname is used as role.
  #
  # Roles are used to restrict the job to specific
  # sites that match these roles.
  # When the job is subsequently run, the job
  # may be further restricted to a subset of roles.
  #
  # Roles cannot be added, only restricted, when
  # running. However, sites may be added by including
  # them in roles after a job has been created.
  #
  # When a job is added multiple times, each action
  # is associated with those roles given when added
  # to the job. In effect a job becomes a cluster
  # of actions that run together, but not necessarily
  # in the same place, but always at the same time.
  #
  # Actions allways run concurrently, regardless of the
  # schedule used to run multiple jobs.
  #
  # example roles (arrays are flattened before use):
  #  "www"
  #  ["test", "deploy"]
  #  ["db", ["test", "deploy"]]
  #
  # A site is a name that maps to configurations settings
  # which typically include a host domain, a user,
  # and a local path. A site may be local (no host domain),
  # or remote. .ssh/config is typically used to map a host
  # to a real remote host with ssh keys.
  #
  # An action is a function that receives options and a
  # a callback. The callback must be called when the action
  # is considered complete wrt. error handling and dependent
  # actions, but the action may continue after that point.
  # It is, however, vital that the callback is called exactly
  # once.
  add: (name, roles, actions) ->
    if typeof roles is 'function'
      actions = roles
      roles = name
    job = @_jobs[name]
    unless job
      @_jobs[name] = job = new Job(name, @sites)
    job.addAction roles, actions
    return job

  # Run job or jobs in site-sequential schedule
  # where two jobs do not overlap on a single site
  # but may overlap on different sites.
  # In effect each site pulls the next job when ready,
  # and is normally what is desired.
  #
  # Multiple actions within a single job always run concurrently.
  #
  # `jobs` : job name or (nested) array of job names.
  # `opts.roles` : optional role filter to restrict number of affected sites.
  #    If `filter` is null or 'any', jobs will run on all sites
  #    they are defined for.
  # `opts.breakOnError = true` terminates action sequence on a site that fails.
  # `opts.allowMissingJob = true` : allow missing jobs without throwing an exception.
  # `complete` : called with null or error count once all sites have completed.
  #    complete is wrapped so it runs with a schedule object
  #    as this pointer.
  # (More detailed control can be had by having actions communicate
  #  over the shared object provided in the action and schedule objects).
  runSiteSequential: (jobs, opts, complete) ->
    sched = _prepareBatch('site-sequential', jobs, opts, complete)    
    actionmap = {}
    pending = 1
    errors = 0
    cb = (err) ->
      ++errors if err
      sched._complete(errors or null) unless --pending  
    for jobname in jobs      
      if job = @_findJob sched, jobname
        job.chainJobActions actionmap, sched, cb
    if sched.opts.log
      sites = []
      actioncount = 0
      for site, actions of actionmap
        actioncount += actions.length
        sites.push site
      _reportSchedule(sched, _.uniq(sites), actioncount)
    for site, actions of actionmap
      next = actions.shift()
      if next
        ++pending
        next()
    sched._complete(errors or null) unless --pending

  # synonym for default run mode
  run: (args...) -> @runSiteSequential.apply(this, args)

  # Run all actions of all jobs in a parallel schedule.
  # `jobs` : job name or (nested) array of job names.
  # `opts.roles` : restrict number of affected sites
  #    (unless missing or 'any').
  # `opts.breakOnError` has no effect since all
  #    actions are started before we can detect errors.
  # `opts.allowMissingJob = true` : ignore missing jobs.
  #  missing options are inherited from containing schedules.
  # `complete` : called with null or error count
  #    once all actions have completed.
  #    complete is wrapped so it runs with a schedule object
  #    as this pointer.
  # See also runSiteSequential.
  runParallel: (jobs, opts, complete) ->
    sched = _prepareBatch('parallel', jobs, opts, complete)    
    pending = 1
    errors = 0
    cb = (err) ->
      ++errors if err
      sched._complete(errors or null) unless --pending
    q = []
    sites = []
    actioncount = 0
    for jobname in jobs
      if job = @_findJob sched, jobname
        siteactions = job.siteActions(sched.opts.roles)
        q.push siteactions
        if sched.opts.log
          for site, actions of siteactions
            sites.push site
            actioncount += actions.length        
    _reportSchedule(sched, _.uniq(sites), actioncount)
    while q
      siteactions = q.shift()
      for site, actions of siteactions
        job.runSiteActions sched, site, actions, cb
    sched._complete(errors or null) unless --pending

  # Run all jobs in a sequential schedule across all sites.
  # Actions within a single job still run concurrently.
  #
  # `jobs` : job name or (nested) array of job names.
  # `opts.roles` : restrict number of affected sites
  #   (unless missing or 'any').
  # `opts.breakOnError = true` will terminate subsequent jobs
  #   on all sites if a single site fails.
  # `opts.allowMissingJob = true` : allow missing jobs without
  #   throwing an exception.
  #  missing options are inherited from containing schedules.
  # `complete` : called with error count once last job completes.
  #    If opts.breakOnError == true, complete may be called earlier.
  #    complete is wrapped so it runs with a schedule object
  #    as this pointer.
  # See also runSiteSequential.
  runSequential: (jobs, opts, complete) ->
    sched = _prepareBatch('sequential', jobs, opts, complete)
    errors = 0
    q = []
    sites = []
    actioncount = 0
    for jobname in jobs
      if job = @_findJob sched, jobname
        siteactions = job.siteActions(sched.opts.roles)
        for site, actions of siteactions
          sites.push site
          actioncount += actions.length
          q.push [ job, sched, site, actions ]
    _reportSchedule(sched, _.uniq(sites), actioncount)
    next = (err) ->
      # the this pointer of next is not the job
      # because we injecting a context in the callbacks
      ++errors if err
      w = q.shift()
      if not w or (errors and sched.opts.breakOnError)
        return sched._complete errors or null
      w.push next
      job = w.shift()
      job.runSiteActions.apply job, w
    next()

exports.jobs = (sites) -> new Jobs(sites)
