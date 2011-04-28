### Password Agent

The password agent controls a single password, and also coordinates any number of
shell processes interested in that password.

Internally, a shell automatically creates a password agent if none is
provided. We can access such an agent and pass it on to new shells:


    shell = require('ploy').shell
    host1 = shell('host1.example.com');
    host2 = shell({ host: 'example.com', passwordCache: host.passwordCache });

or we can create an agent explicitly:

    ploy = require('ploy');
    shell = ploy.shell
    pwc = ploy.password.cache();
    
    host1 = shell({ host: 'host1.example.com', passwordCache: pwc);
    host2 = shell({ host: 'host2.example.com', passwordCache: pwc);

The explicit way can be useful in conjunction with the sites collection
to set up a shared passwordCache property for multiple sites. See also
`lib/password.coffee` if a custom password agent is needed - the interface
is fairly simple.

The hosts will in either case be sharing a password cache so the first `sudo`
prompt will block all other prompts and have the shell wait for the first
prompt to provide the answers.

