shell = require('../ploy').shell

# note: setup example.com to some useful server in .ssh/config

shell("example.com").run 'ls'

host = shell("example.com")
host.run 'ls -al', -> console.log "done"

console.log "operating on system #{host.name}"

host.run 'bad-command'

host.spawn 'ls', ['.']

