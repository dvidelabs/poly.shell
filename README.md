# Polyshell - multi-site role based job scheduling with local and remote shells

Polyshell is primarily intended to administer server clusters, but it
can also be used to schedule other kinds of distributed computation, or
to just run simple shell commands.

Typical scenarios are to install new software, to monitor log files, to upload
new versions of web sites, and to verify that backup jobs have been completing
successfully.

The Capistrano and Vlad tools for Ruby on Rails are designed for these kind of
jobs. Polyshell is a lower level tool but forms a good foundation for performing
standard routines such as deploying a new version of a web site pulled from
the latest source control branch.

The basic idea is to define a set of named jobs with actions that can run
in sequence, in parallel, or some variation thereof, on multiple local and
remote sites using role names to aid configuration.

Polyshell can also be used as a convenient way to quickly run system
local shell commands:

    require('polyshell').shell().run("touch IWasHere");

or to run commands on a single remote system:

    require('polyshell').shell('example.com').run("ls");

For more complex work, `jobs()` provides a job control
system to define named jobs that can be assembled in different schedules
and run on multiples sites:

    var jobs = require('polyshell').jobs();
    var sites = jobs.sites;
    var email = { send: function(to, title, body) { console.log "implement this"; } };
    
    sites.add('local', { scripts: "~/repository/scripts", www: "~/stage/www" });
    sites.add('appsvr-busy', ['app', 'primary'], { host: "app1.example.com" });
    sites.add('appsvr-standby', 'app', { host: "app2.example.com" });
    
    sites.update('app', {
      admin: "admin@example.com",
      adminAlert: function(title, body) { email.send(this.admin, title, body); };
    });
    
    jobs.add('deploy', 'app', function() {
      var status = {}
      var cb = this.async(); // hold next job until script completes
      this.shared[this.site.name] = status;
      this.shell.run("mydeployscript.sh", function(ec, capture) {
        status.ok = !ec;
        if(ec)
          this.site.adminAlert("deploy failed on " + site.name, capture());
        cb(); // don't fail here, next job should check status
      });
    
    jobs.add('snapshot', 'app', function() {
      
      // Use this.shared to convey information to other jobs
      var status = this.shared[this.site.name] || {};
      
      // We might as well do the grunt work locally on the remote site
      // using shell scripts, or perhaps even Node.js polyshell scripts.
      var scripts = ["scripts/myinit", "scripts/mybackup"];
      
      if(status.ok)
        scripts.shift();
      else
        scripts.push("scripts/myrollback");
        
      // hold next job until script completes by acquiring a async callback
      this.shell.run(scripts, this.async());
    });
    
    put = function(from, to, cb) {
      var host = "";
      if(this.site && this.site.host)
        host = this.site.host + ":";
      shell().run("rsync -r " + from + " " + host + to, cb);
    }
    
    jobs.add('update', 'app', function() {
      env = sites.get('local');
      // run two concurrent rsyncs, but don't run next job until
      // both rsyncs are done.
      put(env.scripts, "scripts", this.async());
      put(env.www, "www", this.async());
    });
    
    jobs.add('prepare', 'local', function() {
      console.log("todo checkout data into this.site.scripts and this.site.www");
    }
    
    // prepare data for upload on local system
    jobs.run('prepare', function() {
      // hold all jobs on all sites until we have prepared data for update
      // then run the following in sequence on each site,
      // but concurrently for all sites
      // ( in this example it will spawn 6 concurrent rsync commands )
      this.run(['update', 'snapshot', 'deploy', 'snapshot']);
    }

In the above script jobs execute in the default schedule
`site-sequential` meaning that jobs on different sites executes in
parallel, but in sequence on each site.

Sites are used to define a logical unit of configuration such that a
physical host can represent multiple sites - for example if a host
both operates a database and two different web domains.

Roles are used to name groups of sites in a server cluster. This makes
it easy to assign jobs to specific sites, and also to configure
multiple sites consistently with common settings.

Shells are can redirect output, so it is possible to integrate the job
runner with a web application framework such as `Express` for `Node.js`.

## Installation

Download to some user local folder.

Enter folder and install locally (using npm 1.0.0):

    make install

(Or use npm 0.3.x directly without the makefile, not tested - notably the makefile has
some npm 1.0.0 specific references to the CoffeeScript compiler because CoffeeScript
as of this writing otherwise fails with the npm 1.0.0 module system.)

Test that things are ok (see warning below):

    make test

**Warning**: it may be that some tests happen to want to run on the host
`example.com`. This should not be the case - such logic should be elsewhere,
but just in case it slips: The tests may break because `example.com`
is an unknown host. If `example.com` has been pointed to a known host, the tests
might possibly create `tmp` folders, dump test files, and remove `tmp` folders on
your `example.com` server.

Tests normally dump files in a local tmp dir that is cleaned with `make clean`.

## CoffeeScript

Polyshell is written primarily in CoffeeScript, but that shouldn't change anything.
If, for some reason (including debugging), a JavaScript version is needed,
a JavaScript only module can be created in sub-folder using:

    make js

## Passwords

Polyshell does not support ssh password based account login. It is assumed that ssh
will use ssh keys without passwords, or with passwords managed by an external
agent such as `ssh-agent`.

Polyshell does, however, support `sudo` password prompts after ssh login. In the
basic form a shell detects a sudo prompt and issues a silent prompt to the
user console.

Since many processes may target the same site, and many sites may have the
same admin password, it is convenient to cache a password across sites.

This works by creating a password cache object that is stored in all site
configurations that are supposed to share a `sudo` passwords.

Shells can detect when another shell is prompting for a password and wait for
the user to enter the password, and otherwise start a password prompt when no
valid password is cached.

## Scheduling

The Polyshell job control scheduler is fairly simple. A schedule is an
array of job names which can be run in one the following modes:
`sequential`, `atomic`, `parallel`, or the default: `site-sequential`
where different jobs may run at the same time but each site will only
see one of the jobs at a time. These schedules can then be chained to
more complex scenarios if needed, and the same jobs can be reused in
different schedules. This model is somewhat similar to the various
Node.js async libraries like `seq`, `flow` and `async`, but with
role based job distribution, reporting, configuration, unique
identifiers, (remote) shell support, and password agents.

Polyshell has no dependency resolver, but it is possible to use
Polyshell inside a `Jakefile`, or in similar tools, or even in a
web framework like `Express`.

It is also possible to create new primitives such as context locks
that can be stored in site configurations or on the shared job object
space. Locking is known from database transaction schedulers and,
perhaps counterintuitively, implements a good scheduling algorithm.

The Polyshell password cache does something along these lines by using
a Node.js EventEmitter.
