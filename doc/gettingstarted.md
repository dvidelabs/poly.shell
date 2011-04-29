## Getting Started

A basic example running multiple shells on two sites; here two different locations
on the same host to simplify the setup.

Configure `.ssh/config` to point `example.com` to a real test server. You can
also remove the 'host: 'example.com' setting altogether to run on your local
system, or remove the host setting altogether to run in a local shell:

    jobs = require('polyshell').jobs();

    jobs.sites.add('test', 'app-role', { host: 'example.com', testpath: 'tmp/jobstest/t1' });
    jobs.sites.add('test2', 'app-role', { host: 'example.com', testpath: 'tmp/jobstest/t2' });

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
        "echo grettings from: " + this.site.name + "running on host: " + this.site.host,
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

