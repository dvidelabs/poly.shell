pkg = require('..')
jobs = pkg.jobs()
sites = jobs.sites

sites.add('example', ['role1', 'testrole'], { host: 'example.com' });
jobs.add('onlyforexample', 'example', [function (){}, function(){}]);
jobs.add('example', function () {
   // This is an action function with this pointer set to a job action
   // object with facilities like shell, report, etc.
   // Add a job named 'example' matching sites in role 'example' which
   // in this case is exactly the site named 'example',
   // which has the hostname 'example.com'
   // (which could be configured in your .shh/config file).
   // This action has a globally unique id and access to a remote shell:
   this.report("my id " + this.id + " should match the report log id");
   this.shell.run("ls -lort /tmp | tail");
});
jobs.add('myjob', ['role1', 'role2'], function() { /* my action */ });
jobs.add('testjob', 'testrole', function() {
  this.shell.run([
    "mkdir -p ~/tmp",
    "echo hello " + this.site.name + "> ~/tmp/" + this.job + "-" + this.batch + ".log",
    ]); });
// ...
// run jobs with full log output
jobs.run(['myjob', 'testjob'], { log: true }, function () {
   // this is a schedule object, not a job action object like above,
   // so no shell, but still a report facility amongst others.
  this.report("all jobs completed");
});
// only dump reporting and error messages
jobs.run(['myjob', 'testjob'], { report: true }, function () {
  this.report("all jobs completed");
});
// only dump error messages
jobs.run(['myjob', 'testjob'], function () {
  /* all jobs completed */
});
// don't even dump that
jobs.run(['myjob', 'testjob'], { quiet: true }, function () {
  /* all jobs completed */
});

// jobs can be scheduled in different ways,
// and actions can acquire callbacks using this.async().
//
// See also Jobs class and test/jobs.

