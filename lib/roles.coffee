_ = require('util')._


# early draft code ...
# a site must be a string
# and that string must map to a configuration object
# a site should be a valid role.

# a location is a hash of configuration keys

_roles = {}
_sites = {}

# rough, we should decide if roles reference other roles that can later
# be modified so it affects the referencing role
exports.addRole = (name, sites) ->
  roles[name] = _.flatten([_roles[name] or [], siteOrRoleNames])

# adding site multiple times extends it
exports.addSite = (name, cfg, roles) ->
  if cfg
    _cfg = _sites[name]
    if _cfg
      cfg = _.extend(_cfg, cfg)
    else
      _sites[name] = cfg
  
  for name in _.uniq(_.flatten(roles))
    role name, site
  

exports.sitesOfRoles = (roles, filter) ->
  sites = _.map(roles, (r) -> _roles[r]))
  if filter
    filtersites = _.map(roles, (r) -> _roles[r]))
    sites = _.intersect(sites, filtersites)
  return _.uniq(sites)

exports.siteConfig = (site) ->
  _sites[site]
  