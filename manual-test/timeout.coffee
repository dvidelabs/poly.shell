shell = require('..').shell

console.log "waiting for connection to timeout - ctrl+c if impatient"
eh = (ec) -> if ec then console.log "#{this.name} failed"

shell({host: "example.com", user: "foo", port:2200}).run "ls", eh

