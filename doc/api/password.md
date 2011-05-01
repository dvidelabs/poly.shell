## Password Cache

### Password Sharing in Site Configurations

A shell always creates its own internal password agent that talks
to a password cache. By default the shell also creates its own password
cache to handle a single login scenario. But the shell may use a shared
password cache to participate in multiple login scenarios.

Here we use the default cache of one shell named `host1` and passes it
on to another shell named `host2`.

    shell = require('poly').shell
    var host1 = shell('host1.example.com');
    var host2 = shell({ host: 'example.com', passwordCache: host1.passwordCache });

We can also create a cache explicitly and pass it on to both hosts
with equal effect:

    poly = require('poly');
    shell = poly.shell
    pwc = poly.password.cache();
    
    host1 = shell({ host: 'host1.example.com', passwordCache: pwc);
    host2 = shell({ host: 'host2.example.com', passwordCache: pwc);

The hosts will in either case be sharing a password cache so the first
`sudo` prompt will block all other prompts and have the shell wait for
the first prompt to provide the answers.
