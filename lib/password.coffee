stdio = process.binding("stdio")
util = require './util'
EventEmitter = require('events').EventEmitter

# inspired by npm prompt.js
readSilentLine = (cb = ->) ->
  unless cb
    cb = (err, line) ->
      if err == 'SIGINT'
        process.kill process.pid, 'SIGINT'
    
  stdin = process.openStdin()
  stdio.setRawMode(true)
  line = ""
  stdin.resume()
  stdin.on("error", cb)
  stdin.on "data", (data) ->
    data = data + ""
    pos = data.search /\n|\r|\u0004/
    if pos >= 0
      process.stdout.write "\n"
      process.stdout.flush()
      line += data.slice(0, pos)
      stdin.removeListener("data", arguments.callee)
      stdin.removeListener("error", cb)      
      stdio.setRawMode(false)
      stdin.pause()
      cb null, line
    else if /\u0003/.test data
      cb 'SIGINT'
    else
      line += data

silentPrompt = (msg, cb) ->
  process.stdout.write(msg, null, readSilentLine(cb))

askPassword = (prompt, cb) ->
  if typeof prompt == 'function'
    cb = prompt
    prompt = null
  prompt ?= "Password:"
  silentPrompt prompt, cb

askPasswordTwice = (prompt, prompt2, cb) ->
  if typeof prompt2 == 'function'
    cb = prompt2
    prompt2 = undefined
  if typeof prompt == 'function'
    cb = prompt
    prompt = undefined
    prompt2 = undefined
  prompt ?= "Password:"
  prompt2 ?= "Again, please:"  
  silentPrompt prompt, (err, password) ->
    cb err if err
    silentPrompt prompt2, (err, password2) ->
      cb err if err
      if password != password2
        cb "password-mismatch"
      else
        cb null, password


class PasswordCache extends EventEmitter
  constructor: ->
    @password = null
    @pending = null
  reset: ->
    @password = null
    @emit 'password', 'password-reset', null
  get: -> return @password
  set: (@password) ->
    @emit 'password', null, @password
  setPending: (@pending = true) ->
  isPending: () -> @pending

# An agent should only be used for one password session
# or reset bewteen sessions (this does not clear password cache)
class PasswordAgent
  constructor: (@cache = new PasswordCache()) ->
    @maxAttempts = 5
    @reset()

  reset: ->
    @attempts = 0
    @prompt = util.uid(6) + ":Password:"
  resetCache: ->
    @cache.reset()
  setPassword: (pw) ->
    @cache.set(pw)
    console.log "setting password"
  getPassword: (cb = ->) ->
    @attempts++
    pw = @cache.get()
    if @attempts == 1 and pw
      console.log "using cached password"
      cb(null, pw)
    else if @attempts > @maxAttempts
      cb "giving up on password after #{@maxAttempts} attempts"
    else
      if @cache.isPending()
        console.log "waiting for password entry in other process"
        @cache.once('password', cb)
      else
        _cb = (err, pw) =>
          @cache.setPending(false)
          @setPassword pw unless err
          cb err, pw
        @cache.setPending(true)
        readSilentLine _cb

helpers = {}
helpers.readSilentLine = readSilentLine
helpers.silentPrompt = silentPrompt
helpers.askPassword = askPassword
helpers.askPasswordTwice = askPasswordTwice
exports.helpers = helpers
exports.cache = (cache) -> new PasswordCache()
exports.agent = (cache) -> new PasswordAgent(cache)
