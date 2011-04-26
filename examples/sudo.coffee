host = require('..').shell(host:"example.com", log:true)

host.run 'ls /var/log', ->
  host.log = true
  host.sudo 'tail /var/log/auth.log', ->
    host.sudo 'head /var/log/auth.log'

# test concurrent password acquisition
host.sudo 'ls ~'

# test sudo detector
host.run 'sudo tail /var/log/auth.log | grep root'

host.promptPassword()

host.setPassword('hello')
