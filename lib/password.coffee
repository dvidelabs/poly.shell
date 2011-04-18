stdio = process.binding("stdio")

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

exports.readSilentLine = readSilentLine
exports.silentPrompt = silentPrompt
exports.askPassword = askPassword
exports.askPasswordTwice = askPasswordTwice
