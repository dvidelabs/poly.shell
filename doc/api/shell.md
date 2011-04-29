## Shell

The most important use of the shell is the shell object automatically created
inside job actions, but shells can be used in isolation for many other
purposes, including arbitrary tasks in Jakefiles.

## Overview

### Shell with job actions

To understand the shell together with job actions, look at the `Shell API`
below and study the options. These options represent properties in site
configuration objects. the job controller sets a few of these directly: if
logging is enabled it will be set in the shell also, and the shell name is not
the site name but `this.issuer` which is a longer unique id including the site
name for better logging consistency.

See also `sudo` operation below. This also apply when running shells under job
control.

### Standalone Shell usage

Basic example running local and remote hosts, assuming .ssh/config has been
configured with real host name and ssh keys.

TODO: test these examples


    var shell = require('polyshell').shell;
    
    shell('example.com').run("ls");
    
    shell().run("echo running local shell");
    
    host1 = shell({ host: "example.com", log: true });
    host1.run("touch iamhost1.test");

Callbacks can be used to get the error code from the shell, or delay execution
between two shell commands (although it is usually better to use ' && ' in a
single command):

    var shell = require('polyshell').shell;

    var host = shell('example.com');
    
    host.run("ls", function(err) {
      if(!err) {
        host.run("touch hello.test");
      };
    });

Multiple shell commands can be given as an array and will be converted
to a single string joined by ' && ', like the last command below:

    var shell = require('polyshell').shell;

    var host = shell('example.com');
    host.run(["ls", "touch hello2.test"]);
    host.run("ls && touch hello2.test");


Site configurations are used by the Polyshell job controller, partially to
initialise remote shells. Here is an example using just site configurations
and shells without job control.

    var polyshell = require('polyshell');
    var sites = polyshell.sites();
    sites.add('host1', { host: "example.com" });
    
    var host1 = shell(sites.get('host1'));
    host1.run("touch killroywashere.test");

Shells can also be accessed from within job actions, see `jobs.add`,
`jobs.run`.

### Callbacks

