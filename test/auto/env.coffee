# run with expresso

assert = require 'assert'
_ = require('../../lib/util')._

# here we assume a model where each deployment site is an environment

createSites = require('../../lib/env').create

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
    assert.eql sites.get('www.example.com'), { name: 'www.example.com' }
    result = sites.list('www.example.com')
    assert.eql result, ['www.example.com']
    
    # name property cannot be overriden
    sites.add 'host1', null, { name: 'x1', site: 'x1' }
    assert.equal 'host1', sites.get('host1').name
    assert.equal 'x1', sites.get('host1').site
    
    sites.add 'host2', [], { site: 'x2' }
    assert.eql { name: 'host2', site: 'x2' }, sites.get('host2') 

    sites.add 'host3', { site: 'x3' }
    assert.eql { name: 'host3', site: 'x3' }, sites.get('host3') 

  get: ->
    sites = createSites()
    sites.add ['www1', 'www2'], { live: true}
    assert.ok sites.get('www1').live
    assert.ok sites.get('www2').live

    # returned environment is a copy
    sites.get('www1').live = false
    assert.ok sites.get('www1').live
    assert.ok sites.get('www2').live


    sites.update ['www1', 'www2', 'www3'], { live: false }
    assert.ok not sites.get('www1').live
    assert.ok not sites.get('www2').live
    assert.isNull sites.get('www3')

  list: ->
    sites = createSites()
    sites.add ['x', 'y'], ['www', 'db', 'app'], { testpath: 'test' }
    sites.update 'x', 'beta'
    betaSites = sites.list 'beta'
    assert.eqlSet betaSites, ['x']
    wwwSites = sites.list 'www'
    assert.eqlSet wwwSites, ['x', 'y']
    assert.eqlSet betaSites, sites.list('www', 'beta')

    # `k` is a role, not a real site, so `beta` role doesn't change
    sites.update 'k', 'beta'
    assert.eqlSet betaSites, sites.list('www', 'beta')

    # now `k` becomes a real site and updates `beta` role
    sites.add 'k', 'beta'
    assert.eqlSet ['x', 'k'], sites.list('beta')

    set = sites.list 'www', 'beta'
    console.log eqlSet(sites.list('beta'), set)
    assert.ok not eqlSet(sites.list('beta'), set)
    assert.eqlSet ['x'], set

  update: ->
    sites = createSites()
    sites.add ['x', 'y'], ['www', 'db', 'app'], { testpath: 'test' }
    sites.update 'x', { msg: 'hello' }
    assert.eql { name: 'x', msg: 'hello', testpath: 'test'}, sites.get('x')
    
    sites.update 'x', { msg: 'world' }
    assert.eql { name: 'x', msg: 'world', testpath: 'test'}, sites.get('x')

    sites.update 'x', { module: { a: 1, b: 2} }
    assert.eql {
      name: 'x', msg: 'world', testpath: 'test',
      module: { a: 1, b: 2 }}, sites.get('x')

    # recursive extend replaces embedded object
    sites.update 'x', { module: { c: 3} }
    assert.eql {
      name: 'x', msg: 'world', testpath: 'test',
      module: { c: 3 }}, sites.get('x')

}