# percona-distribution-mysql-ps

Percona Distribution for MySQL (Percona Server-based) packaged as a
strict-confinement snap: Percona Server for MySQL plus the best components
from the Percona ecosystem, all tested to work together — Percona
XtraBackup for hot physical backups, MySQL Router and MySQL Shell for
InnoDB Cluster workflows, ProxySQL for SQL-aware load balancing,
Orchestrator for replication topology management, and the full Percona
Toolkit — staged unmodified from Percona's official apt repository at
`repo.percona.com`, nothing compiled from source. Two major versions are
published as separate branches/tracks, each pinned to an exact upstream
package version (see below). Base: `core26`.

## Why this snap

Installing this snap gets the entire Percona Distribution for MySQL stack
in one artifact instead of assembling server, backup, routing, proxy, and
topology tooling from separate packages, with every component pinned to
an exact upstream version. The install hook runs `mysqld --initialize`,
switches `root@localhost` to `auth_socket` authentication, and starts the
server automatically — there is no separate bootstrap step. ProxySQL,
MySQL Router, and Orchestrator ship as disabled daemons you opt into with
`snap start` when you need them. Each supported major (8.4, 9.7) is a
distinct branch/track, so moving to a new major is an explicit channel
switch rather than something the snap decides for you on refresh.

## Tracks and branches

| Branch | apt source | Version |
|---|---|---|
| `8.4/edge` | `repo.percona.com/pdps-84-lts/apt` (resolute, main) | 8.4.11-11 |
| `9.7/edge` | `repo.percona.com/pdps-97-lts/apt` (resolute, main) | 9.7.1-1 |

The two tracks differ in more than the core version pin:

- **ProxySQL**: `proxysql2` (2.7.3) on 8.4, `proxysql3` (3.0.9) on 9.7.
- **XtraBackup**: `percona-xtrabackup-84` (8.4.0-6, GA) on 8.4;
  `percona-xtrabackup-97` on 9.7 is currently a release candidate
  (9.7.1~rc1).
- **Percona Toolkit**: not yet published to `pdps-97-lts`'s `resolute`
  suite, so the 9.7 track pulls the identical `percona-toolkit` package
  (3.7.1-4) from the 8.4 distribution repo instead. The toolkit is a
  MySQL-version-agnostic client-side utility with no dependency on
  `percona-server`/`libperconaserverclient`, so this is safe.

## Getting the snap

### From a CI build

Every push to a `*/edge` branch, every pull request, and every manual
`workflow_dispatch` run of the `Tests` workflow builds the snap (amd64 and
arm64) and runs the full spread suite against it.

1. Open the workflow run in GitHub Actions and download the
   `snap-packages` artifact.
2. Unzip it.
3. Install:
   ```
   sudo snap install ./percona-distribution-mysql-ps_<version>_amd64.snap --dangerous --jailmode
   ```
   (substitute the `arm64` filename on that architecture).

### From source

```
git clone https://github.com/EvgeniyPatlan/percona-distribution-mysql-ps-snap.git
cd percona-distribution-mysql-ps-snap
git checkout 8.4/edge   # or 9.7/edge
snapcraft pack
sudo snap install ./percona-distribution-mysql-ps_*.snap --dangerous --jailmode
```

Requires the `snapcraft` and `lxd` snaps.

Store channels exist for each track (`8.4/edge`, `9.7/edge`), but the
release workflow only publishes when the repository's `RELEASE_ENABLED`
variable is set, so Store availability isn't guaranteed.

## First steps

`mysqld` starts automatically on install. The install hook switches
`root@localhost` to `auth_socket` authentication, so connect locally
without a password:

```
sudo percona-distribution-mysql-ps.mysql -u root
```

A TCP connection as `root@localhost` is denied by design — `auth_socket`
only accepts the local Unix socket — so create a dedicated user with a
password for TCP/network access. The RocksDB storage engine ships ready
to enable:

```
sudo percona-distribution-mysql-ps.ps-admin --enable-rocksdb -u root
```

## Services and apps

