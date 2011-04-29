cpspawn = require('child_process').spawn
password = require './password'
util = require './util'

# TODO:
# Change current working directory of shell
# if the configuration holds a path settings.

spawn = (cmd, args, opts, cb) ->
  args = [] unless args
  opts = {} unless opts
  name = opts.issuer or opts.name or ""
  if typeof args == 'function'
      cb = args
      args = []
  else if typeof opts == 'function'
      cb = opts
      opts = {}
  capture = []
  capsize = 0
  caplimit = opts.captureLimit or 0
  readcapture = ->
    s = ""
    for buf in capture
      s += buf.toString()
    return s
  # capture buffers, but don't convert them unless the user actually wants them
  addcapture = (buf) ->
    return if capsize == caplimit
    if buf.length + capsize < caplimit
      capture.push buf
    else
      capture.push buf.slice 0, caplimit - capsize 
  child = cpspawn cmd, args
  pwa = opts.passwordAgent
  if opts.silent
    out = { write: -> }
  else
    out = opts.outStream or process.stdout
  logout = opts.logStream or process.stdout
  log = (buffer) ->
    return unless opts.log
    logout.write buffer + '\n'
    logout.flush()

  log "#{name} : #{cmd} #{args.join(' ')}"
  child.on('exit', (err) -> cb err, readcapture) if cb
  child.stdout.on 'data', (data) ->
    unless pwa
      addcapture data
      return out.write data unless pwa
    ascii = data.asciiSlice 0
    out.flush()
    if ascii.indexOf(pwa.prompt) < 0
      addcapture data
      return out.write data
    else
      pwa.getPassword (err, pw) ->
        if err
          log err
          process.kill child.pid
          process.kill process.pid if err == 'SIGINT'
          cb err
        else if child.stdin.writable
          log "writing password to #{name}"
          child.stdin.write pw + "\n"
        else
          err = 'could not write password'
          process.kill child.pid
          log err
          cb err

      # TODO: 
      # We currently strip password prompt and feeds the buffer to console with
      # a replaced prompt (removing the confusing unique prompt identifier).
      # We should only write the prompt to the console, and everything else except the
      # unique prompt to the output stream which may, or may not, be the console.
      # but since the stream is binary, we might not want to perform a toString.replace
      # as we currently do, so we need to be more careful about how to go about this.
      # To complicate matters, it will likely work as is because the prompt arrives
      # in its own buffer chunk, but that may not always be the case, especially over ssh.
      # Hmm: perhaps buffer.asciiSplice(pwa.prompt, "") will work (splice, not slice).
      
      # NOTE: apparently the write below must be after the call to
      #       pwa.getPassword (or the equivalent require('./password).readSilentLine).
      #       otherwise the password is not accepted for some reason
      console.log("#{name} prompts for password\n" + data.toString().replace(pwa.prompt, "Password:"))
  child.stderr.on 'data', (data) ->
    ascii = data.asciiSlice 0
    if /^execvp\(\)/.test ascii
      console.log cmd + ': ' + data.asciiSlice 10
    else if /tcgetattr: Inappropriate ioctl for device/.test ascii
      console.log "expected error from ssh -t -t operation:" if opts.log
      console.log "  " + data.toString() if opts.log
    else
      console.log data.toString()

# see doc/api/shell
class Shell
  
  constructor: (opts) ->
    args = []
    if typeof opts == 'string'
      opts = {host: opts}
    opts = {} unless opts
    @log = opts.log
    @passwordCache = opts.passwordCache or password.cache()
    pushCustomArgs = ->
      if opts.args
        switch typeof opts.args
          when 'string'
            args.push opts.args
          when 'array'
            args = args.concat opts.args
          else
            throw new Error "bad argument, opts.args must be string or array (was #{typeof opts.args})"
    if typeof opts == 'string'
      opts = host: opts
    @outStream = opts.outStream
    @logStream = opts.logStream
    @captureLimit = opts.captureLimit ? 64 * 1024
    @silent = opts.silent
    if opts.host
      @name = opts.issuer or opts.name or opts.host
      @remote = true
      @shell = opts.ssh or 'ssh'
      if opts.port
        args.push "-p"
        args.push opts.port.toString()
      if opts.user
        args.push "-l"
        args.push opts.user
      pushCustomArgs()
      args.push opts.host
    else
      @name = opts.issuer or opts.name or "local-system"
      @remote = false
      @shell = opts.shell or process.env.shell or 'sh'
      pushCustomArgs()
      args.push "-c"
    @args = args

  run: (cmd, cb) ->
    if /^(\s*)sudo\s/.test cmd
      return @sudo cmd.slice(cmd.indexOf('sudo') + 4), cb
    _cb = (ec, readcapture) => cb.call(this, ec, readcapture) if cb
    captureLimit = @captureLimit if cb
    if cmd instanceof Array
      cmd = cmd.join(' && ')
    if typeof cmd != 'string'
      throw new Error "bad argument, cmd should be string or array (was #{typeof cmd})"
    args = @args.concat [cmd.toString()]
    spawn @shell, args, {
      name: @name
      log: @log
      captureLimit
      outStream: @outStream
      logStream: @logStream
      silent: @silent
    }, _cb
    this

  # on local systems calls a process directly bypassing the shell
  # on remote systems runs via shell
  # args should be shell escaped TODO: consider escaping inside this op
  spawn: (cmd, args, cb) ->
    if typeof args == 'function'
      cb = args
      args = []
    _cb = (ec) => cb.call(this, ec) if cb
    if @remote
      _args = @args.concat []
      _args.push cmd
      args = _args.concat args
      cmd = @shell
    spawn cmd, args, {name: @name, log: @log}, _cb
    this

  # use instead of run for sudo commands
  # run also redirects commands starting with sudo
  # cmd as array is not support, unlike run
  # (better create a script for sudoing multiple commands)
  sudo: (cmd, cb) ->
    captureLimit = @captureLimit if cb
    _cb = (ec) => cb.call(this, ec) if cb
    if cmd instanceof Array
      throw new Error "sudo doesn't allow cmd as array"
    if typeof cmd != 'string'
      throw new Error "bad argument, cmd should be string or array (was #{typeof cmd})"
    # -t: enable tty for sudo password prompt via ssh
    # -t -t: because our local stdin is also not tty
    pwa = password.agent @passwordCache
    args = @args.concat ['-t', '-t', 'sudo', '-p', pwa.prompt] 
    args = args.concat [cmd.toString()]
    child = cpspawn
    spawn @shell, args, {
        passwordAgent: pwa
        name: @name
        log: @log
        captureLimit
        outStream: @outStream
        logStream: @logStream
        silent: @silent
      }, _cb
    this

  # prompt user for password to preload password cache
  # not strictly needed, but may be more userfriendly
  promptPassword: (prompt, cb) ->
    password.agent(@passwordCache).getPassword(prompt, cb)
  
  # like prompt password, but programmatically set password
  setPassword: (password) ->
    @passwordCache.set(password)
    
  # prevent new commands from using old password
  resetPassword: -> @passwordCache.reset()

exports.shell = (opts) -> new Shell opts
