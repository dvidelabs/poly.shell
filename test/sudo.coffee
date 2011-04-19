# note: setup example.com to some useful server in .ssh/config

# on some systems, sudo is rembembered across ssh sudo calls (Ubuntu 10.04)
# on others (Debian Squeeze), password must be reentered for new connections
# the shell contains a password agent to alleviate this problem
# hence we should enter the sudo password at most once in the following
# (timing issues may prevent this from working though)

host = require('../ploy').shell(host:"example.com", log:true)

host.run 'ls /var/log', ->
  host.log = true
  host.sudo 'tail /var/log/auth.log', ->
    host.sudo 'head /var/log/auth.log'

#host.run 'sudo -p Password: ls'

