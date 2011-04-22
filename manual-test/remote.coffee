assert = require 'assert'
shell = require('..').shell

# note: setup example.com to some useful server in .ssh/config


host = shell("example.com")
console.log "testing password prompt, just type anything"
host.promptPassword ->

  shell("example.com").run 'ls'

  host.run 'ls -al', -> console.log "done"

  console.log "operating on system #{host.name}"

  host.run 'bad-command'

  host.spawn 'ls', ['.']

  host.setPassword('hello')
  assert.equal host.passwordCache.get(), 'hello'
  host.resetPassword()
  assert.equal host.passwordCache.get(), null