Shells run commands as background processes. Callbacks can be used to wait
for completion with a numeric error code:

    var shell = require('polyshell').shell;
    
    shell.run("ls");
    shell.run("ls", function() { console.log "done"; });
    shell.run("ls", function(ec) {
      if(ec)
        console.log("ls failed with error code: " + err);
      else
        console.log("done");

### Capturing Output

By default shells output all commands to `process.stdout` and also captures the
output to a buffer for use in callbacks:

    var shell = require('polyshell').shell;

    shell().run("ls", function(ec, capture) {
        if(!ec)
          console.log("output was: " + capture() + "!");
    }

Notice that `capture` is a function that we call to access the captured
output. This converts the internal buffers to a string while avoiding
the conversion for commands that do not need it.

The capture is limited to 64K, but can be changed using the
`option.captureLimit` in the Shell constructor (this is also a site
configuration option). Any output beyond the limit will not show up in
the output() function, but will still be written to the output stream.
Capturing can be disabled by setting `captureLimit = 0` If no callback
is given, output is not captured at all, but still written to the output
stream.

### Redirecting Output

The output stream can be changed or nulled by adding an object with a
write method as the `option.outStream` property (also a site configuration).
The same applies to logging with the `option.logStream` option when
`option.log` is true:

    var shell = require('polyshell').shell;
    var logger = { write: function(buffer) { console.log buffer } };
    var devnull = { write: function() {} };

    shell({
      outStream: devnull,
      logStream: logger,
      captureLimit: 1024 * 1024 * 2
    }).run("ls",
      function(ec, capture) {
        if(!ec)
          console.log capture();
    });

In the above we redirected the output stream to nothing in order to silence the output
and capture it instead. The shell option `options.silent` has the same effect.

Standard Node.js Writable streams can also be used as outStream and logStream objects.

### sudo

The shell has a `sudo` method to detect password prompts and locally prompt
user. This can be messy if there is a lot of logging going on, so best to make
sure at least the first `sudo` operation runs at an isolated stage, although
not a requirement.

In the following example we see two different ways to run `sudo`. One where the
shell object detects `sudo` in the start of the command, and one where we
explicitly call `sudo`. The latter is recommended, but for trivial commands the
former should work.

  var shell = require('polyshell').shell;
  var host = shell('example.com');

  host.sudo("ls");
  host.run 'sudo tail /var/log/auth.log | grep root';


The example above runs two shells concurrently on the same shell object. One
of the commands will detect a `sudo` prompt, ask for password, save the password
in a cache and feed the password to the remote server. The other command will
detect a `sudo` request, then detect that the other shell is already pending for
user input and wait for the result, then access the cached password and send
it to the server.

Note that on some systems, the remote end will have a `sudo` timeout so the
second command will not need to ask for a password, while others will.

We can also set the password explicitly if we dare to have it accessible in a
script. This will preload the cache and the first command detecting a `sudo`
prompt will try the cached password first before falling back to asking the
user:

    var shell = require('polyshell').shell;
    var host = shell('example.com');
    
    host.setPassword("xyzzy");
    host.sudo("ls");

We can also explicitly ask the user for a password before detecting a sudo
prompt and then cache the password for later use. When a shell eventually
detects a `sudo` prompt, it will first try the cached password before asking the
user:

    var shell = require('polyshell').shell;
    var host = shell('example.com');

    host.promptPassword();
    host.sudo("ls", function(err) { if(err) { host.resetPassword(); } });

In the above example, we have chosen to reset the password after the shell returns.

## Shell API

### shell([host | options])

Creates a new shell object, but does not run anything or consume any
significant resources. Holds configuration data needed to start a local shell,
or a remote shell. Also holds information for password caching:

    var shell = require('polyshell').shell;
    var local = shell();
    var host1 = shell({ host: "example.com", log: true });
    var host2 = shell("example.com");

If neither `host` nor `options` are given, a local shell is created. Note that
`localhost` is not a local shell, but rather ssh access to the local system.

`host` : the name of the host. Typically matches an entry in .ssh/config with
user name and other real host domain or IP address. 'host' is also used as the
default shell name which is used for logging purposes and can be overridden in
options.

`options`:

- `options.args`: (a string or array of strings), optional extra
  arguments to ssh before the command to execute (these arguments are
  for ssh, not the command being run by ssh).

- `options.captureLimit`: amount of output to capture in buffers given
  to `shell.run` callback -- see `shell.run`. Defaults to 64K.
  No output is captured when `options.captureLimit = 0`.
  All output is streamed to `option.outStream` or `process.stdout`
  regardless.

- `options.issuer`: optional name used for logging, overrides `host`
  and `name` for this purpose. Set by job control when creating a
  shell for a job action with the actions `this.issuer` property. -
  `options.log`: optional true to enable logging (set by job controls
  log setting for job action shells).
  
- `options.logStream`: Like `options.outStream` for logging. Only used when
  `options.log` is true.

- `options.name`: optional informative system name used for logging
  (not a user name for remote login).

- `options.outStream`: optional stream object that must be an object with
  function named write taking a buffer as argument, for example:
  `var devnull = { write: function(buffer) {} };`
  Node.js WritableStreams can also be used. Does not capture `sudo` password
  prompts which are always directed to `process.stdout`.
    
- `options.passwordCache`: enables sharing of passwords between
  multiple shells - see `Password Agents`.

- `options.port`: integer port number for ssh if not the standard port
  22 (can also be set in `.ssh/config`).

- `options.sh`: optional name for the shell to use instead of the
  environment SHELL variable.

- `options.silent`: redirect the output stream to nothing, also
  when `outStream` has been set.

- `options.ssh`: optional alternative ssh command to use for remote
  access.

- `options.user`: optional user name for ssh (can also be set in
  `.ssh/config`).

### shell.run(cmd, [callback(err, capture())])

`cmd` : a command string to be executed by a local or remote shell. If given
as array, the individual commands are joined by ' && ' before being given to
the ssh command - no real magic or extra parsing here.

`callback(err, capture)` : optional callback to know when the shell has completed.
Especially useful under job control to ensure that a job action does not
complete before the shell does, and that the action fails if the shell does.
If shell is created with `option.captureLimit = 0`, capture returns the empty string,
otherwise up to `options.captureLimit` bytes of buffered output, or default 64K.
If no callback is given, the shell continues as a background process and no output
is captured (but still streamed to the shells output stream).
`capture` is a function that converts captured buffers to a string:
`var myoutputstring = capture()`.
The callback is compatible with the callback acquired by job actions
`this.async()`.

If the shell command begins with "sudo", "sudo" is stripped from the command and
the rest is passed on to the `shell.sudo` helper command.

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

### shell.sudo(cmd, [callback(err, capture())])

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

### shell.log

Enable logging by setting value to true.
Reflects `options.log` pass when shell was created.

### shell.passwordCache

property equal to assigned options.passwordCache, or a internally created
password cache object if none were provided. The property can be used to
initialise new shells that should share the same password.
