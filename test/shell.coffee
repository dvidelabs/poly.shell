assert = require 'assert'
fs = require 'fs'
shell = require('..').shell

module.exports = {
  redirectedShell: ->
    
    pending = 2
    outfile = "#{__dirname}/../tmp/redirected-shell.out"
    logfile = "#{__dirname}/../tmp/redirected-shell.log"
    
    fs.unlinkSync outfile
    fs.unlinkSync logfile
    
    outStream = fs.createWriteStream(outfile, flag: 'w')
    logStream = fs.createWriteStream(logfile, flag: 'w')
    
    runShell = ->
      return unless outStream.fd and logStream.fd
      sh = shell {outStream, logStream, log: true}
      console.log "redirecting output to #{outfile}"
      sh.run "echo hello, world!", ->
        outStream.destroy()
        result = fs.readFileSync outfile
        assert.equal result.toString(), "hello, world!\n"
        console.log "reading log output:\n#{fs.readFileSync logfile}"
    
    outStream.on 'open', runShell
    logStream.on 'open', runShell
}
