shell = require('..').shell
assert = require('assert')
util = require('..').util

TO = 6000

module.exports = {
  
  rsyncfile: ->
    local = shell(log:true)
    sh = shell("example.com", { log: true });
    assert.equal(sh.options.host, "example.com")
    assert.ok sh.log
    file = 'tmp/hello.test'
    content = util.uid(6);
    upok = false
    downok = false
    local.run "echo #{content} > #{file}", ->
      sh.rsyncup file, file, ->
        sh.run "cat #{file}", (ec, cap) ->
          assert.ok not ec
          assert.equal(cap.out(), "#{content}\n")
          upok = true
          setTimeout (-> assert.ok(downok, "rsyncdown failed to complete in time")), TO
          sh.rsyncdown file, file + "2", ->
            local.run "cat #{file}2", (ec, cap) ->
              assert.equal cap.out(), "#{content}\n"
              downok = not ec
    setTimeout (-> assert.ok(upok, "rsyncup failed to complete in time")), TO

  upload: ->
    
    # prefix a, b for sorting
    a = "a#{util.uid(3)}"
    b = "b#{util.uid(3)}"
    lsout = "#{a}\n#{b}\n"
    
    cmd = [
      "rm -rf tmp/uploads",
      "rm -rf tmp/roundtrip",
      "mkdir -p tmp/uploads",
      "touch tmp/uploads/#{a}",
      "touch tmp/uploads/#{b}"]
      
    local = shell(log:true)
    sh = shell(host: "example.com", log: true);
    upok = false
    downok = false
    
    local.run cmd, ->
      sh.upload "tmp/uploads/", "tmp/uptest", ->
        sh.run "ls tmp/uptest", (ec, cap) ->
          assert.equal cap.out(), lsout
          upok = true
          setTimeout (-> assert.ok(downok, "download failed to complete in time")), TO
          sh.download "tmp/uptest/", "tmp/roundtrip", (ec, cap) ->
            assert.ok not ec
            local.run "ls tmp/roundtrip", (ec, cap) ->
              assert.equal cap.out(), lsout
              downok = true
    setTimeout (-> assert.ok(upok, "upload failed to complete in time")), TO
}

