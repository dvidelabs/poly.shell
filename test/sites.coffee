# run with expresso

assert = require 'assert'
_ = require('../lib/util')._

createSites = require('../lib/sites').createSites

eqlSet = (x, y) ->
  return false if x.length != y.length
  h = {}
  for v in x
    h[v] = true
  for v in y
    return false unless h[v]
  return true

assert.eqlSet = (x, y) -> assert.ok eqlSet x, y
   
module.exports = {
  trival: ->
    console.log "testing the test"
    assert.eqlSet [1,2], [2,1]

  add: ->
    sites = createSites()
    sites.add 'www.example.com'
    assert.eql sites.config('www.example.com'), { site: 'www.example.com' }
    result = sites.inRoles('www.example.com')
    assert.eql result, ['www.example.com']
    
    # site config cannot be overriden
    sites.add 'host1', null, { site: 'x1', xsite: 'x1' }
    assert.equal 'host1', sites.config('host1').site
    assert.equal 'x1', sites.config('host1').xsite
    
    sites.add 'host2', [], { xsite: 'x2' }
    assert.eql { site: 'host2', xsite: 'x2' }, sites.config('host2') 

    sites.add 'host3', { xsite: 'x3' }
    assert.eql { site: 'host3', xsite: 'x3' }, sites.config('host3') 

  config: ->
    sites = createSites()
    sites.add ['www1', 'www2'], { live: true}
    assert.ok sites.config('www1').live
    assert.ok sites.config('www2').live

    # return config is a copy
    sites.config('www1').live = false
    assert.ok sites.config('www1').live
    assert.ok sites.config('www2').live


    sites.update ['www1', 'www2', 'www3'], { live: false }
    assert.ok not sites.config('www1').live
    assert.ok not sites.config('www2').live
    assert.isNull sites.config('www3')

  roles: ->
    sites = createSites()
    sites.add ['x', 'y'], ['www', 'db', 'app'], { testpath: 'test' }
    sites.update 'x', 'beta'
    betaSites = sites.inRoles 'beta'
    assert.eqlSet betaSites, ['x']
    wwwSites = sites.inRoles 'www'
    assert.eqlSet wwwSites, ['x', 'y']
    assert.eqlSet betaSites, sites.inRoles('www', 'beta')

    # `k` is a role, not a real site, so `beta` role doesn't change
    sites.update 'k', 'beta'
    assert.eqlSet betaSites, sites.inRoles('www', 'beta')

    # now `k` becomes a real site and updates `beta` role
    sites.add 'k', 'beta'
    assert.eqlSet ['x', 'k'], sites.inRoles('beta')

    set = sites.inRoles 'www', 'beta'
    console.log eqlSet(sites.inRoles('beta'), set)
    assert.ok not eqlSet(sites.inRoles('beta'), set)
    assert.eqlSet ['x'], set

  update: ->
    sites = createSites()
    sites.add ['x', 'y'], ['www', 'db', 'app'], { testpath: 'test' }
    sites.update 'x', { msg: 'hello' }
    assert.eql { site: 'x', msg: 'hello', testpath: 'test'}, sites.config('x')
    
    sites.update 'x', { msg: 'world' }
    assert.eql { site: 'x', msg: 'world', testpath: 'test'}, sites.config('x')

    sites.update 'x', { module: { a: 1, b: 2} }
    assert.eql {
      site: 'x', msg: 'world', testpath: 'test',
      module: { a: 1, b: 2 }}, sites.config('x')

    # recursive extend replaces embedded object
    sites.update 'x', { module: { c: 3} }
    assert.eql {
      site: 'x', msg: 'world', testpath: 'test',
      module: { c: 3 }}, sites.config('x')

}