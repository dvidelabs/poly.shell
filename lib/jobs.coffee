_ = require 'underscore'
util = require './util'
shell = require('./shell').shell
sysutil = require('util')

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

_debug = (msg, value) ->
  console.log "[DEBUG] : #{msg}:#{_fmtMsg sysutil.inspect value}"


_reportSchedule = (sched, sites, actioncount) ->
  opts = sched.opts
  return unless opts.log
  roles = opts.roles
  jobs = sched.jobs
  type = sched.type
  id = sched.id
  name = if sched.opts.name then "#{opts.name}" else ""
  desc = if sched.opts.desc then "- #{opts.desc}" else ""
  if name and desc
    desc = " " + desc
  headerln = "[#{id}] : #{type} job schedule#{_fmtMsg name + desc}\n  jobs:\n"
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


# Run all job specific actions for a single site concurrently.
_runSiteActions = (jobname, sched, config, actions, cb) ->
  opts = sched.opts
  site = config.name
  config.log = opts.log
  config.quiet = opts.quiet
  n = actions.length
  return cb null, site unless n
  i = 0
  total = n
  for action in actions
    ++i
    if total == 1
      name = jobname
    else
      name = jobname + '(' + i + '/' + total + ')'
    e = null
    ctx = sched._ctx
    ++ctx.actioncount
    id = "#{ctx.batch}-#{sched.index}-#{ctx.actioncount}"
    issuer = "[#{id}] #{site}"      
    config.issuer = issuer
    actionObj = {
      _ctx: ctx, _sched: sched, opts,
      shared: ctx.shared, batch: ctx.batch, id, issuer,
      index: i, total, job: name, site: config, shell: shell(config),
      report: (msg) ->
        if opts.log or opts.report
          state = if n then "" else " (background)"
          console.log "#{issuer} :#{state} reporting: #{_fmtMsg(msg)}"
      debug: (msg, value) ->
        if opts.debug
          value = if value then ":" + _fmtMsg sysutil.inspect value else ""
          console.log "[DEBUG] #{issuer} : #{msg}#{value}"
    }
    _cb = (err) ->
      if n == 0
        msg = "action fail or action async callback used after action termination"
        console.log "\nNOT GOOD : #{issuer} :#{_fmtMsg(msg)}\n"
        throw new Error "action fail or action async callback used after action termination"
      if n < 0
        throw new Error "internal schedule error"
      if err
        e ?= []
        e.push err
        console.log  "#{issuer} : failed job: #{name} with error:#{_fmtMsg(err)}" if opts.log or not opts.quiet
      else
        console.log  "#{issuer} : completed job: #{name}" if opts.log
      cb(e, actionObj) unless --n
    actionObj.async = () -> ++n; _cb
    actionObj.fail = (err) -> ++n; _cb(err)
    console.log  "#{issuer} : starting job: #{name}" if opts.log
    config.log = opts.log
    config.issuer = issuer
    action.call actionObj
    # call the cb for action to simplify simple actions
    _cb()
    # action can get one or more callbacks by calling async like this
    #   cb1 = this.async()
    #   cb2 = this.async()
    #   setTimeout(cb1, 10)
    #   setTimeout(cb2, 20)
    # sync and async actions can call @fail any number of times to report failure
    #   this.fail "foo"
    #   this.fail "bar" 
  return null
  
# non-public interface
class _Job
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

