assert = require('assert')
createJobs = require('..').jobs
util = require('..').util

createSites = require('..').envs

console.log "=> jobs test"

loadSites = ->
  sites = createSites()
  
  # add two example sites in the deploy role; both with the property symlink = true
  sites.add ['example.com', 'app.example.com'], 'deploy', { symlink: true }
  
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
    
  jobs: ->
    jobs = createJobs(loadSites())
    assert.ok jobs.sites.get('foo.bar').log
        
    context = { sitecount: {}, log: true }
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
  
    # add job named deploy in the deploy role
    jobs.add 'deploy', (action, done) ->
      
      # increment a counter for every site this action fires on
      util.addmap action.ctx.sitecount, action.site.name
      # important to ensure progress
      done()
    
    # add job named countertest to the test role.
    jobs.add 'countertest', ['test'], (action, done) ->
      console.log action.job
      assert.ok action.site.log
      util.addmap action.ctx.sitecount, action.site.name
      done()
    
    # add the job named checkruns in the roles 'test' and 'deploy'
    jobs.add 'checkruns', ['test', 'deploy'], (action, done) ->
      console.log action.job
      ctx = action.ctx
      # only deploy
      assert.equal ctx.sitecount['example.com'], 1
      # test and deploy
      assert.equal ctx.sitecount['foo.bar'], 2
      ctx.checkrunsDone = true

    # these are job names, not roles
    jobs.runParallel ['deploy', 'countertest'], context, ->
      jobs.run 'checkruns', context, complete
          
  notnow: ->
    jobs = createJobs(loadSites())

    # we could play around with action.shell.run "ls ~", done
    # that requires a live host etc., so we don't actually run
    # this job. 
    jobs.add 'touch-hello', 'not-now', (action, done) ->
      sh = action.shell
      env = action.site
      sh.run ["mkdir -p #{path(env)}", "touch ~/hello-#{env.name}"], ->
        sh.run "ls -l ~/hello", done

    
}

