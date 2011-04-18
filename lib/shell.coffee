cpspawn = require('child_process').spawn
util = require 'util'


# TODO: for sudo: create a password cache with timeout
#   - Ubunto 10.04 remembers sudo over ssh
#   - Debian Squeeze doesn't, so user is prompted repeatedly
#   Allow cache to be preloaded, for example by running password
#   early in script, or by using a master password for encrypted host
#   passwords.
# TODO: generate random password prompt strings such that
#   dumping source of this script doesn't trigger password prompter
spawn = (cmd, args, opts, cb) ->
  args = [] unless args
  opts = {} unless opts
  name = if opts.name? then opts.name + ": " else  ""
  if typeof args == 'function'
      cb = args
      args = []
  else if typeof opts == 'function'
      cb = opts
      opts = {}
  if opts.log
    console.log "#{name}#{cmd} #{args.join(' ')}"
  child = cpspawn cmd, args
  child.stdout.on 'data', (data) ->
    if /(^:w6kffb47:Password:w6kffb47:$)|(\n:w6kffb47:Password:w6kffb47:$)/.test data.asciiSlice(0,data.length)
      console.log "#{name} prompts for password" if opts.log
      require('./password').askPassword (err, pw) ->
        if err == 'SIGINT'
          process.kill child.pid
          cb 'user killed shell during password query'
        else if err
          cb err
        else
          child.stdin.write pw + "\n"
    else
      process.stdout.write data
  child.stderr.on 'data', (data) ->
    ascii = data.asciiSlice(0,data.length)
    if /^execvp\(\)/.test ascii
      console.log cmd + ': ' + data.asciiSlice 10
    else if /tcgetattr: Inappropriate ioctl for device/.test ascii
      console.log "expected error from ssh -t -t operation:" if opts.log
      console.log "  " + data.toString() if opts.log
  child.on 'exit', cb if cb

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
  # opts.log <bool> enable logging (experimental)
  # opts.args <array of string | string> are additional shell arguments for local and remote shells
  #   note: opt.args are for the shell, not for the commands that the shell might run later
  constructor: (opts) ->
    args = []
    if typeof opts == 'string'
      opts = {host: opts}
    opts = {} unless opts
    @log = opts and opts.log? and opts.log
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

  # TODO: this is far from complete, must respond to password requests,
  #       or set password from elsewhere
  sudo: (cmd, cb) ->
    _cb = (ec) => cb.call(this, ec) if cb
    if cmd instanceof Array
      cmd = cmd.join(' && ')
    if typeof cmd != 'string'
      throw new Error "bad argument, cmd should be string or array (was #{typeof cmd})"
    # -t: enable tty for sudo password query
    # -t -t: because our local stdin is not tty
    args = @args.concat ['-t', '-t', 'sudo', '-p', ':w6kffb47:Password:w6kffb47:'] 
    args = args.concat [cmd.toString()]
    child = cpspawn
    spawn @shell, args, {name: @name, askpass: true, log: @log}, _cb
    this


exports.shell = (opts) -> new Shell opts
