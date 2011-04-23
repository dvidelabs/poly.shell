_ = require 'underscore'
util = require './util'
shell = require('./shell').shell

class Job
  constructor: (@name, @sites) ->
    @_actions = []

  # Add actions for specific roles.
  # A job need not run all actions in all roles.
  # All actions are concurrent within the job.
  #
  # `roles` : role name or (nested) array of role names.setidentifies sites the actionsn will run on.
  #   roles are resolved at runtime.
  # `actions' : action function or (nested) array of action functions.
  #   action(env, callback(err)) where env has:
  #     `env.ctx` : execution global settings
  #     `env.job` : name of job the action is executed from
  #     `env.site` : site configuration incl. site.name where the action is running
  #     `env.shell` : a shell object that can run shell commands on the site.
  # also for the same site, but every action is executed
  # at most once.
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
  runSiteActions: (ctx, site, actions, cb) ->
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
      _cb = (err) ->
        if err
          e ?= []
          e.push err
          console.log  "#{site} : failed job: #{name} with error: #{err}" if ctx.log
        else
          console.log  "#{site} : completed job: #{name}" if ctx.log
        cb(e, site) unless --n
      console.log  "#{site} : starting job: #{name}" if ctx.log
      config.log = ctx.log
      action.call { ctx, index: i, total, job: name, site: config, shell: shell(config) }, _cb
    return null

  # Using a queue per site (`actionmap`) makes it easier
  # to extend the per site action sequence at both ends.
  # {cb} is called once per site with actions in the given job
  chainJobActions: (actionmap, ctx, cb) ->
    siteactions = @siteActions(ctx.roles)
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
        @runSiteActions ctx, site, actions, _cb

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
  
  # add may be called multiple times with same name
  # but different roles.
  #
  # If no role is given, the jobname is used as role.
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
  add: (name, roles, actions) ->
    if typeof roles is 'function'
      actions = roles
      roles = name
    job = @_jobs[name]
    unless job
      @_jobs[name] = job = new Job(name, @sites)
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
    jobs = _.flatten([jobs])
    actionmap = {}
    pending = 1
    errors = 0
    cb = (err) ->
      ++errors if err
      complete(errors or null) unless --pending  
    for jobname in jobs      
      if job = @_jobs[jobname]        
        job.chainJobActions actionmap, ctx, cb
      else
        throw new Error "job '#{jobname}' not found" unless ctx.allowMissingJob
    for site, actions of actionmap
      next = actions.shift()
      if next
        ++pending
        next()
    complete(errors or null) unless --pending

  # synonym for default run mode
  run: (jobs, ctx, complete) -> @runSiteSequential(jobs, ctx, complete)

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
    jobs = _.flatten([jobs])
    pending = 1
    errors = 0
    cb = (err) ->
      ++errors if err
      complete(errors or null) unless --pending
    for jobname in jobs
      unless job = @_jobs[jobname]
        throw "job '#{job.name}' not found" unless ctx.allowMissingJob
      else
        siteactions = job.siteActions(ctx.roles)
        for site, actions of siteactions
          job.runSiteActions ctx, site, actions, cb
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
    jobs = _.flatten([jobs])
    errors = 0
    _jobs = @_jobs # bind name
    next = ->
      jobname = jobs.shift()
      if errors and ctx.breakOnError
        jobname = null
      if(jobname)
        job = _jobs[jobname]
        unless job
          return next() if ctx.allowMissingJob
          throw "job #{jobname} not found"
      else
        return complete(errors or null)
      siteactions = job.siteActions(ctx.roles)
      pending = 1
      for site, actions of siteactions
        ++pending
        cb = (err) ->
          ++errors if err
          next() unless --pending
        job.runSiteActions ctx, site, actions, cb
    next()

exports.jobs = (sites) -> new Jobs(sites)
