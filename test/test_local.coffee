ploy = require('../ploy')
local = ploy.shell({name: "onsite", log:true})

console.log local
console.log local.name

local.run 'echo hello'  
local.run 'echo world'

# foo bar runs in sequence, little elf runs concurrently with foo bar
local.run(['echo foo', 'echo bar']).run('echo little elf')
local.spawn 'sh', ['-c', 'ls .']

local.run 'bad-command', (ec) -> if ec then console.log "#{this.name} failed with code #{ec}"

reportShell = (sh) -> sh.run 'echo $SHELL'
reportShell ploy.shell(sh: '/bin/bash')
reportShell ploy.shell(sh: 'sh')
reportShell ploy.shell()
