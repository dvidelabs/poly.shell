_ = require 'underscore'
util = require './util'

class Environments
  constructor: () ->
    @_env = {}
    @_roles = {}

  # Add new environent or update existing.
  #
  # `names` : env name or (nested) array of env names
  # `roles` : optinal role name or (nested) array of role names
  # `merge` : optional merge function when env exists, defaults to _.extend
  # An env implicitly becomes a member of the role with its own name.
  # An env has a reserved `name` property that cannot be overridden
  # (this is managed when the env is read).
  #
  # If a env already exists, the named settings replace existing properties at top level
  # and other top level properties remain untouched. Properties are not otherwise merged.
  # 
  # A new env is given its own name as role and optionally other specified role names.
  # an existing env is optionally added to new roles while keeping existing roles.
  #
  # This examples assume an env represents a site used for deployment,
  # but that is just one use case:
  #
  # examples :
  #
  #   sites = new Environments()
  #   sites.add(['host1', 'host2'], ['db', 'admin'], { path: '~/example', comment: "hosts defined in .ssh/config" });
  #   sites.add('test-host', { path: "/tmp", user: "test", host: "0.0.0.0" });
  #   sites.add('app.example.com');
  #
  add: (names, roles, env, merge) ->
    if typeof env == 'function'
      merge = env
      env = null
    if typeof roles == 'function'
      merge = roles
      roles = null
    if roles and (typeof roles) is 'object' and not (roles instanceof Array)
      env = roles
      roles = []
    names = _.flatten [names or []]
    roles = _.flatten [roles or []]
    for name in names
      e = @_env[name]
      if e
        unless merge
          merge = _.extend
        merge(e, env) if env
        e.name = name
      else
        if env
          @_env[name] = e = _.clone env
          e.name = name
        else
          @_env[name] = { name }
        # add env name as a role
        util.pushmap @_roles, name, name
      for role in roles
        util.pushmap @_roles, role, name

  # Returns an array of names that belong the given role.
  # Optionally filter by roles in second argument unless filter is null.
  # (in effect find the intersection of both role sets)
  list: (roles, filter) ->
    roles = _.flatten [roles]
    rs = @_roles
    names = _.flatten(_.map(roles, (r) -> rs[r] or []))
    if filter
      filter = _.flatten [filter]
      filternames = _.flatten(_.map(filter, (r) -> rs[r] or []))
      names = _.intersect(names, filternames)
    return _.uniq(names)

  # Finds all names in the left hand roles and update these
  # with new roles and env properties, similar to `add`.
  #
  # examples (using env to represent sites) :
  #
  #  sites = new Environments()
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
  update: (inroles, roles, env, merge) ->
    @add(@list(inroles), roles, env, merge)

  # Returns a copy of the environment object for a valid name, or null.
  get: (name) ->
    e = @_env[name]
    # underscore clones null to empty object
    if e then _.clone(e) else null

exports.envs = -> new Environments()
