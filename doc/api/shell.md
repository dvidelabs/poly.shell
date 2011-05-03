## Shell Overview

The most important use of the shell is the shell object automatically
created inside job actions, but shells can be used in isolation for
many other purposes, including arbitrary tasks in Jakefiles.

### Shell with Job Actions

To understand the shell together with job actions, look at the `Shell
API` below and study the options. These options represent properties
in site configuration objects. the job controller sets a few of these
directly: if logging is enabled it will be set in the shell also, and
the shell name is not the site name but `this.issuer` which is a
longer unique id including the site name for better logging
consistency.

See also `sudo` operation below. This also apply when running shells
under job control.

### Standalone Shell Usage

Basic example running local and remote hosts, assuming .ssh/config has
been configured with real host name and ssh keys.

    var shell = require('poly').shell;
    
    shell('example.com').run("ls");
    
    shell().run("echo running local shell");
    
    host1 = shell({ host: "example.com", log: true });
    host1.run("touch iamhost1.test");

Callbacks can be used to get the error code from the shell, or delay
execution between two shell commands (although it is usually better to
use ' && ' in a single command):

    var shell = require('poly').shell;

    var host = shell('example.com');
    
    host.run("ls", function(err) {
      if(!err) {
        host.run("touch hello.test");
      };
    });

Multiple shell commands can be given as an array and will be converted
to a single string joined by ' && ', like the last command below:

    var shell = require('poly').shell;

    var host = shell('example.com');
    host.run(["ls", "touch hello2.test"]);
    host.run("ls && touch hello2.test");


Site configurations are used by the `poly.jobs()`, partially to
initialise remote shells. Here is an example using just site
configurations and shells without job control.

    var poly = require('poly');
    var sites = poly.sites();
    sites.add('host1', { host: "example.com" });
    
    var host1 = shell(sites.get('host1'));
    host1.run("touch killroywashere.test");

Shells can also be accessed from within job actions, see `jobs.add`,
`jobs.run`.

### Callbacks

