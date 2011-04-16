#! /usr/bin/env coffee
spawn = require('child_process').spawn
exec =  require('child_process').exec
util = require 'util'
sys = require 'sys'

ploy = exports
ploy.run = (cmd, args, cb) ->
  args = [] unless args
  if typeof args == 'function'
      cb = args
      args = []
  child = spawn cmd, args
  child.stdout.on 'data', (data) ->
    process.stdout.write data
  child.stderr.on 'data', (data) ->
    if (/^execvp\(\)/.test(data.asciiSlice(0,data.length)))
      console.log cmd + ': ' + data.asciiSlice 10
    else
      console.log "err:" + data.toString()
  child.on 'exit', cb if cb

# examples:
# run_remote "example.com", 'ls', ['.'], (code) -> console.log "failed" if code != 0
# run_remote "foo@example.com:2200", 'ls'
# run_remote {host: "example.com", user:"foo", port:"2200"}, 'ls'
ploy.run_remote = (host, cmd, args, cb) ->    
  args = [] unless args
  if typeof args == 'function'
      cb = args
      args = []
  args.unshift cmd
  if typeof host == 'object'
    opts = host
    host = opts.host
    if opts.port
      args.unshift opts.port
      args.unshift '-p '
    if opts.user
      args.unshift opts.user
      args.unshift '-l '
  if typeof host == 'string'
      args.unshift host
  else
    throw new Error 'bad argument, expected host name'
  eh = (code) ->
    if code != 0
      console.log "remote host: #{host}, command: #{cmd}, failed with code #{code}" 
    cb code if cb
  ploy.run 'ssh', args, eh
