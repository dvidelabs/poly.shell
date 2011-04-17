shell = require('../ploy').shell

# note: setup example.com to some useful server in .ssh/config
host = 'example.com'

shell(host).run 'ls'

sh1 = shell(host).run 'ls -al', -> console.log "done"
console.log "operating on system #{sh1.name}"
eh = (ec) -> if ec then console.log "#{this.name} failed"

# remote spawn fails
#shell("example.com").spawn "ls", ["."], eh

shell({host: "example.com", user: "foo", port:2200}).run "ls", eh

shell(host).run 'bad-command'
