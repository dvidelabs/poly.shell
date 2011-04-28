assert = require 'assert'
fs = require 'fs'
shell = require('..').shell

module.exports = {
  redirectedShell: ->
    base = "#{__dirname}/../tmp/"
    outfile = "#{base}sudoredirected-shell.out"
    logfile = "#{base}sudoredirected-shell.log"

    try
      fs.unlinkSync outfile
    catch err
    try
      fs.unlinkSync logfile
    catch err
    
    outStream = fs.createWriteStream(outfile, flag: 'w')
    logStream = fs.createWriteStream(logfile, flag: 'w')
    
    runShell = ->
      return unless outStream.fd and logStream.fd
      sh = shell { outStream, logStream, log: true }
      console.log "redirecting output to #{outfile}"
      sh.run "echo hello, world!", ->
        outStream.destroy()
        logStream.destroy()
        result = fs.readFileSync outfile
        assert.equal result.toString(), "hello, world!\n"
        console.log "reading log output:\n#{fs.readFileSync logfile}"
    shell().run [
      "mkdir -p #{base}"
      "rm -f #{outfile} #{logfile}"], ->

        outStream = fs.createWriteStream(outfile, flag: 'w')
        logStream = fs.createWriteStream(logfile, flag: 'w')
        outStream.on 'open', runShell
        logStream.on 'open', runShell
}
