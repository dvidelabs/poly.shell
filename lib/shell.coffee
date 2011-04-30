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
  outcap = []
  errcap = []
  outcap.capsize = 0
  errcap.capsize = 0
  caplimit = opts.captureLimit or 0
  caplimit = 0 unless cb
  readcapture = (cap, encoding) ->
    s = ""
    for buf in cap
      s += buf.toString(encoding)
    return s
  # capture buffers, but don't convert them unless the user actually wants them
  addcapture = (cap, buf) ->
    return if cap.capsize == caplimit
    if buf.length + cap.capsize < caplimit
      cap.push buf
      cap.capsize += buf.length
    else
      cap.push buf.slice 0, caplimit - cap.capsize
      cap.capsize = caplimit
  child = cpspawn cmd, args
  pwa = opts.passwordAgent
  if opts.quiet or opts.silent
    outstream = { write: -> }
  else
    outstream = opts.outStream or process.stdout
  if opts.silent
    errstream = { write: -> }
  else
    # Node.js currently has no process.stderr
    errstream = opts.errStream or process.stdout 
  log = (buffer) ->
    return unless opts.log
    if opts.logStream
      # user should add newline and flush if so desired
      opts.logStream.write buffer
    else
      console.log buffer
  log "#{name} : #{cmd} #{args.join(' ')}"
  if cb
    child.on('exit', (err, encoding) -> cb err, {
      out: (type) -> readcapture(outcap, encoding)
      err: (type) -> readcapture(errcap, encoding)
    });
  child.stdout.on 'data', (data) ->
    unless pwa
      addcapture outcap, data
      outstream.write data
      return
    ascii = data.asciiSlice 0
    out.flush()
    if ascii.indexOf(pwa.prompt) < 0
      addcapture outcap, data
      outstream.write data
      return
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
      addcapture errcap, data
      errstream.write data
      return

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
    @errStream = opts.errStream
    @captureLimit = opts.captureLimit ? 64 * 1024
    @silent = opts.silent
    @quiet = opts.quiet
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
      @name = opts.issuer or opts.name or "local"
      @remote = false
      @shell = opts.shell or process.env.shell or 'sh'
      pushCustomArgs()
      args.push "-c"
    @args = args

  _spawnopts: (extra) ->
    opts = {
      name: @name
      log: @log
      outStream: @outStream
      logStream: @logStream
      errStream: @errStream
      silent: @silent
      quiet: @quiet
      captureLimit: @captureLimit
    }
    util.merge(opts, extra) if extra
    opts
    
  run: (cmd, cb) ->
    if /^(\s*)sudo\s/.test cmd
      return @sudo cmd.slice(cmd.indexOf('sudo') + 4), cb
    _cb = (ec, capture) => cb.call(this, ec, capture) if cb
    captureLimit = @captureLimit if cb
    if cmd instanceof Array
      cmd = cmd.join(' && ')
    if typeof cmd != 'string'
      throw new Error "bad argument, cmd should be string or array (was #{typeof cmd})"
    args = @args.concat [cmd.toString()]
    spawn @shell, args, @_spawnopts(), _cb
    # don't return this, it suggests sequential shell().run().run(), but it is concurrent.
    null 

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
    spawn cmd, args, @_spawnopts(), _cb
    null

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
    spawn @shell, args, @_spawnopts({ passwordAgent: pwa}), _cb
    null

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