Shells run commands as background processes. Callbacks can be used to
wait for completion with a numeric error code:

    var shell = require('poly').shell;
    
    shell.run("ls");
    shell.run("ls", function() { console.log "done"; });
    shell.run("ls", function(ec) {
      if(ec)
        console.log("ls failed with error code: " + err);
      else
        console.log("done");

### Capturing Output

By default shells output all commands to `process.stdout` and also
captures the output to a buffer for use in callbacks:

    var shell = require('poly').shell;

    shell().run("ls", function(ec, capture) {
        if(!ec)
          console.log("output was: " + capture() + "!");
    }

Notice that `capture` is a function that we call to access the
captured output. This converts the internal buffers to a string while
avoiding the conversion for commands that do not need it.

The capture is limited to 64K, but can be changed using the
`option.captureLimit` in the Shell constructor (this is also a site
configuration option). Any output beyond the limit will not show up in
the output() function, but will still be written to the output stream.
Capturing can be disabled by setting `captureLimit = 0` If no callback
is given, output is not captured at all, but still written to the
output stream.

### Redirecting Output

The output stream can be changed or nulled by adding an object with a
write method as the `option.outStream` property (also a site
configuration). The same applies to logging with the
`option.logStream` option when `option.log` is true:

    var shell = require('poly').shell;
    var logger = { write: function(buffer) { console.log buffer } };
    var devnull = { write: function() {} };

    shell({
      outStream: devnull,
      logStream: logger,
      captureLimit: 1024 * 1024 * 2
    }).run("ls",
      function(ec, capture) {
        if(!ec)
          console.log capture.out();
    });

In the above we redirected the output stream to nothing in order to
silence the output and capture it instead. The shell option
`options.silent` has the same effect.

`options.errStream` and `capture.err()` behave similar to the output
stream. The error stream obeys `options.silent` and
`options.captureLimit` the same as the outStream.

The `options.logStream` has an option `logStream.flush()` method that
is called after each log entry if present. This to ensure logging is
captured in the event of a system down event.

Standard Node.js Writable streams can also be used as outStream and
logStream objects. This enables use of shells in http servers, as an
example.

### sudo

The shell has a `sudo` method to detect password prompts and locally
prompt the user. This can be messy if there is a lot of logging going
on, so it is best to make sure at least the first `sudo` operation
runs at an isolated stage (or an explicit `shell.promptPassword`
operation), although not a requirement.

There are two different ways to run `sudo`; one where the shell object
detects `sudo` in the start of the command, and another one where we
call `shell.sudo` explicitly. The latter is recommended, but for
trivial commands the former should work just as well:

    var shell = require('poly').shell;
    var host = shell('example.com');

    host.sudo("ls");
    host.run 'sudo tail /var/log/auth.log | grep root';

The example above runs two shells concurrently on the same shell
object. One of the commands will detect a `sudo` prompt, ask for
password, save the password in a cache and feed the password to the
remote server. The other command will detect a `sudo` request, then
detect that the other shell is already pending for user input and wait
for the result, then access the cached password and send it to the
server.

Note that on some systems, the remote end will have a `sudo` timeout
so the second command will not need to ask for a password, while
others will.

We can also set the password explicitly if we dare to have it
accessible in a script. This will preload the cache and the first
command detecting a `sudo` prompt will try the cached password first
before falling back to asking the user:

    var shell = require('poly').shell;
    var host = shell('example.com');
    
    host.setPassword("xyzzy");
    host.sudo("ls");

We can also explicitly ask the user for a password before detecting a
sudo prompt and then cache the password for later use. When a shell
eventually detects a `sudo` prompt, it will first try the cached
password before asking the user:

    var shell = require('poly').shell;
    var host = shell('example.com');

    host.promptPassword();
    host.sudo("ls", function(err) {
      if(err) { host.resetPassword(); } });

In the above example, we have chosen to reset the password after the
shell returns.

### Transferring Files

Files can be transferred via rsync over ssh using

- shell.upload(sources, destination, [cb])
- shell.download(sources, destination, [cb])

`sources` can optionally be an array of pathnames. Files are up- or
downloaded into a single destination directory. The shell host is
added to the destination for uploads and to the sources for downloads:

    var host = shell("example.com");
    var local = shell();

    local.run("mkdir -p tmp && echo hello >
      tmp/hello.local.test", function () {
      host.upload("tmp/hello.local.test", "uploads");
    });

Remote files are relative to the user account home, local files are
relative to current working directory, much like any other shell
command. If the shell is local, both sources and destination are relative
to the current working directory (folder).

As usual with `rsync`, a source pathname with a trailing slash means the copy
contents of the directory but not the directory itself, and otherwise
include the directory.

The destination (or sources) host is automatically added to the
destination (or sources).

`shell.upmirror` and `shell.downmirror` behaves like up- and download
but deletes files in the destination if they are not present in the
sources.

**Warning**:
 
*Mirror deletes any files in the destination that does not match the
source. Careless use of mirror can lead to extensive data loss.*

The above functions are really convenience functions calling the lower
level `shell.upsync` and `shell.downsync` functions which take
additional rsync arguments. The up- and download functions are
implemented by these functions using `['-azP']` as argument. The up-
and downmirror functions uses the arguments `['-azP','--delete']`:

    var mydownload = function(host, port, user, sources, dest) {
      shell({ host: host, user: user, port: port}
        ).downsync(sources, dest, ['-azP']);
    };

Note: `rsync` runs via ssh. `options.port` and `options.user`
are passed to rsync using the rsync -e option. For example:

    var host = shell({ host: "example.com",
      port: 10000, user: beatrice });
    host.upsync("localfile", "destfile", ['-z']);

becomes:

    $ rsync -e 'ssh -p 10000 -l beatrice'
       -z localfile example.com:destfile

As is always the case with remote shell operation, user name and port
number are optional when defined in `.ssh/config`, but will override
the `.ssh/config` setting.

## Shell Reference

### shell([host], [options])

Creates a new shell object, but does not run anything or consume any
significant resources. Holds configuration data needed to start a local shell,
or a remote shell. Also holds information for password caching:

    var shell = require('poly').shell;
    var local = shell();
    var host1 = shell("example.com", { log: true });
    var host2 = shell("example.com");
    var host3 = shell({ host: "example.com", port: 10000, user: "beatrice" });

If neither `host` nor `options` are given, a local shell is created. If both are
given, 'host' takes priority over `options.host`. Do not use `localhost` to
create a local shell, it would connect via ssh.

`host` : the name of the host. Typically matches an entry in .ssh/config with
user name and other real host domain or IP address. 'host' is also used as the
default shell name which is used for logging purposes and can be overridden in
options.

`options`:

- `options.captureLimit`: amount of output to capture in buffers given
  to `shell.run` callback -- see `shell.run`. Defaults to 64K.
  No output is captured when `options.captureLimit = 0`.
  All output is streamed to `option.outStream` or `process.stdout`
  regardless. The error stream is captured separately with the same limit.

- `options.errStream`: optional error stream object similar to outStream.
  Produces no output when `options.silent` is true.

- `options.issuer`: optional name used for logging, overrides `host`
  and `name` for this purpose. Set by job control when creating a
  shell for a job action with the actions `this.issuer` property. -
  `options.log`: optional true to enable logging (set by job controls
  log setting for job action shells).
  
- `options.logStream`: Like `options.outStream` for logging. Only used when
  `options.log` is true. Defaults to:
   `{ write: function(data) { console.log(data.toString()); }}`.
   
- `options.name`: optional informative system name used for logging
  (not a user name for remote login).

- `options.outStream`: optional stream object that must be an object with
  function named write taking a buffer as argument, for example:
  `var devnull = { write: function(buffer) {} };`
  Node.js WritableStreams can also be used. Does not capture `sudo` password
  prompts which are always directed to `process.stdout`. Produce no output
  when `options.silent` or `options.quiet` are set.

- `options.passwordCache`: enables sharing of passwords between
  multiple shells - see `Password Agents`.

- `options.port`: integer port number for ssh if not the standard port
  22 (can also be set in `.ssh/config`).

- `options.quiet`: redirects output stream to nothing, but leaves
  error stream open.
  
- `options.sh`: optional name for the shell to use instead of the
  environment SHELL variable when running local systems.

- `options.shargs`: (a string or array of strings), optional extra
  arguments to ssh before the command to execute (these arguments are
  for ssh, not the command being run by ssh).
    
- `options.silent`: redirect the output and error stream to nothing, also
  when `outStream` or `errStream` has been set. Does not affect `logStream`.


- `options.ssh`: optional alternative ssh command to use for remote
  access.

- `options.sshargs`: optional extra arguments to ssh.

- `options.rsync`: optional alternative rsync command.

- `options.rsyncargs`: optional extra rsync arguments.

- `options.user`: optional user name for ssh (can also be set in
  `.ssh/config`).

### shell.run(cmd, [callback(err, capture)])

`cmd` : a command string to be executed by a local or remote shell. If given
as array, the individual commands are joined by ' && ' before being given to
the ssh command - no real magic or extra parsing here.

`callback(err, capture)` : optional callback to know when the shell has completed.
Especially useful under job control to ensure that a job action does not
complete before the shell does, and that the action fails if the shell does.
If shell is created with `option.captureLimit = 0`, capture returns the empty string,
otherwise up to `options.captureLimit` bytes of buffered output, or default 64K.

When the shell is created as part of a `jobs.add()` action invocation,
`this.async()` may be used as callback. This makes the action wait for
the shell before signalling the action complete (modulo other calls to
`this.async()`).

If no callback is given, the shell continues as a background process
and no output is captured (but still streamed to the shells output
stream).

`capture` is an object with the following functions:

- out([encoding = 'utf8']): convert captured output buffers into a
  string with the given encoding. Returns at most 'captureLimit' bytes
  before conversion.

- err([encoding = 'utf8']): like out for the error stream (not the log stream).

If the shell command begins with "sudo", "sudo" is stripped from the command and
the rest is passed on to the `shell.sudo` helper command.

Returns the Node.js child process object.

### shell.sudo(cmd, [callback(err, capture)])

Will detect a sudo password prompt using a globally unique prompt name and
replace that prompt with 'Password:' and display it the user. If there is a
password agent with a password already, this password will be tried once
before bugging the user. The `err` callback should be tested for the string
`SIGINT` similar to `shell.promptPassword`.

If sudo doesn't ask for a prompt, the operation behaves like a normal
`shell.run` command. If a password is prompted, the operation proceeds like a
normal `shell.run` command once the password is accepted.

Password prompts are directed to process.stdout but are not included in the
output streamed to `options.outStream` and is not buffered in `capture()`.

If there is another password prompt pending with the same password agent, sudo
will wait for that prompt to complete and then use the answer similar to an
already cached password - i.e. once before falling back to user prompt.

To avoid too much noise messing with the password prompt, sudo commands should
not be run in parallel with other commands. However, other sudo commands
connected to the same agent will pause so they can run without obscuring the
prompt.

It may be a better strategy to start the entire operation with
`shell.promptPassword` in isolation before kicking off a host of concurrent
shell commands.

Returns the Node.js child process object.

### shell.upload(sources, dest, [cb])

Calls upsync with the arguments ['-azP']. 

### shell.download(sources, dest, [cb])

Calls downsync with the arguments ['-azP']. 

### shell.upmirror(sources, dest, [cb])

Calls upsync with the arguments ['-azP', '--delete']. 

*Warning: 'dest' will have all files removed
that do not match the source list.*

### shell.downmirror(sources, dest, [cb])

Calls downsync with the arguments ['-azP', '--delete']. 

*Warning: 'dest' will have all files removed
that do not match the source list.*

### shell.downsync(sources, dest, [args], [cb])

Transfers files from remote system to local system.

See also `shell.upsync`.

`args`: flags passed to rsync before `sources`.

`sources: relative to remote host user. Remote host prefix is added
before passed to rsync. If running in a local shell, `sources` are
relative to the current working directory.

`dest`: destination file or folder (depending on args) relative to
current working directory on local system.

`cb`: callback similar to `shell.run`.

### shell.upsync(sources, dest, [args], [cb])

Transfers local files to remote system.

`rsync` operation over .ssh that respects `shell.options.user` and
`shell.options.port` as well as `shell.options.rsync` and
`shell.options.rsyncargs`. Add extra arguments with `args`.

Adds site destination to `dest` argument.

`args`: optional rsync argument or (nested) array of extra arguments presented
to `rsync` before the `sources` list. Defaults to file to file transfer, but
can  for example create a mirror using `args = ['-azP', '--delete']`
where `dest` is a directory.

`sources`: pathname or (nested) array of pathnames on the local system relative
to current working directory.

`dest`: pathname for remote site relative to user home. If running in a local shell, 
relative to current working directory.

`cb`: callback similar to `shell.run`.

### shell.spawn(cmd, args, [cb])

Executes a local system command, also when the shell is remote.
The callback works like `shell.run` and shell.run is roughly `spawn`
with `sh` or `ssh` as first argument. Useful for running source
control and rsync commands to access the remote system.

Returns Node.js child process object, including child.pid.

### shell.setPassword(password)

Sets the password cache such that the first `sudo` prompt will not ask
the user unless the password is incorrect.

### shell.resetPassword()

Clears the password cache.

### shell.promptPassword(prompt, [callback(err)])

`prompt`: optional string to display to the user, defaults to nothing,
otherwise write prompt to `process.stdout`, also when shell output has
been redirected.

Waits for user input unless the password cache already has the password,
or waits for another prompt if the cache says one is active.
Prompts the user for a password without echoing the input text to the
console. Callback makes it possible to wait for the user to complete
the password entry. Issues the error string 'SIGINT' if the user types
'Ctrl+C' and should normally be used to issue a
`process.kill(process.pid)`. Otherwise similar to setPassword.

### shell.log

Property that can be read and set. Enables similar top `options.log`.

### shell.options

The options given as input. Gives access to a copy of site configuration when
the shell is created by a job action, see `jobs()`.

### shell.remote

A read-only flag that is true if the shell is running on a remote
system. Set if `options.host` has been specified.

### shell.shellCmd

The command used to run the shell, typically "sh" or the SHELL environment
variable for local systems, and "ssh" for remote systems. Affected by
`options.ssh` and `options.shell` for local and remote systems respectively.

### shell.shellArgs

Array of arguments passed to `spawn` when running shell commands, affected
by `options.shargs` and `options.sshargs`.

### shell.passwordCache

Property equal to assigned options.passwordCache, or a internally created
password cache object if none were provided. The property can be used to
initialise new shells that share the same password.