| App | Kind | Purpose |
|---|---|---|
| `mysqld` | daemon, auto-started | Percona Server, run under a supervisor loop that re-execs on the SQL `RESTART` statement (exit code 16) |
| `mysql` | CLI | interactive/batch SQL client |
| `mysqladmin` | CLI | server administration (ping, status, shutdown, …) |
| `mysqlcheck` | CLI | table check/repair/analyze/optimize |
| `mysqldump` | CLI | logical backup |
| `mysqlimport` | CLI | load delimited text files |
| `mysqlshow` | CLI | list databases/tables/columns |
| `mysqlslap` | CLI | load-testing/benchmark tool |
| `ps-admin` | CLI | Percona Server admin helper (e.g. enabling RocksDB) |
| `xtrabackup` | CLI | hot physical backup/restore |
| `xbstream` | CLI | XtraBackup stream (de)serialization |
| `xbcloud` | CLI | upload/download XtraBackup images to/from cloud storage |
| `xbcrypt` | CLI | encrypt/decrypt XtraBackup stream files |
| `mysqlsh` | CLI | MySQL Shell (JS/Python/SQL, InnoDB Cluster admin) |
| `mysqlrouter` | CLI | ad-hoc MySQL Router invocation |
| `mysqlrouter-service` | daemon, disabled by default | MySQL Router, connection routing driven by its config file |
| `mysqlrouter-passwd` | CLI | manage MySQL Router's REST-API password file |
| `proxysql` | daemon, disabled by default | ProxySQL SQL-aware proxy/load balancer |
| `proxysql-admin` | CLI | ProxySQL admin helper |
| `proxysql-status` | CLI | ProxySQL status/health reporting |
| `orchestrator` | daemon, disabled by default | replication topology manager, web UI + API on `:3000` |
| `orchestrator-client` | CLI | Orchestrator CLI client (defaults to the local daemon's API) |
| `pt-align` … `pt-visual-explain` | CLI (42 tools) | Percona Toolkit utilities, run as `percona-distribution-mysql-ps.pt-<tool>` |

`mysqld` is the only daemon enabled by default:

```
sudo snap stop percona-distribution-mysql-ps.mysqld
sudo snap start percona-distribution-mysql-ps.mysqld
sudo snap restart percona-distribution-mysql-ps.mysqld
```

`mysqlrouter-service`, `proxysql`, and `orchestrator` ship
`install-mode: disable` — they exist on disk after install but are not
running until you `snap start` them.

## Configuration and data paths

| Item | Path |
|---|---|
| Read-only defaults | `/snap/percona-distribution-mysql-ps/current/etc/my.cnf` (`!includedir` pulls in the directory below) |
| Editable mysqld config | `/var/snap/percona-distribution-mysql-ps/current/etc/mysqld.cnf` |
| MySQL Router config | `/var/snap/percona-distribution-mysql-ps/current/etc/mysqlrouter/` (empty until you drop in a `mysqlrouter.conf`) |
| ProxySQL config | `/var/snap/percona-distribution-mysql-ps/current/etc/proxysql/proxysql.cnf` (seeded on install; kept out of the directory above because mysqld's `!includedir` would try to parse ProxySQL's brace-block syntax as an ini file and refuse to start) |
| Orchestrator config | `/var/snap/percona-distribution-mysql-ps/current/etc/orchestrator.conf.json` |
| Data directory | `/var/snap/percona-distribution-mysql-ps/common/data` (survives snap refreshes) |
| Error log | `/var/snap/percona-distribution-mysql-ps/current/log/error.log` |
| Slow / general / binlog logs | `/var/snap/percona-distribution-mysql-ps/current/log/{mysql-slow,query,mysql-bin}.log` (disabled by default; uncomment the relevant lines in `mysqld.cnf`) |
| MySQL socket | `/var/snap/percona-distribution-mysql-ps/current/run/mysqld.sock` |
| X Protocol socket | `/var/snap/percona-distribution-mysql-ps/current/run/mysqlx.sock` (port 33060) |
| ProxySQL data dir | `/var/snap/percona-distribution-mysql-ps/common/proxysql` |
| Orchestrator sqlite dir | `/var/snap/percona-distribution-mysql-ps/common/orchestrator` |
| `mysql-files` dir | `/var/snap/percona-distribution-mysql-ps/common/var/lib/mysql-files` |

## Taking a hot backup with XtraBackup

```
sudo percona-distribution-mysql-ps.xtrabackup --backup -u root \
  -S /var/snap/percona-distribution-mysql-ps/current/run/mysqld.sock \
  --datadir=/var/snap/percona-distribution-mysql-ps/common/data \
  --target-dir=/var/snap/percona-distribution-mysql-ps/common/backup
sudo percona-distribution-mysql-ps.xtrabackup --prepare \
  --target-dir=/var/snap/percona-distribution-mysql-ps/common/backup
```

To restore: stop `mysqld`, empty the data directory, then
`xtrabackup --copy-back --target-dir=<backup dir> --datadir=<data dir>`
before restoring ownership on the data directory and starting `mysqld`
again.

## ProxySQL quickstart

```
sudo snap start percona-distribution-mysql-ps.proxysql
```

The admin interface listens on `:6032` and the proxy interface on `:6033`,
both on **all interfaces**. The seeded config ships the default admin
credentials `admin:admin` — **change both before starting on a routable
host**. Config is seeded once, at
`/var/snap/percona-distribution-mysql-ps/current/etc/proxysql/proxysql.cnf`;
later changes go through the admin interface itself:

```
percona-distribution-mysql-ps.mysql -h127.0.0.1 -P6032 -uadmin -padmin \
  -e "INSERT INTO mysql_servers (hostgroup_id, hostname, port) VALUES (0, '127.0.0.1', 3306);
      LOAD MYSQL SERVERS TO RUNTIME;"
```

`proxysql-admin` needs `--proxysql-username`/`--proxysql-password` (or a
`proxysql-admin.cnf` passed via `--config-file`), and `proxysql-status`
needs `--login-file` or a `~/.my.cnf` — no default config is shipped for
either.

## Orchestrator quickstart

```
sudo snap start percona-distribution-mysql-ps.orchestrator
```

The web UI and API listen on `:3000` on **all interfaces with no
authentication by default** — restrict network access or set an
`AuthenticationMethod` in
`/var/snap/percona-distribution-mysql-ps/current/etc/orchestrator.conf.json`
before starting on a routable host. Discover an instance from the CLI
client, which defaults to the local daemon's API
(`http://127.0.0.1:3000/api`, override with `ORCHESTRATOR_API`):

```
percona-distribution-mysql-ps.orchestrator-client -c discover -i 127.0.0.1:3306
percona-distribution-mysql-ps.orchestrator-client -c clusters
```

## MySQL Router

Drop a `mysqlrouter.conf` into
`/var/snap/percona-distribution-mysql-ps/current/etc/mysqlrouter/`, then
start the service:

```
sudo snap start percona-distribution-mysql-ps.mysqlrouter-service
```

Extra command-line options are passed via a `snap set` knob:

```
sudo snap set percona-distribution-mysql-ps mysqlrouter.extra-options="..."
```

Use `mysqlrouter-passwd` to manage a REST-API password file, and the
`mysqlrouter` app for one-off/ad-hoc invocations outside the daemon.

## Percona Toolkit

All 42 `pt-*` tools are exposed as individual snap commands, e.g.:

```
sudo percona-distribution-mysql-ps.pt-summary
sudo percona-distribution-mysql-ps.pt-query-digest \
  /var/snap/percona-distribution-mysql-ps/common/slow.log
```

Input files for the toolkit commands must live under
`/var/snap/percona-distribution-mysql-ps/common` — the snap cannot read
your home directory under strict confinement. Tools that need to
authenticate against this snap's own server (e.g. `pt-show-grants`) run
as the invoking user rather than through a `setpriv` wrapper, so use
`sudo` when the target account (such as `root`) relies on `auth_socket`.

## Testing

Every push and pull request runs the full spread suite against a real
snapd install inside an LXD `ubuntu-24.04` VM, on both `amd64` and
`arm64`. Suites: `aliases`, `backup_restore`, `cli_mysqladmin`,
`cli_mysqlcheck`, `cli_mysqlcli`, `cli_mysqldump`, `cli_mysqlimport`,
`cli_mysqlshow`, `cli_mysqlslap`, `daemon_mysqld`, `orchestrator_service`,
`proxysql_service`, `rocksdb`, `router_service`, `smoke`, `storage`,
`toolkit_cli`, and `upgrade` (currently marked `manual` until the snap is
published to `8.4/edge`).

To reproduce locally:

```
snapcraft pack
CRAFT_ARTIFACT=$(pwd)/percona-distribution-mysql-ps_<version>_amd64.snap spread -v
```

(`spread` from `go install github.com/canonical/spread/cmd/spread@latest`;
needs the `lxd` snap.)

## License

The snap packaging is Apache-2.0. Upstream component licenses (Percona
Server for MySQL, XtraBackup, MySQL Router, MySQL Shell, ProxySQL,
Orchestrator, Percona Toolkit, and their runtime dependencies) are
shipped under `licenses/` inside the snap.
