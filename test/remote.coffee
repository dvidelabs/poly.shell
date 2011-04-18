shell = require('../ploy').shell

# note: setup example.com to some useful server in .ssh/config

shell("example.com").run 'ls'

host = shell("example.com")
host.run 'ls -al', -> console.log "done"

console.log "operating on system #{host.name}"

eh = (ec) -> if ec then console.log "#{this.name} failed"

shell({host: "example.com", user: "foo", port:2200}).run "ls", eh

host.run 'bad-command'

host.spawn 'ls', ['.']
