assert = require 'assert'
fs = require 'fs'
shell = require('..').shell

module.exports = {
  captureShell: ->
    sh = shell()
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello, world!\n", capture.out()
      
  captureSilentShell: ->
    outbuf = null
    sh = shell(silent:true, outStream: { 
      write: (data) -> outbuf = data })
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello, world!\n", capture.out()
      assert.equal null, outbuf

  captureNonSilentShell: ->
    outbuf = null
    sh = shell(outStream: { 
      write: (data) -> outbuf = data })
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello, world!\n", capture.out()
      assert.equal "hello, world!\n", outbuf
    
  capturehighLimitShell: ->
    sh = shell(captureLimit: 100)
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello, world!\n", capture.out()
      
  captureLimitShell: ->
    sh = shell(captureLimit: 5)
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "hello", capture.out()

  captureLimit0Shell: ->
    sh = shell(captureLimit: 0)
    sh.run "echo hello, world!", (ec, capture) ->
      assert.equal "", capture.out()

  captureErrShell: ->
    outbuf = null
    errbuf = null
    sh = shell({
      # technically there can be multiple writes, but not with
      # such small amounts of data
      outStream: { write: (data) -> outbuf = data }
      errStream: { write: (data) -> errbuf = data }
    })
    sh.run "echo hello, world! 1>&2", (ec, capture) ->
      assert.equal "", capture.out()
      # we might get a zero length buffer or nothing
      assert.ok outbuf == "" or outbuf == null
      assert.equal "hello, world!\n", capture.err()
      assert.equal "hello, world!\n", errbuf

  captureNonErrShell: ->
    sh = shell()
    sh.run "echo hello, world! 2>&1", (ec, capture) ->
      assert.equal "hello, world!\n", capture.out()
      assert.equal "", capture.err()
  
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
