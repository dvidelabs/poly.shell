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

inactive = {

  jobs: ->
    jobs = createJobs(loadSites())
    assert.ok jobs.sites.get('foo.bar').log

    shared = { sitecount: {}, livecount: {} }
    opts = { log: true, shared }
    
    path = (env) -> env.path or "~/tmp"
    complete = (errors) ->
      # node.js convention is to return null when there are no
      # errors.
      if errors
        console.log "jobs completed with #{errors} errors."
      else
        console.log "all jobs completed successfully"
      assert.isNull errors
      assert.ok shared.checkrunsDone

    # add a job named deploy in the deploy role
    jobs.add 'deploy', ->
      # increment a counter for every site this action fires on
      util.addmap @shared.sitecount, @site.name
      # important to ensure progress

    # add action to deploy job that only runs in the live role
    jobs.add 'deploy', 'live', ->
      # increment a counter for every site this action fires on
      util.addmap @shared.livecount, @site.name
      # important to ensure progress

    # add a job named countertest to the test role.
    jobs.add 'countertest', ['test'], ->
      assert.ok @site.log
      util.addmap @shared.sitecount, @site.name

    # add a job named checkruns in the roles 'test' and 'deploy'
    jobs.add 'checkruns', ['test', 'deploy'], ->
      # only deploy
      assert.equal @shared.sitecount['example.com'], 1
      # test and deploy
      assert.equal @shared.sitecount['foo.bar'], 2
      @shared.checkrunsDone = true

    # these are job names, not roles
    opts.roles = ['test', 'live']
    jobs.runParallel ['deploy', 'countertest'], opts, ->
      jobs.run 'checkruns', opts, complete

}

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
    jobs.add 'sync', 'example.com', ->
      @report "sync running"
    jobs.run 'sync', log: true, -> @report "sync done"

  syncnofail: ->
    jobs = createJobs(loadSites())
    jobs.add 'syncnofail', 'example.com', ->
      err = null
      @report "sync running"
      @fail err
    jobs.run 'syncnofail', log: true, -> @report "sync done"
    
  syncfail: ->
    jobs = createJobs(loadSites())
    jobs.add 'syncfail', 'example.com', ->
      @fail "testing sync failure"
      @fail "can fail multiple times, if we so desire"
      @report "sync running with expected errors"
    jobs.run 'syncfail', log: true, -> @report "sync done"
    
  async: ->
    jobs = createJobs(loadSites())
    jobs.add 'async', 'example.com', ->
       # don't call async inside the timeout
       # then our action will have completed prematurely
       cb1 = @async()
       cb2 = @async()
       that = this
       setTimeout((that.report "timeout 1"; cb1()), 10)
       setTimeout((that.report "timeout 2"; cb2()), 20)
    jobs.run 'async', log: true, -> @report "async done"

  asyncfail: ->
    jobs = createJobs(loadSites())
    jobs.add 'asyncfail', 'example.com', ->
       # each callback may receive an error
       cb1 = @async()
       cb2 = @async()
       # we may use coffee-script binding instead of that
       setTimeout((=> @report "timeout 1"; cb1()), 10)
       setTimeout((=> @report "timeout 2"; cb2 "something bad happened"), 20)
    jobs.run 'asyncfail', log: true, -> @report "async done with expected error"

  noasync: ->
    jobs = createJobs(loadSites())
    jobs.add 'noasync', 'example.com', ->
       setTimeout((-> @report "timeout"), 10)
    jobs.run 'noasync', log: true, -> @report "sync action done with async background job"

  shell: ->
    jobs = createJobs(loadSites())
    jobs.add 'putmsg', 'example.com', ->
      cb = @async()
      # note: we use the coffee-script binding operator to keep the `this` pointer
      delay = =>
        # pass a completion function to shell so we are sure the file exists subsequently
        @shell.run "mkdir -p tmp && echo hello > tmp/#{@id}.log", cb
      setTimeout(delay, 400)
    jobs.add 'getmsg', 'example.com', ->
        # we didn't give a callback to shell, so we just return with the job in the background
        @shell.run "echo tmp/#{@id}"
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
}
