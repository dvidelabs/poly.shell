assert = require 'assert'
pw = require '../lib/password'

pw.askPasswordTwice (err, password) ->
  if err == "mismatch"
    console.log "password not accepted"
  else if err == 'SIGINT'
    process.kill process.pid
  else if err
    console.log "failed to read password: #{err.toString()}"
  else
    console.log "password accepted"
    console.log "first password was '#{password}'"
    pw.askPassword("Next password:", (err, password2) -> console.log "last password was '#{password2}'" unless err)

pwa = pw.agent()
pwa2 = pw.agent(pwa)

pwa.setPassword('hello')
assert.equal pwa.getCachedPassword(), 'hello'

pwa.getPassword (err, password) ->
  assert.equal(password, 'hello')
  unless err
    pwa.resetAttempts()
  
  assert.equal pwa2.getCachedPassword(), 'hello'

  pwa2.getPassword (err, password) ->
    assert.equal(password, 'hello')