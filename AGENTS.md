# OpenLogReplicator

## Build

Prerequisites: Docker with BuildKit, docker compose.

```bash
# Dev build
make build

# Or manually
DOCKER_BUILDKIT=1 docker build -f Dockerfile.dev \
  --build-arg GIDOLR=$(id -g) --build-arg UIDOLR=$(id -u) \
  -t olr-dev:latest .
```

`Dockerfile.dev` splits dependencies into cached layers + uses ccache via
BuildKit cache mounts. Only the OLR compilation layer rebuilds on source changes
(~1-2 min with ccache warm, vs ~15 min cold).

## Tests

```bash
# Run redo log regression tests (no Oracle needed)
make test-redo

# Run SQL tests against live Oracle
make -C tests/sql/environments/free-23 up
make -C tests/sql/environments/free-23 test-sql
make -C tests/sql/environments/free-23 down

# Archive generated fixtures for committing
make fixtures
```

**IMPORTANT:** SQL tests for different Oracle environments (free-23, xe-21, etc.)
must NOT run in parallel. They share the container name `oracle` to enforce this.
Run one environment at a time — bring it down before starting another.

Redo log tests run OLR in batch mode against captured redo log fixtures
(compressed as `tests/fixtures/*.tar.gz`, extracted on demand) and compare
JSON output against golden files.

To generate fixtures, use `tests/sql/scripts/generate.sh` which runs SQL
scenarios against Oracle, captures redo logs, validates OLR output against
LogMiner, and saves golden files.
See [`tests/README.md`](tests/README.md) for details.