# Jobs require a sites collection to manage the configuration
# of sites that jobs can run on.
# Sites can be defined using the Environments class
# where each environment name represents a site.
# A site env is used to initialize Shell objects such
# that local and remote hosts can be accessed.
#
# A jobs collection is created using the exported
# jobs function.
class Jobs

  constructor: (@sites = require('..').sites()) ->

    @_jobs = {}

  _findJob: (sched, jobname) ->
    if job = @_jobs[jobname]
      return job
    throw new Error "job #{jobname} not found" unless sched.opts.allowMissingJob
    console.log "[#{sched.batch}] ignoring undefined job #{jobname}" if sched.opts.log
    return null

  _prepareBatch: (type, jobs, opts_in, complete) ->
    if typeof opts_in is 'function'
      complete = opts_in
      opts_in = null
    complete ?= ->
    ctx = @_ctx or {}
    opts_in ?= {}
    ctx.opts ?= {}
    opts = _.clone _.extend(ctx.opts, opts_in)
    unless ctx.batch
      ctx.batch = util.uid(6)
      ctx.starttime = new Date()
      ctx.actioncount = 0
      ctx.schedulecount = 0
      ctx.shared = opts.shared ? {}
      console.log "[#{ctx.batch}] starting new batch; #{ctx.starttime}" if opts.log
    ++ctx.schedulecount
    # ctx.opts carries over options for the next schedule,
    # but are never used directly

    jobs = _.flatten([jobs])
    name = if opts.name then " (#{opts.name})" else ""
    issuer = "[#{ctx.batch}-#{ctx.schedulecount}] :#{name} #{type}"

    sched = {
      __proto__: this
      _ctx: ctx
      report: (msg) ->
        if opts.log or opts.report
          console.log "#{issuer} job schedule completion : reporting:#{_fmtMsg(msg)}"
      debug: (msg, value) ->
        if opts.debug
          value = if value then ":" + _fmtMsg sysutil.inspect value else ""
          console.log "[DEBUG] #{issuer} : #{msg}#{value}"
      shared: ctx.shared
      batch: ctx.batch
      name: opts.name
      issuer
      type
      opts
      jobs
      index: ctx.schedulecount
      id: "#{ctx.batch}-#{ctx.schedulecount}"
      }
    # make it possible to run new schedules in same batch
    
    _complete = (args...) ->
      if opts.log
        errors = if args.length then args[0] else null
        if opts.log or (errors and not opts.quiet)
          emsg = if errors then "with #{errors} errors" else "successfully"
          console.log "#{issuer} job schedule completed #{emsg}"
      complete.apply sched, args
    sched._complete = _complete
    return sched

  
  # Adds actions to a new or existing named job.
  #
  # If no role is given, the jobname is used as role.
  add: (name, roles, actions) ->
    if typeof name isnt 'string' or name.length < 1      
      throw new Error "Jobs.add : job name missing"

    roles = [] unless roles
    actions = [] unless actions
    roles = _.flatten [roles]
    actions = _.flatten [actions]
    if roles.length and typeof roles[0] is 'function'
      actions = roles
      roles = [name]
      if arguments.length > 2
        throw new Error "Jobs.add unexpected argument after actions"
    if roles.length == 0
      roles = [name]
    for a in actions
      if typeof a isnt 'function'
        throw new Error "Jobs.add : action argument should be a function, or an array of functions"
    for r in roles
      if typeof r in roles is 'function'
        throw new Error "Jobs.add : got action function where role name was expected"
    job = @_jobs[name]
    unless job
      @_jobs[name] = job = new _Job(name, @sites)
    if actions.length > 0
      job.addAction roles, actions
    return job

  # Run job or jobs in a site-sequential schedule
  # where two jobs do not overlap on a single site
  # but may overlap on different sites.
  # In effect each site pulls the next job when ready,
  # and is normally what is desired.
  runSiteSequential: (jobs, opts, complete) ->
    sched = @_prepareBatch('site-sequential', jobs, opts, complete)    
    jobs = sched.jobs
    actionmap = {}
    pending = 1
    errors = 0
    roles = sched.opts.roles
    opts = sched.opts
    actioncount = 0
    cb = (err) ->
      throw new Error "internal schedule error" if pending <= 0
      ++errors if err
      sched._complete(errors or null) unless --pending  
    for jobname in jobs      
      if job = @_findJob sched, jobname
        siteactions = job.siteActions(roles)
        for site, actions of siteactions
          actioncount += actions.length          
          # helper to bind current variable scope for callback
          _jobrunner = (jobname, site, config, actions) ->
            _cb = (err) ->
              next = undefined
              unless err and opts.breakOnError
                next = actionmap[site].shift()
              if next then next() else cb err
            -> _runSiteActions jobname, sched, config, actions, _cb
          if actions.length
            config = @sites.get(site)            
            util.pushmap actionmap, site, _jobrunner(jobname, site, config, actions)
    _reportSchedule(sched, _.keys(actionmap), actioncount)
    for site, actions of actionmap
      # call the head of each action chain in parallel
      # callbacks will sequentially pull the rest
      next = actions.shift()
      if next
        ++pending
        next()
    cb()

  # synonym for default run mode
  run: -> @runSiteSequential.apply(@, arguments)

  # Run all actions of all jobs in a parallel schedule.
  runParallel: (jobs, opts, complete) ->
    sched = @_prepareBatch('parallel', jobs, opts, complete)    
    jobs = sched.jobs
    pending = 1
    errors = 0
    cb = (err) ->
      throw new Error "internal schedule error" if pending <= 0
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
            actioncount += actions.length
            sites.push site if actions.length
    _reportSchedule(sched, _.uniq(sites), actioncount)
    while q.length
      siteactions = q.shift()
      for site, actions of siteactions
        ++pending
        _runSiteActions jobname, sched, @sites.get(site), actions, cb
    cb()

  # Run all jobs in a sequential schedule across all sites.
  # Actions within a single job still run concurrently.
  runSequential: (jobs, opts, complete) ->
    sched = @_prepareBatch('sequential', jobs, opts, complete)
    jobs = sched.jobs
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
          q.push [ jobname, sched, @sites.get(site), actions ]
    _reportSchedule(sched, _.uniq(sites), actioncount)
    next = (err) ->
      # the this pointer of next is not the job
      # because we injecting a context in the callbacks
      ++errors if err
      w = q.shift()
      if not w or (errors and sched.opts.breakOnError)
        return sched._complete errors or null
      w.push next
      _runSiteActions.apply null, w
    next()

#   Create class to schedule jobs across multiple sites:
exports.jobs = (sites) -> new Jobs(sites)
