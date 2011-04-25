assert = require('assert')
createJobs = require('..').jobs
util = require('..').util
envs = require('..').envs
createSites = envs

console.log "=> jobs test"

# The site settings are passed to the Shell constructor for running shell commands.
# If host: is missing, the shell command runs locally.
# If host is set, for example: { host: example.com },
# then .ssh/config file can be configured to point to a real test site
# with a real user account with ssh keys.
#
# The job runner overrides a few settings passed to the shell:
# The shell name and log option are passed from the responsible action.
#
# Site settings may also be used for arbitrary other settings since job actions
# can access a copy of the environment through the this.site property.
#
# (More complex configurations can be had by adding an envs() object to the
# shared object passed to the job scheduler. This supports role based configurations
# that are not necessarily interpreted as sites.)
#
loadSites = ->
  sites = createSites()
  
  # add two example sites in the deploy role; both with the property symlink = true
  sites.add ['example.com', 'app.example.com'], ['deploy', 'live'], { symlink: true }
  
  # add the property primary = true to the primary domain.
  sites.update 'app.example.com', { primary: true }
  
  # add a new site named 'foo.bar' in the test and deploy roles.
  sites.add 'foo.bar', ['test', 'deploy'], { path: '~/tmp/test', log: true }
  
  return sites


module.exports = {

  trivial: ->
    assert.equal 2+2, 4

  sites: ->
    sites = loadSites()
    assert.ok util.eqSet(sites.list('test'), ['foo.bar'])
    assert.ok util.eqlSet(sites.list(['test', 'deploy']), ['foo.bar', 'example.com', 'app.example.com'])
    assert.ok sites.get('foo.bar').log
    jobs = createJobs(sites)

  syncnofail: ->
    jobs = createJobs(loadSites())
    jobs.add 'syncnofail', 'example.com', ->
      @report "syncnofail running"
    jobs.run 'syncnofail', log: true, -> @report "syncnofail done"

  syncnofail2: ->
    jobs = createJobs(loadSites())
    jobs.add 'syncnofail2', 'example.com', ->
      err = null
      @report "syncnofail2 running"
      @fail err
    jobs.run 'syncnofail2', log: true
    
  syncfail: ->
    jobs = createJobs(loadSites())
    jobs.add 'syncfail', 'example.com', ->
      @fail "testing sync failure"
      @fail "can fail multiple times, if we so desire"
      @report "#{@job}-#{@index} running with expected errors"
      @debug "options", @opts
      console.log "syncfail ..."
    jobs.run 'syncfail', log: true, debug: true
    jobs.run 'syncfail', log: true, debug: false
    jobs.run 'syncfail', log: false, debug: true
    jobs.run 'syncfail', log: false, debug: true, quiet: true
    jobs.run 'syncfail'
    jobs.run 'syncfail', report: true
    
  async: ->
    jobs = createJobs(loadSites())
    jobs.add 'async', 'example.com', ->
       # don't call async inside the timeout
       # then our action will have completed prematurely
       cb1 = @async()
       cb2 = @async()
       action = this
       setTimeout((action.report "timeout 1"; cb1()), 10)
       setTimeout((action.report "timeout 2"; cb2()), 20)
    jobs.run 'async', log: true, -> @report "async done"

  asyncfail: ->
    jobs = createJobs(loadSites())
    jobs.add 'asyncfail', 'example.com', ->
       # each callback may receive an error
       cb1 = @async()
       cb2 = @async()
       action = this
       setTimeout((-> action.report "timeout 1"; cb1()), 10)
       setTimeout((-> action.report "timeout 2"; cb2 "something bad happened"), 20)
    jobs.run 'asyncfail', log: true, -> @report "async done with expected error"

  noasync: ->
    jobs = createJobs(loadSites())
    jobs.add 'noasync', 'example.com', ->
       action = this
       setTimeout((-> action.report "timeout"), 10)
    jobs.run 'noasync', log: true, -> @report "sync action done with async background job"

  shell: ->
    jobs = createJobs(loadSites())
    jobs.add 'putmsg', 'example.com', ->
      cb = @async()
      logfile = "tmp/#{@id}.log"
      @shared[@site.name] or= {}
      @shared[@site.name].logfile = logfile
      # note: we use the coffee-script binding operator to keep the `this` pointer
      delay = =>
        # pass a completion function to shell so we are sure the file exists subsequently
        @shell.run "mkdir -p tmp && echo hello > #{logfile}", cb
      setTimeout(delay, 400)
    jobs.add 'getmsg', 'example.com', ->
      logfile = @shared[@site.name].logfile
      # we didn't give a callback to shell, so we just return with the job in the background
      @shell.run "echo #{logfile} contains: && cat #{logfile}"
    jobs.run ['putmsg', 'getmsg'], name : "shelltest", log: true, ->
      assert.equal 2, @_ctx.actioncount

  lateshell: ->
    jobs = createJobs(loadSites())
    jobs.add 'latetimeout', 'example.com', ->
      # the shell can start after our action is done
      # just don't use @fail or @async after the fact.
      late = =>
        @shell.run "echo starting shell after action has terminated"
        @report "reporting from undead action"
      setTimeout(late , 100)      
    jobs.run 'latetimeout'
    
  sequential: ->
    jobs = createJobs(loadSites())
    jobs.add 'hello', 'app.example.com', ->
      # batch is a common identifier used in reporting
      # the action id is a counter extension to the batch identifier,
      # unique for this action
      assert.equal 0, @id.indexOf(@batch + "-")
      @report "Testing the reporting\nfacitlity.\nThere can be multiple\nlines."
      # the id is suitable for tmp files unique for this action, across all sites.
      @shell.run "mkdir -p tmp && echo hello > tmp/#{@id}.log"
      # we didn't give a callback to shell, so we just return with the job in the background
      
      # note: we use the coffee-script binding operator to keep the `this` pointer,
      #       and we allocate a callback to delay job completion.
      cb = @async()
      delay = =>
        util.writemap @shared, "greeting", "hello"
        cb()
      setTimeout(delay, 100)
    jobs.add 'world', 'example.com', ->
      util.writemap @shared, "greeting", ", world!"
    jobs.add 'display', 'app.example.com', ->
      @shared.display = true
      msg = "my unique place in the world"
      @report "action identifier: " + @id
      @report "schedule identifier: " + @_sched.id
      @report "schedule type: " + @_sched.type
      assert.equal "sequential", @_sched.type
      assert.equal 0, @id.indexOf(@_sched.id)
      @shared[@id] = { msg }
      assert.equal @_ctx.shared[@id].msg, msg
      assert.equal @_sched.shared[@id].msg, msg
      assert.ok @shared.greeting, "greeting expected"
    complete = (err) ->
      assert.isNull err, "non errors should be null"
      assert.equal @index, 1 # first and only schedule
      assert.equal @type, "sequential"
      @report "final shared state:\n#{JSON.stringify @shared}"
      assert.equal @shared.greeting, "hello, world!", "expected hello world message"
      assert.ok @shared.display, "display task should have been running"
    jobs.runSequential ['hello', 'world', 'display'], { log: true, shared: { greeting: ""} }, complete

  nop: ->
    x = 0
    jobs = createJobs(loadSites())
    jobs.add 'test'
    jobs.run 'test', {log:true, name:"nop"}, ->
      assert.equal x, 0
      assert.equal @_ctx.actioncount, 0

  nearnop: ->
    x = 0
    jobs = createJobs(loadSites())
    # we are relying on the fact that the foo.bar site belongs
    # to the test role and that the job named 'test' assigns itself to
    # the 'test' role - otherwise there would be no site on which
    # to run the test.
    jobs.add 'test', [(-> ++x), (-> ++x)]
    jobs.run 'test', {log:true, name:"nearnop"}, ->
      assert.equal x, 2
      assert.equal @_ctx.actioncount, 2
      
  nops: ->
    jobs = createJobs(loadSites())
    jobs.add 'test'
    jobs.runSequential 'test', log:true, name:"nops"

  par1: ->
    jobs = createJobs(loadSites())
    jobs.add 'par1', 'foo.bar', -> console.log 'par1'
    jobs.runParallel 'par1', log:true, name: 'par1'
      
  mixed: ->

    jobs = createJobs(loadSites())
    assert.ok jobs.sites.get('foo.bar').log
    
    path = (env) -> env.path or "~/tmp"
    complete = (errors) ->
      # node.js convention is to return null when there are no
      # errors.
      if errors
        console.log "jobs completed with #{errors} errors."
      else
        console.log "all jobs completed successfully"
      assert.isNull errors
      assert.ok @shared.checkrunsDone

    # add a job named deploy in the deploy role
    jobs.add 'deploy', ->
      # increment a counter for every site this action fires on
      util.addmap @shared.sitecount, @site.name
      @report @site.name

    # add action to deploy job that only runs in the live role
    jobs.add 'deploy', 'live', ->
      # increment a counter for every site this action fires on
      util.addmap @shared.livecount, @site.name
      @report @site.name

    # add a job named countertest to the test role.
    jobs.add 'countertest', ['test'], ->
      assert.ok @site.log
      util.addmap @shared.sitecount, @site.name

    # add a job named checkruns in the roles 'test' and 'deploy'
    jobs.add 'checkruns', ['test', 'deploy'], ->
      @report "checkruns running"
      @debug "checkruns shared state", @shared
      ++checks
      # only deploy
      assert.equal @shared.sitecount['example.com'], 1
      # test and deploy
      assert.equal @shared.sitecount['foo.bar'], 2
      @shared.checkrunsDone = true
      @report "running in roles #{opts.roles or "<all>"}"

    mkopts = -> { 
      shared: { sitecount: {}, livecount: {} }
      roles: ['test', 'live']
      log: true
      debug: true
    }
    
    checks = 0
    expectchecks = 0
    
    opts = mkopts()
    opts2 = mkopts()
    opts3 = mkopts()
    
    #runs = ['site-seq'] # fails
    runs = ['par', 'seq'] # succeeds
    
    if 'seq' in runs 
      
      # sequential seems to work
      ++expectchecks
      jobs.runSequential ['deploy', 'countertest'], opts, ->
        # only run the global check once, assign it to site foo.bar
        # pass shared state to new schedule via opts.
        opts.roles = 'foo.bar'
        jobs.run 'checkruns', opts, complete    

    if 'site-seq' in runs
      
      # site-sequential messes up what actions to run where
      # or at least messes up logging of the fact
      ++expectchecks
      jobs.runSiteSequential ['deploy', 'countertest'], opts2, ->
        opts2.roles = 'foo.bar'
        jobs.run 'checkruns', opts2, complete    

    if 'par' in runs
      ++expectchecks    
      jobs.runParallel ['deploy', 'countertest'], opts3, ->
        opts3.roles = 'foo.bar'
        jobs.run 'checkruns', opts3, complete
        

    setTimeout((->assert.equal checks, expectchecks, "test failed to run or to complete in time"), 400)
    
    assert.equal runs.length, 3, "disabled some failing tests"

}

if process.env.jobstest
  test = process.env.jobstest

if test
  x = module.exports
  module.exports = { test: -> x[test]() }

