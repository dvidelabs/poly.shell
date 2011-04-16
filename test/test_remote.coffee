run_remote = require('../ploy').run_remote

console.log 'NOTE: test requires .ssh/config configured with example.com host and user'

host = 'example.com'

run_remote host, 'ls'
run_remote "example.com", 'ls', ['.'], (code) -> console.log "failed" if code != 0
run_remote "foo@example.com:2200", 'ls'
run_remote {host: "example.com", user:"foo", port:"2200"}, 'ls'

run_remote host, 'bad-command'