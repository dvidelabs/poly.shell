jobs = require('..').jobs();

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
