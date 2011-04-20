# Concepts

Ploy is inspired by Vlad's remote task concept, but we try to extract a
general idea from various sources where Vlad is a simplification of the
deployment tool Capistrano.

Essentially there are four components:

1. dependent tasks (rake, make, jake, ...)
2. shell interaction (bash, sudo, ssh, rsync, streams, ...)
3. concurrent task sets (roles, remote hosts, ...)
4. configuration (deploy_to, scm_revision, ...)

We can define a shell abstraction to represent both local and remote hosts. We
can further abstract this such that a shell represents a location which is a
host and a path. A location is a configuration, shell is an actual
instantiation that makes it possible to execute commands at that location.

A location is generally defined by a host (possibly local), a user, and a
folder. Permissions is generally given by ssh keys for remote locations.

Locations are identified by name and grouped into roles. A location may belong
to multiple roles and roles may refer to other roles. When locations are
extracted from a set of roles, duplicates are removed by location name.

A job is a set of roles and a procedure to be executed on all associated
locations independently. The procedure includes a configuration environment
that also includes the location environment of any location the procedure is
applied to. The job also hold a set of prerequisite jobs.

A task is a job procedure applied to a single location. A task may have an
associated shell. A dependent job can start tasks before a prerequisite job
has completed all of its tasks. For execution, jobs are translate into
parallel trees of dependent tasks.

# Scheduling

This is early work, subject to change.

Unlike Rake and Vlad, Ploy does not schedule by dependencies. Instead jobs are
schedule by batches which can list sequential and parallel job execution.
The concept can be extended with named locks specific to a location or to a
role set. Locks happen to implement an efficient scheduling algorithm as known
from database transaction theory. This needs to be further developed since we
have multiple tasks in a single job and it is not clear have to clearly specify
who waits on what. The same problem applies to Make style dependencies when
adding multiple tasks to a job.
