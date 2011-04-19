# note: setup example.com to some useful server in .ssh/config

host = require('../ploy').shell(host:"example.com", log:true)

host.run 'ls', ->
  host.log = false
  host.sudo 'ls'

#host.run 'sudo -p Password: ls'

