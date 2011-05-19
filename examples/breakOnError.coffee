poly = require '..'

jobs = poly.jobs()
sites = jobs.sites


sites.add 'site-1', 'all'

jobs.add 'job-1', 'all', -> this.shell.run "ls2", this.async()
jobs.add 'job-2', 'all', -> this.shell.run "ls", this.async()
jobs.add 'job-3', 'all', -> this.shell.run "ls", this.async()

jobs.runSequential ['job-1', 'job-2', 'job-3'], { breakOnError: true, log:true }, (err) ->
  console.log err if err
  console.log "done"
