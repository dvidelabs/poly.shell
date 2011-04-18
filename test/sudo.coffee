# note: setup example.com to some useful server in .ssh/config

host = require('../ploy').shell(host:"example.com", log:true)


host.run 'ls'

#host.run 'sudo -p Password: ls'

host.sudo 'ls', ->
  @log = false
  console.log "sudo ls once more without logging:"
  @sudo 'ls'
