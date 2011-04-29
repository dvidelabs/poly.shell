assert = require 'assert'
fs = require 'fs'
shell = require('..').shell

module.exports = {
  captureShell: ->
    sh = shell()
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello, world!\n", capture()
      
  capturehighLimitShell: ->
    sh = shell(captureLimit: 100)
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello, world!\n", capture()
      
  captureLimitShell: ->
    sh = shell(captureLimit: 5)
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello", capture()

  captureLimit0Shell: ->
    # this actually disables capturing, but shouldn't break our interface
    sh = shell(captureLimit: 0)
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "", capture()
    
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
        # timeout is a hack, but otherwise we have to listen for a kernel flush
        # event of the outStream - without timeout the test generally passes
        # in isolation, but not always running async with many other tests
        # the timeout should fix that.
        setTimeout((->
          result = fs.readFileSync outfile
          assert.equal result.toString(), "hello, world!\n"
          console.log "reading log output:\n#{fs.readFileSync logfile}"
          ), 100);
    shell().run [
      "mkdir -p #{base}"
      "rm -f #{outfile} #{logfile}"], ->

        outStream = fs.createWriteStream(outfile, flag: 'w')
        logStream = fs.createWriteStream(logfile, flag: 'w')
        outStream.on 'open', runShell
        logStream.on 'open', runShell
}
