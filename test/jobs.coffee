assert = require('assert')
createJobs = require('..').jobs
util = require('..').util

createSites = require('..').envs

console.log "=> jobs test"

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

  trivial: ->
    assert.equal 2+2, 4

  sites: ->
    sites = loadSites()
    assert.ok util.eqSet(sites.list('test'), ['foo.bar'])
    assert.ok util.eqlSet(sites.list(['test', 'deploy']), ['foo.bar', 'example.com', 'app.example.com'])
    assert.ok sites.get('foo.bar').log
    jobs = createJobs(sites)

  jobs: ->
    jobs = createJobs(loadSites())
    assert.ok jobs.sites.get('foo.bar').log

    context = { sitecount: {}, livecount: {}, log: true }
    path = (env) -> env.path or "~/tmp"
    complete = (errors) ->
      # node.js convention is to return null when there are no
      # errors.
      if errors
        console.log "jobs completed with #{errors} errors."
      else
        console.log "all jobs completed successfully"
      assert.isNull errors
      console.log "context: "
      console.log context
      assert.ok context.checkrunsDone

    # add a job named deploy in the deploy role
    jobs.add 'deploy', (done) ->
      # increment a counter for every site this action fires on
      util.addmap @ctx.sitecount, @site.name
      # important to ensure progress
      done()

    # add action to deploy job that only runs in the live role
    jobs.add 'deploy', 'live', (done) ->
      # increment a counter for every site this action fires on
      util.addmap @ctx.livecount, @site.name
      # important to ensure progress
      done()

    # add a job named countertest to the test role.
    jobs.add 'countertest', ['test'], (done) ->
      assert.ok @site.log
      util.addmap @ctx.sitecount, @site.name
      done()

    # add a job named checkruns in the roles 'test' and 'deploy'
    jobs.add 'checkruns', ['test', 'deploy'], (done) ->
      # only deploy
      assert.equal @ctx.sitecount['example.com'], 1
      # test and deploy
      assert.equal @ctx.sitecount['foo.bar'], 2
      @ctx.checkrunsDone = true
      done()

    # these are job names, not roles
    context.roles = ['test', 'live']
    jobs.runParallel ['deploy', 'countertest'], context, ->
      jobs.run 'checkruns', context, complete

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
}


module.exports = {

  sequential: ->
    jobs = createJobs(loadSites())
    jobs.add 'hello', 'app.example.com', (done) ->
      delay = ->
        util.writemap @ctx, "greeting", "hello"
        done()
      setTimeout(delay, 100)
    jobs.add 'world', 'example.com', (done) ->
      util.writemap @ctx, "greeting", ", world!"
      done()
    jobs.add 'display', 'app.example.com', (done) ->
      assert.ok @ctx.greeting, "greeting expected"
      console.log @ctx.greeting
      @ctx.display = true
      done()
    complete = (err) ->
      assert.isNull err, "non errors should be null"
      assert.equal @ctx.greeting, "hello, world!", "expected hello world message"
      assert.ok @ctx.display, "display task should have been running"
    jobs.runSequential ['hello', 'world', 'display'], { log: true, greeting: "" }, complete

}
