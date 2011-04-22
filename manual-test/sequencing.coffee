# note: configure example.com in .ssh/config

shell = require('..').shell

eh = (ec) -> if ec then console.log "#{this.name} failed"

ex = shell(host: 'example.com', log: true)

next = -> ex.spawn "touch", ["~/tmp/test/a\\ space"], ->
  @run "ls tmp/test", ->
    @run "rm -rf ~/tmp/test"

ex.run ["mkdir -p ~/tmp/", "mkdir -p ~/tmp/test", "ls tmp/test"], next

