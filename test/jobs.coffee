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
    jobs.add 'deploy', (done) ->
      # increment a counter for every site this action fires on
      util.addmap @shared.sitecount, @site.name
      # important to ensure progress
      done()

    # add action to deploy job that only runs in the live role
    jobs.add 'deploy', 'live', (done) ->
      # increment a counter for every site this action fires on
      util.addmap @shared.livecount, @site.name
      # important to ensure progress
      done()

    # add a job named countertest to the test role.
    jobs.add 'countertest', ['test'], (done) ->
      assert.ok @site.log
      util.addmap @shared.sitecount, @site.name
      done()

    # add a job named checkruns in the roles 'test' and 'deploy'
    jobs.add 'checkruns', ['test', 'deploy'], (done) ->
      # only deploy
      assert.equal @shared.sitecount['example.com'], 1
      # test and deploy
      assert.equal @shared.sitecount['foo.bar'], 2
      @shared.checkrunsDone = true
      done()

    # these are job names, not roles
    opts.roles = ['test', 'live']
    jobs.runParallel ['deploy', 'countertest'], opts, ->
      jobs.run 'checkruns', opts, complete

    forcedError: ->
      assert.ok false, "we know errors don't propagate correctly to the end in the jobs test, fix this"

    notnow: ->
      return
      jobs = createJobs(loadSites())
      # we could play around with action.shell.run "ls ~", done
      # that requires a live host etc., so we don't actually run
      # this job. 
      jobs.add 'touch-hello', 'not-now', (done) ->
        sh = action.shell
        env = action.site
        sh.run ["mkdir -p #{path(env)}", "touch ~/hello-#{env.name}"], ->
          sh.run "ls -l ~/hello", done    

  sudoshell: ->
    jobs = createJobs(loadSites())
    jobs.add 'hello', 'app.example.com', (exit) ->
      @report "sudoing for ls"
      @shell.sudo "ls", (err) ->
        @report err if err
        exit err
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

  shell: ->
    jobs = createJobs(loadSites())
    jobs.add 'putmsg', 'example.com', (done) ->
      
      # note: we use the coffee-script binding operator to keep the `this` pointer
      delay = =>
        # pass done to shell so we are sure the file exists subsequently
        @shell.run "mkdir -p tmp && echo hello > tmp/#{@id}.log", done()
      setTimeout(delay, 400)
    jobs.add 'getmsg', 'example.com', (done) ->
        # we didn't give a callback to shell, so we just return with the job in the background
        @shell.run "echo tmp/#{@id}"
        done()
    jobs.run ['putmsg', 'getmsg'], name : "shelltest", log: true, ->
      assert.equal 2, @_ctx.actioncount
    
  sequential: ->
    jobs = createJobs(loadSites())
    jobs.add 'hello', 'app.example.com', (done) ->
      # batch is a common identifier used in reporting
      # the action id is a counter extension to the batch identifier,
      # unique for this action
      assert.equal 0, @id.indexOf(@batch + "-")
      @report "Testing the reporting\nfacitlity.\nThere can be multiple\nlines."
      # the id is suitable for tmp files unique for this action, across all sites.
      @shell.run "mkdir -p tmp && echo hello > tmp/#{@id}.log"
      # we didn't give a callback to shell, so we just return with the job in the background
      
      # note: we use the coffee-script binding operator to keep the `this` pointer
      delay = =>
        util.writemap @shared, "greeting", "hello"
        done()
      setTimeout(delay, 100)
    jobs.add 'world', 'example.com', (done) ->
      util.writemap @shared, "greeting", ", world!"
      done()
    jobs.add 'display', 'app.example.com', (done) ->
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
      done()
    complete = (err) ->
      assert.isNull err, "non errors should be null"
      assert.equal @index, 1 # first and only schedule
      assert.equal @type, "sequential"
      @report "final shared state:\n#{JSON.stringify @shared}"
      assert.equal @shared.greeting, "hello, world!", "expected hello world message"
      assert.ok @shared.display, "display task should have been running"
    jobs.runSequential ['hello', 'world', 'display'], { log: true, shared: { greeting: ""} }, complete
}
