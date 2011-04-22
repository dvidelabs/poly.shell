cpspawn = require('child_process').spawn
password = require './password'
util = require './util'

# TODO:
# Change current working directory of shell
# if the configuration holds a path settings.

spawn = (cmd, args, opts, cb) ->
  args = [] unless args
  opts = {} unless opts
  name = opts.name ? ""
  if typeof args == 'function'
      cb = args
      args = []
  else if typeof opts == 'function'
      cb = opts
      opts = {}
  if opts.log
    console.log "#{name} : #{cmd} #{args.join(' ')}"
  child = cpspawn cmd, args
  pwa = opts.passwordAgent
  child.on('exit', cb) if cb
  child.stdout.on 'data', (data) ->
    return process.stdout.write data unless pwa
    ascii = data.asciiSlice 0
    process.stdout.flush()
    if ascii.indexOf(pwa.prompt) < 0
      return process.stdout.write data  
    else
      pwa.getPassword (err, pw) ->
        if err
          console.log err if opts.log
          process.kill child.pid
          process.kill process.pid if err == 'SIGINT'
          cb err
        else if child.stdin.writable
          console.log "writing password to #{name}" if opts.log
          child.stdin.write pw + "\n"
        else
          err = 'could not write password'
          process.kill child.pid
          console.log err if opts.log
          cb err
      # note: apparently the write below must be after the call to
      #       pwa.getPassword (or the equivalent require('./password).readSilentLine).
      #       otherwise the password is not accepted for some reason
      process.stdout.write ("#{name} prompts for password\n" + data.toString().replace(pwa.prompt, "Password:"))
  child.stderr.on 'data', (data) ->
    ascii = data.asciiSlice 0
    if /^execvp\(\)/.test ascii
      console.log cmd + ': ' + data.asciiSlice 10
    else if /tcgetattr: Inappropriate ioctl for device/.test ascii
      console.log "expected error from ssh -t -t operation:" if opts.log
      console.log "  " + data.toString() if opts.log
    else
      console.log data.toString()

class Shell
  
  # usage: sh = new Shell([host|opts])
  # 
  # examples:
  #   sh = new Shell();
  #   bash = new Shell({sh: /bin/bash});
  #   bash2 = new Shell("example.com", {log:true});
  #   ex = new Shell({host:example.com, user:"foo", port:2200});
  #   ex2 = new Shell("foo@example.com");
  #
  # host <string> optional, takes precedence over opts.host
  #
  # opts <hash> optional:
  # If host or opts.host is defined, a remote shell is created,
  # otherwise a local shell is created (setting or not setting opts.ssh does not affect this)
  # opts.name <string> optional informative system name used for logging (not user name for remote login).
  # opts.sh <string> overrides local system shell when opts.host is not specified.
  #                  by default $SHELL is used when present
  # opts.ssh <string> allows for a specific ssh path used when opts.host is specified.
  # opts.user <int> optional user name for ssh
  # opts.port <int> optional port number for ssh
  # opts.log <bool> enable logging
  # opts.passwordCache <PasswordCache> enables sharing of passwords between multiple shells
  # opts.args <array of string | string> are additional shell arguments for local and remote shells
  #   note: opt.args are for the shell, not for the commands that the shell might run later
  constructor: (opts) ->
    args = []
    if typeof opts == 'string'
      opts = {host: opts}
    opts = {} unless opts
    @log = opts and opts.log? and opts.log
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
    if opts.host
      @name = opts.name or opts.host
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
      @name = opts.name or "local-system"
      @remote = false
      @shell = opts.shell or process.env.shell or 'sh'
      pushCustomArgs()
      args.push "-c"
    @args = args

  # sh.run(cmd, [callback(errorCode)])
  # cmd is a string, or an array that will be joined with &&.
  #
  # handles sudo in the trivial case where cmd is a string starting with sudo
  # like sh.run 'sudo tail /var/log/auth.log', but not with arrays or sudo
  # later in the syntax.
  #
  # example
  #   sh = new Shell();
  #   sh.run('ls .', function(ec)
  #     { if(ec) { throw new Error("#{this.name} failed with error: " + ec); }})
  #
  # more examples in test folder
  #
  # TODO: consider more advanced piping scheme
  #       for now, everything goes to stdout concurrently
  
  run: (cmd, cb) ->
    if /^(\s*)sudo\s/.test cmd
      return @sudo cmd.slice(cmd.indexOf('sudo') + 4), cb
    _cb = (ec) => cb.call(this, ec) if cb
    if cmd instanceof Array
      cmd = cmd.join(' && ')
    if typeof cmd != 'string'
      throw new Error "bad argument, cmd should be string or array (was #{typeof cmd})"
    args = @args.concat [cmd.toString()]
    spawn @shell, args, {name: @name, log: @log}, _cb
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
        name: @name
        passwordAgent: pwa
        log: @log
      }, _cb
    this

  # prompt user for password to preload password cache
  # not strictly needed, but may be more userfriendly
  promptPassword: (cb) ->
    password.agent(@passwordCache).getPassword(cb)
  
  # like prompt password, but programmatically set password
  setPassword: (password) ->
    @passwordCache.set(password)
    
  # prevent new commands from using old password
  resetPassword: -> @passwordCache.reset()

exports.shell = (opts) -> new Shell opts
