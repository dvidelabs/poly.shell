## Environments

### envs()

    var envs = require('poly').envs();

Creates a generic role based environments collection useful for various
purposes. See [`sites()`](sites.html) for an example use of the `envs()` module.

A sites collection is simply an environments collection interpreted in
a special way:

    var sites = require('poly').sites();

    // the above is equivalent to:

    var envs = require('poly').envs();
