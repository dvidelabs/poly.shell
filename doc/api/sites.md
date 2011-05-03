## Sites Overview

Sites is a collection of named configurations (environments) that
provide information about a server. In addition to the stored
configuration, each site also belongs to one or more roles.

A minimal site configuration is empty for local servers and contains a
host name for remote servers.

Sites are used to initialise shell object and for job scheduling
through `poly.jobs().sites`. Sites can hold any kind of information
including complex objects, but the minimal, and typical usage, is to
store the host name that a shell should contact when running commands.

The host is typically configured in the file `.ssh/config`, but
otherwise `user` name and `port` number may also be configured to help
a shell connect to a host. See `poly.shell()`.

### Advanced configuration

Site configurations may hold non-trivial objects. For example, a
password cache can be stored in a site config under the name
`passwordCache` which will be used by shells detecting a `sudo`
prompt. The cache object not only stores a common password, but also
holds an EventListener that queues up all shells waiting for the same
password. The `jobs.sharedPassword` function sets up such a cache for
sites in the given roles.

## Sites Reference

### sites()

Creates a collection of environment objects indexed by name and organised
by roles:

    sites = require('poly').sites();

We use the term `site` loosely to reference a site name, the
configuration object of a site, or the physical location represented
by the name.

Note: `sites()` creates a generic environments collection with role
support. The environments collection can by used for a number of other
purposes:

    var sites = require('poly').sites();

    // the above is equivalent to:

    var envs = require('poly').envs();

### sites.add(names, [roles], [config], [merge])


    var sites = require('poly').sites();

    sites.add('example', 'test', { host: 'test.example.com' });
    sites.add('host1', { host: 'www1.example.com' });
    sites.add('host2', { host: 'www2.example.com' });
    sites.add('host1-admin', { host: 'www1.example.com',
      port: 8000, path: "sites/admin" });
    sites.add('local');

Sites are always organised into roles. In the above example the sites
are already added to the roles given by their own name. The `example`
site is also added to the `test` role.

We can add more roles later:

    // ...
    sites.add(['host1', 'host2'], ['www', 'deploy']);
    sites.add(['host1-admin', 'local'], 'admin');

`names` : a site name, or a (nested) array of sites names to be
created or updated. It is valid to add to an existing site. (Nesting
is just a convenience with no significance.)

`roles` : optional role name or (nested) array of role names. (Nesting
is just a convenience with no significance.). sites are assigned to
the listed roles if any. This makes it possible to reference a group
of sites by a single name. A site always belong to a role with the
same name as the site name to make it easy to target specific sites in
functions that only accept role names.

`config` : an optional configuration object (or environment if you
like) that is applied to all to all listed sites. The config is
**not** assigned to roles. Only those sites currently listed will
receive the configuration. If a site already exists, the configuration
object will be extended by adding new names to the old object, but
entirely overwriting old data where the top-level names conflict.
Configurations are always cloned so the input object will never be
changed by modifying a site, and sites added simultaneously will have
separate copies.

`merge` : an optional merge function that is applied if a config
object already exists. The default is to use the _.extend function
from the underscore library. `merge` has the form `merge(x, y)` where
`x` is the existing object that must be updated in-place, and `y` is
the new config object given as argument to `sites.add`.

A configuration object always has a property named 'name' which is
identical to the site name. It cannot be overridden, but it can be
changed for "personal" use without ill-effects after calling
`sites.get()`.


    var sites = require('poly').sites();

    sites.add('foo', { name: "bar", x: "1" });
    sites.get('foo');
      // => { name: "foo", "x: "1" }

    sites.add(['site1', 'site2'], { x: "1", y: "2" });
    
    sites.get('site1');
      // => { name: "site1", x: "1", y: "2" }
    sites.get('site2');
      // => { name: "site2", x: "1", y: "2" }

    sites.add('site2',
      { z: 3, info: { tags: [ "test", "online" ], timeout: 4000 } });
    
    sites.get('site1')
      // => { name: "site1", x: "1", y: "2" }
    sites.get('site2')
      // => { name: "site2", x: "1", y: "2", z: 3,
      //      info: { tags: [ "test", "online" ], timeout: 4000 } }
  
    sites.add('site2', { info: { tags: [ "busy" ] } });
    
    sites.get('site1');
      // => { name: "site1", x: "1", y: "2" }
    sites.get('site2');
      // => { name: "site2", x: "1", y: "2", z: 3,
      // info: { tags: [ "busy" ] } }

The above behaviour can be changed with a custom merge function.

### sites.get(name)

Returns a copy of the configuration currently stored for the named
site, or null if the site is not present.

`name` : name of site.

    var sites = require('poly').sites()
    
    sites.add('ex', 'www', { host: "app.example.com" });
    sites.get('ex');
      // => { name: 'ex', x: "1", y: "2" }
    sites.get('www');
      // => null
    sites.get('app.example.com');
      // => null
    sites.get(sites.list('www').shift());
      // => { name: 'ex', x: "1", y: "2" }

Any changes to an object returned by get will not have any effect on
the configuration stored in the sites collection.

### sites.list(roles, [filter])

Returns an array of matching site names. The result can be an empty
array, an array with one element, or a flat array with more elements.
There will be no duplicate site names.

`roles` : a role name or a (nested) array of role names. All sites
existing in at least one of the roles will be returned. If `roles` is
empty or null, an empty array is returned.

`filter` : an optional role name or a (nested) array of role names
similar to `roles`. If present a site must exist in both roles and
filter in order to be include in the result set. The filter is used by
the job controller to restrict the number of sites a job would
normally target.

### sites.update(inroles, [roles], [config], [merge])

A shorthand for `sites.add(sites.list(inroles), roles, config, merge)`;

Updates all sites in the given `inroles` simultaneously, but will
not create any new sites.

### jobs.sites

Sites are used by the job controller. The job controller automatically
creates a sites collection if one is not being passed when the job
controller is created:

    var jobs = require('poly').jobs();
    var sites = jobs.sites;

or, to share sites between different job controllers:

    var poly = require('poly');
    var sites = poly.sites();
    
    var jobs = poly.jobs(sites);
      // sites === jobs.sites
      
    jobs2 = poly.jobs(sites);
      // sites === jobs2.sites
