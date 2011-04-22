shell = require('../../ploy').shell

# connection timeout eventualy
eh = (ec) -> if ec then console.log "#{this.name} failed"

shell({host: "example.com", user: "foo", port:2200}).run "ls", eh

