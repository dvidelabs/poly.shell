## Environments

### envs()

    var envs = require('polyshell').envs();

Creates a generic role based environments collection useful for various
purposes. See [`sites()`](sites.html) for an example use of the `envs()` module.

A sites collection is simply an enviroments collection interpreted in a special way:

    var sites = require('polyshell').sites();

    // the above is equivalent to:

    var envs = require('polyshell').envs();
