util = require 'util'
_ = util._

roles = require(./roles)
sitesOfRoles = roles.sitesOfRoles

# map a site name to a configuration hash
siteConfig = roles.siteConfig

class Job
  constructor: (@name) ->
    @actions = []
  
  # action : function, or array of functions
  # actions are executed concurrently in the same job
  # also for the same site, but every action is executed
  # at most once.
  addAction: (roles, actions)
    @actions.push[roles, actions]
    return null

  # list all sites that have associated actions in this job
  sites: () ->
    return sitesOfRoles(_.map(@actions, (x) -> x[0]))
  
  # return a map of sites to actions, possibly restricted by a filter role set
  # note: the map may be outdated if roles are modified subsequently
  siteActions: (filter = null) ->
    map = {}
    map2 = {}
    for a in @actions
      if actions.length
        for site in sitesOfRoles(a[0], filter)
          util.pushmap map, site, a[1]
    for site, actions in map
      a = _.flatten actions
      if a.length then map2[site] = a
    return map2

_runSiteActions = (ctx, jobname, site, actions, cb) ->
  cfg = siteConfig(site)
  n = actions.length
  return cb null, site unless n
  for action in actions
    e = null
    _cb = (err) ->
      if err
        e ?= []
        e.push err
      cb e, site unless --n          
    action { ctx, jobname, site, sh: shell(cfg) }, _cb


# Using a queue per site (`actionmap`) makes it easier
# to extend the per site action sequence at both ends.
# {cb} is called once per site with actions in the given job
_chainJobActions = (actionmap, job, ctx, cb) ->
  unless job
    return if ctx.allowMissingJob
    throw "job '#{job.name}' not found"
  siteactions = job.siteActions(ctx.roles)
  for site, actions in siteactions
    _cb = (err) ->
      next = undefined
      unless err and ctx.breakOnError
        next = actionmap[site].shift()
      if next
        next()
      else
        cb err, site
    # be careful to modify array in place
    util.pushmap actionmap, site, actions, ->
      _runSiteActions ctx, job.name, site, actions, _cb

class Jobs
  constructor: ->
    @jobs = {}
  
  # addJob may be called multiple times with same name
  # but different roles.
  #
  # A roles is a role name or an array of role names.
  # A role name represents a set of sites.
  # Roles may be updated so the set of sites a job
  # operates on, is not static.
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
  # The options include configuration settings
  # and a shell that can execute local or remote shell
  # commands, depending on the location of the site.
  # A shell can coordinate password caching across actions
  # on same or multiple sites.
  #
  # A job is a set of concurrent actions associated with
  # a number of sites derived from the given roles.
  # Within a job, some actions may only execute on a subset
  # of all sites affected by the job.
  # Job execution may specify a role filter which restricts
  # the job to a subset of all sites supported.
  addJob: (name, roles, actions) ->
    job = jobs[name]
    unless job
      jobs[name] = job = new Job(name)
    job.addAction roles, actions
    return job
  
  # Run job or jobs in sequence per site, but in parallel over all sites.
  # Actions within a single job always run concurrently.
  #
  # `jobs` : job name or (nested) array of job names.
  # `ctx.roles` : optional role filter to restrict number of affected sites.
  #    If `filter` is null or 'any', jobs will run on all sites
  #    they are defined for.
  # `ctx.breakOnError = true` terminates action sequence on a site that fails.
  # `ctx.allowMissingJob = true` : allow missing jobs without throwing an exception.
  # `complete` : called with null or error count once all sites have completed.
  # (More detailed control can be had by having actions communicate on the ctx object,
  #  for example using events and/or context locks).
  runSiteSequential: (jobs, ctx, complete) ->
    if typeof ctx is 'function'
      complete = ctx
      ctx = null
    complete ?= ->
    ctx ?= {}
    jobs = _.flatten(jobs)
    actionmap = {}
    pending = 1
    errors = 0
    for job in jobs
      cb = (err, site)
        ++errors if err
        complete(errors or null) unless --pending  
      _chainJobActions actionmap, @jobs[job], ctx, cb
    for site, actions of actionmap
      ++total
      next = actions.shift()
      if next
        ++pending
        next()
    complete(errors or null) unless --pending

  # Run all actions of all jobs concurrently.
  # `jobs` : job name or (nested) array of job names.
  # `ctx.roles` : restrict number of affected sites
  #   (unless missing or 'any').
  # `ctx.breakOnError` has no effect since all
  #   actions are started before we can detect errors.
  # `ctx.allowMissingJobs = true` : ignore missing jobs.
  # `complete` : called with null or error count
  #   once all actions have completed.
  # See also runSiteSequential.
  runParallel: (jobs, ctx, complete) ->
    if typeof ctx is 'function'
      complete = ctx
      ctx = null
    complete ?= ->
    ctx ?= {}
    jobs = _.flatten(jobs)
    pending = 1
    for jobname in jobs
      job = @jobs[jobname]
      unless job
        throw "job '#{job.name}' not found" unless ctx.allowMissingJob
      else
        siteactions = job.siteActions(ctx.roles)
        for site, actions in siteactions
          cb = (err)
            ++errors if err
            complete(errors or null) unless --pending
          _runSiteActions ctx, job.name, site, actions, cb
    complete(errors or null) unless --pending

  # Run all jobs sequentially across all sites.
  # Actions within a single job still run concurrently.
  #
  # `jobs` : job name or (nested) array of job names.
  # `ctx.roles` : restrict number of affected sites
  #   (unless missing or 'any').
  # `ctx.breakOnError = true` will terminate subsequent jobs
  #   on all sites if a single site fails.
  # `ctx.allowMissingJob = true` : allow missing jobs without
  #   throwing an exception.
  # `complete` : called with error count once last job completes.
  #    If ctx.breakOnError == true, complete may be called earlier.
  # See also runSiteSequential.
  runSequential: (jobs, ctx, complete) ->
    if typeof ctx is 'function'
      complete = ctx
      ctx = null
    complete ?= ->
    ctx ?= {}
    jobs = _.flatten(jobs)
    job = jobs.shift()
    errors = 0
    schedule = ->
      job = jobs.shift()
      if errors and ctx.breakOnError
        job = null
      return complete(errors or null) unless job
      siteactions = job.siteActions(ctx.roles)
      pending = 1
      for site, actions in siteactions
        ++pending
        cb = (err) ->
          ++errors if err
          schedule() unless --pending
        _runSiteActions ctx, job.name, site, actions, cb
    schedule()
    