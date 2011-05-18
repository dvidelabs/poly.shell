## Configuring Sites and Running Jobs

A basic example running multiple shells on two sites; here two different locations
on the same host to simplify the setup.

Configure `.ssh/config` to point `example.com` to a real test server. You can
also remove the 'host: 'example.com' setting altogether to run on your local
system, or remove the host setting altogether to run in a local shell:

    var jobs = require('poly').jobs();

    jobs.sites.add('test', 'app-role',
      { host: 'example.com', testpath: 'tmp/jobstest/t1' });
    jobs.sites.add('test2', 'app-role',
      { host: 'example.com', testpath: 'tmp/jobstest/t2' });

    jobs.add('init', 'app-role', function() {
      this.shell.run("mkdir -p " + this.site.path, this.async());
      // Broadcast test file location to other jobs on the same site:
      this.shared[this.site.name] = { testfile: this.site.path + "/hello.test" };
    });

    jobs.add('hello', 'app-role', function() {
      this.shell.run("echo hello world > "
        + this.shared[this.site.name].testfile, this.async());
    });

    jobs.add('world', 'app-role', function() {
      this.shell.run([
        "echo grettings from: " + this.site.name + "running on host: "
          + this.site.host,
        "cat " + this.shared[this.site.name].testfile
      ]);
      this.report("message delivered");
    });

    // Run batch with logging enabled:
    jobs.run(['init', 'hello', 'world'], { log: true });

`this.shared` is an empty global object that can be seen by all jobs running
in the same batch. The init job sets up a site specific testfile property in
this space.

By default, jobs run in site-sequential mode. This means that on each site, one
job completes before the next is started, but jobs on different sites run in
parallel. Other schedules available such as `jobs.runParallel`.

Notice that we do not explicitly pass a callback to each function given to
`jobs.add`. For example, the `world` job does not need a callback and we could
easily forget to call it if given as argument. Instead we acquire a callback
with the function `this.async()` when one is needed. This makes it simpler to
write simple actions. This model also makes it possible acquire multiple
callbacks so we can wait on both a shell and a database call, for example.

To report errors in an action, either call `this.async()(error)`, or use
`this.fail(error)`. If error is null, the action will not fail. When the
async() callback is given to the shell, the shell takes care of reporting
errors to that callback, but other parts of the action may still use `fail`
until the action completes.

See also `test/jobs.coffee`, `test`, `envs.coffee`, and the `examples` folder
for more inspiration.

## Simplified Deployment Example

    var jobs = require('poly').jobs();
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
      var status = {};
      var cb = this.async(); // hold next job until script completes
      this.shared[this.site.name] = status;
      this.shell.run("mydeployscript.sh", function(ec, capture) {
        status.ok = !ec;
        if(ec)
          this.site.adminAlert("deploy failed on " + site.name, capture.out());
        cb(); // don't fail here, next job should check status
      });

    jobs.add('snapshot', 'app', function() {

      // Use this.shared to convey information to other jobs
      var status = this.shared[this.site.name] || {};

      // We might as well do the grunt work locally on the remote site
      // using shell scripts, or perhaps even Node.js poly.shell scripts.
      var scripts = ["scripts/myinit", "scripts/mybackup"];

      if(status.ok)
        scripts.shift();
      else
        scripts.push("scripts/myrollback");

      // hold next job until script completes by acquiring a async callback
      this.shell.run(scripts, this.async());
    });

    jobs.add('update', 'app', function() {
      env = sites.get('local');
      // run two concurrent rsyncs, but don't run next job until
      // both rsyncs are done (this.async() adds refcount)
      this.shell.upload(env.scripts, "scripts", this.async());
      this.shell.upload(env.www, "www", this.async());
    });

    jobs.add('prepare', 'local', function() {
      console.log("todo checkout data into this.site.scripts and this.site.www");
    });

    // prepare data for upload on local system
    jobs.run('prepare', function() {
      // hold all jobs on all sites until we have prepared data for update
      // then run the following in sequence on each site,
      // but concurrently for all sites
      // ( in this example it will spawn 6 concurrent rsync commands )
      this.run(['update', 'snapshot', 'deploy', 'snapshot']);
    });

In the above script jobs execute in the default schedule
`site-sequential` meaning that jobs on different sites executes in
parallel, but in sequence on each site.

Sites are used to define a logical unit of configuration such that a
physical host can represent multiple sites - for example if a host
both operates a database and two different web domains.

Roles are used to name groups of sites in a server cluster. This makes
it easy to assign jobs to specific sites, and also to configure
multiple sites consistently with common settings.

Shells can redirect output, so it is possible to integrate the job
runner with a web application framework such as `Express` for
`Node.js`.

