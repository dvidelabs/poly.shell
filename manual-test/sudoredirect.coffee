assert = require 'assert'
fs = require 'fs'
shell = require('..').shell

base = "#{__dirname}/../tmp/"
outfile = "#{base}sudoredirected-shell.out"
logfile = "#{base}sudoredirected-shell.log"

outStream = logStream = null
host = "example.com"
log = true
runShell = ->
  return unless outStream.fd and logStream.fd
  sh = shell { host, outStream, logStream, log }
  console.log "redirecting output to #{outfile}"
  sh.run "echo hello, world!", ->
    result = fs.readFileSync outfile
    assert.equal result.toString(), "hello, world!\n"
    sh.sudo "ls ~", ->
      console.log "reading output from host #{host}:\n#{fs.readFileSync outfile}"
      console.log "reading log output:\n#{fs.readFileSync logfile}"

shell().run [
  "mkdir -p #{base}"
  "rm -f #{outfile} #{logfile}"], ->

    outStream = fs.createWriteStream(outfile, flag: 'w')
    logStream = fs.createWriteStream(logfile, flag: 'w')
    outStream.on 'open', runShell
    logStream.on 'open', runShell


