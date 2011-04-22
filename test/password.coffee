assert = require('assert')
password = require('..').password

module.exports = {
  'password agent': ->
    pwa = password.agent()
    pwa2 = password.agent(pwa.cache)

    pwa.setPassword('hello')
    assert.equal pwa.cache.get(), 'hello'
    assert.equal pwa2.cache.get(), 'hello'

    pwa.getPassword (err, password) ->
      assert.equal err, null
      assert.equal(password, 'hello')
      pwa.reset() unless err
      assert.equal pwa.cache.get(), 'hello'  
      assert.equal pwa2.cache.get(), 'hello'
      pwa2.getPassword (err, password) ->
        assert.equal(password, 'hello') 
}
