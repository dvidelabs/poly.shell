util = require './util'
_ = util._

# TODO:
# add a configuration for sharing passwords between sites
# such that the shells created by a job will share password cache.

class Sites
  constructor: () ->
    @_sites = {}
    @_roles = {}

  # Add new sites or extend existing sites.
  #
  # `sites` : site name or (nested) array of sites names
  # `roles` : role name or (nested) array of role names
  #
  # A site implicitly becomes a member of the role with its own name.
  # The site config automatically gets the property { site: <sitename> }
  # If a `site` property is given, it will be ignored.
  #
  # If a site already exists, the named settings replace existing settings.
  # Other settings remain untouched. Settings are not otherwise merged.
  #
  # The site as added to the new roles, if any, but also remains a member of old roles.
  #
  # See also constructor for the Shell class, it will receive a site configuration
  # prior to running a job action.
  #
  # examples :
  #
  #   sites.add(['host1', 'host2'], ['db', 'admin'], { path: '~/example', comment: "hosts defined in .ssh/config" });
  #   sites.add('test-host', { path: "/tmp", user: "test", host: "0.0.0.0" });
  #   sites.add('app.example.com');
  #
  add: (sites, roles, config) ->
    if roles and (typeof roles) is 'object' and not (roles instanceof Array)
      config = roles
      roles = []
    sites = _.flatten [sites or []]
    roles = _.flatten [roles or []]
    if config
      # silently ignore custom site name
      delete config.site
    for sitename in sites
      site = @_sites[sitename]
      if site
        _.extend(site, config) if config
      else
        if config
          @_sites[sitename] = _.extend({ site: sitename}, config)
        else
          @_sites[sitename] = { site: sitename }
        util.pushmap @_roles, sitename, sitename
      for role in roles
        util.pushmap @_roles, role, sitename

  # Returns array of site names that belong the given role.
  # Optionally filter by roles in second argument.
  # If filter is null, the filter is not applied.
  # If filter is an empty array, the result is an empty array.
  inRoles: (roles, filter) ->
    roles = _.flatten [roles]
    rs = @_roles
    sites = _.flatten(_.map(roles, (r) -> rs[r] or []))
    if filter
      filter = _.flatten [filter]
      filtersites = _.flatten(_.map(filter, (r) -> rs[r] or []))
      sites = _.intersect(sites, filtersites)
    return _.uniq(sites)

  # Finds all sites in the left hand roles and update these
  # with new roles and configuration settings, similar to `add`.
  #
  # examples :
  #
  #  set backup path for all sites that are in `db` or `www` role:
  #
  #    sites.update(['db', 'www'], { backupPath: "./backup" });
  #
  #  make all sites that are currently in the `www` and `test-www` roles
  #  belong to the deploy role:
  #
  #    sites.update(['www', test-www'], 'deploy');
  #
  update: (lhRoles, rhRoles, config) ->
    @add(@inRoles(lhRoles), rhRoles, config)

  # Returns a copy of the configuration object for a valid site name, or null.
  config: (site) ->
    cfg = @_sites[site]
    return null unless cfg
    cfg.site = site # in case someone modified it
    _.clone(cfg)

exports.createSites = -> new Sites()
