shell = require('..').shell
assert = require('assert')
util = require('..').util

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
          setTimeout (-> assert.ok(downok, "rsyncdown failed to complete in time")), 5000
          
          sh.rsyncdown file, file + "2", ->
            local.run "cat #{file}2", (ec, cap) ->
              assert.equal cap.out(), "#{content}\n"
              downok = not ec
    setTimeout (-> assert.ok(upok, "rsyncup failed to complete in time")), 5000
    
    upload: ->
      return 
      local = shell(log:true)
      sh = shell(host: "example.com", log: true);
    
}