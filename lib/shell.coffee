cpspawn = require('child_process').spawn
password = require './password'
util = require './util'
_ = require 'underscore'

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
  caplimit = opts.captureLimit ?  64 * 1024
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
  return child

# see doc/api/shell
class Shell
  # shell([host], [opts])
  constructor: (host, opts) ->
    args = []
    if host and opts
      opts = _.clone opts
      opts.host = host
    else if host
      if typeof host == 'string'
        opts = { host }
      else
        opts = host
    opts = {} unless opts
    @options = opts
    @log = opts.log
    @passwordCache = opts.passwordCache or password.cache()
    pushExtraArgs = (extra, name) ->
      if extra
        switch typeof extra
          when 'string'
            args.push extra
          when 'array'
            args = args.concat extra
          else
            throw new Error "bad argument, #{name} must be string or array"
    if opts.host
      @name = opts.issuer or opts.name or opts.host
      @remote = true
      @shellCmd = opts.ssh or 'ssh'
      if opts.port
        args.push "-p"
        args.push opts.port.toString()
      if opts.user
        args.push "-l"
        args.push opts.user
      pushExtraArgs(opts.sshargs, 'options.sshargs')
      args.push opts.host
    else
      @name = opts.issuer or opts.name or "local"
      @remote = false
      @shellCmd = opts.sh or process.env.shell or 'sh'
      pushExtraArgs(opts.shargs, 'options.shargs')
      args.push "-c"
    @shellArgs = args

  _spawnopts: (extra) ->
    options = @options
    opts = {
      name: @name
      log: @log
      outStream: options.outStream
      logStream: options.logStream
      errStream: options.errStream
      silent: options.silent
      quiet: options.quiet
      captureLimit: options.captureLimit
    }
    _.extend(opts, extra) if extra
    opts
    
  run: (cmd, cb) ->
    if /^(\s*)sudo\s/.test cmd
      return @sudo cmd.slice(cmd.indexOf('sudo') + 4), cb
    _cb = (ec, capture) => cb.call(this, ec, capture) if cb
    if cmd instanceof Array
      cmd = cmd.join(' && ')
    if typeof cmd != 'string'
      throw new Error "bad argument, cmd should be string or array (was #{typeof cmd})"
    args = @shellArgs.concat [cmd.toString()]
    return spawn @shellCmd, args, @_spawnopts(), _cb

  spawn: (cmd, args, cb) ->
    if typeof args == 'function'
      cb = args
      args = []
    _cb = (ec) => cb.call(this, ec) if cb
    return spawn cmd, args, @_spawnopts(), _cb

  # use instead of run for sudo commands
  # run also redirects commands starting with sudo
  # cmd as array is not support, unlike run
  # (better create a script for sudoing multiple commands)
  sudo: (cmd, cb) ->
    _cb = (ec) => cb.call(this, ec) if cb
    if cmd instanceof Array
      throw new Error "sudo doesn't allow cmd as array"
    if typeof cmd != 'string'
      throw new Error "bad argument, cmd should be string or array (was #{typeof cmd})"
    # -t: enable tty for sudo password prompt via ssh
    # -t -t: because our local stdin is also not tty
    pwa = password.agent @passwordCache
    args = @shellArgs.concat ['-t', '-t', 'sudo', '-p', pwa.prompt] 
    args = args.concat [cmd.toString()]
    return spawn @shellCmd, args, @_spawnopts({ passwordAgent: pwa}), _cb

  _rsync: (args, cb) ->
    cmd = @options.rsync ? 'rsync'
    args = [@options.rsyncargs ? [], args]
    if @remote
      rsh = @shellCmd
      rsh += " -p #{@options.port}" if @options.port
      rsh += " -l #{@options.user}" if @options.user
      # tricky: don't add single quotes to rsh string
      # or the entire string becomes the ssh binary
      args = ['-e', "#{rsh}", args]
    args = _.flatten(args)
    return @spawn cmd, args, cb

  rsyncup: (sources, dest, args, cb) ->
    if typeof args == 'function'
      cb = args; args = null
    if @remote
      dest = @options.host + ":" + dest
    return @_rsync [args or [], sources, dest], cb

  rsyncdown: (sources, dest, args, cb) ->
    if typeof args == 'function'
      cb = args; args = null
    if @remote
      h = @options.host + ":"
      sources = _.map(_.flatten([sources or []]), (src) -> h + src)
    return @_rsync [args or [], sources, dest], cb

  upload: (sources, dest, cb) ->
    return @rsyncup sources, dest, ["-azP", "--delete"], cb

  download: (sources, dest, cb) ->
    return @rsyncdown sources, dest, ["-azP", "--delete"], cb

  # prompt user for password to preload password cache
  # not strictly needed, but may be more userfriendly
  promptPassword: (prompt, cb) ->
    password.agent(@passwordCache).getPassword(prompt, cb)
  
  # like prompt password, but programmatically set password
  setPassword: (password) ->
    @passwordCache.set(password)
    
  # prevent new commands from using old password
  resetPassword: -> @passwordCache.reset()

exports.shell = (host, options) -> new Shell(host, options)
