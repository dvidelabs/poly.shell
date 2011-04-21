util = require './util'
_ = util._

# TODO:
# add a configuration for sharing passwords between sites
# such that the shells created by a job will share password cache.

class Sites
  @constructor: () ->
    @_sites = {}
    @_roles = []
    
  # Return array of sitenames that belong the given role.
  # Optionally filter by roles in second argument.
  # If filter is null, the filter is not applied.
  # If filter is an empty array, the result is an empty array.
  inRoles: (roles, filter) ->
    sites = _.map(roles, (r) -> @_roles[r]))
    if filter
      filtersites = _.map(filter, (r) -> _roles[r]))
      sites = _.intersect(sites, filtersites)
    return _.uniq(sites)

  # Add new sites or extend existing sites.
  #
  # `sites` : site name or (nested) array of sites names
  # `roles` : role name or (nested) array of role names
  #
  # A site implicitly becomes a member of the role with its own name.
  #
  # If a site already exists, the named settings replace existing settings.
  # Other settings remain untouched. The site as added to the new roles, if any,
  # but also remains a member of old roles.
  #
  # examples :
  #
  #   sites.add(['host1', 'host2'], ['db', 'admin'], { path: '~/example', comment: "hosts defined in .ssh/config" });
  #   sites.add('test-host', { path: "/tmp", user: "test", host: "0.0.0.0" });
  #   sites.add('app.example.com');
  #
  add: (sites, roles, config) ->
    if typeof roles is 'object'
      config = roles
      roles = []
    sites = _.flatten [sites or []]
    roles = _.flatten [roles or []]
    for sitename in sites
      site = @_sites[sitename]
      if site
        _.extend(site, config) if config
      else
        if config
          @_site[sitename] = _.extend({ name: sitename}, config)
        else
          @_site[sitename] = { name: sitename }
        util.pushmap @_roles, sitename, sitename
      for role in roles
        util.pushmap @_roles, role, sitename

  # Finds all sites in the left hand roles and extends these
  # with new roles and configuration settings, similar to `add`.
  #
  # examples :
  #
  #  # set backup path for all sites that are in db or www role.
  #  sites.configure(['db', 'www'], { backupPath: "./backup" });
  #
  #  # make all sites in www and test-www roles belong to the deploy role
  #  # to simplify deployment ops later on.
  #  sites.extend(['www', test-www'], 'deploy');
  #
  extend: (lhRoles, rhRoles, config) ->
    @sites(@inRoles(lhRoles), rhRoles, config)

  # Returns the configuration object for a valid site name, or null.
  config: (site) -> @_sites[site]

exports.sites = -> new Sites()
