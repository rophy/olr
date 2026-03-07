# OpenLogReplicator

## Build

Prerequisites: Docker with BuildKit, docker compose.

```bash
# Dev build
make build

# Or manually
DOCKER_BUILDKIT=1 docker build -f Dockerfile.dev \
  --build-arg GIDOLR=$(id -g) --build-arg UIDOLR=$(id -u) \
  --build-arg WITHTESTS=1 \
  -t olr-dev:latest .
```

`Dockerfile.dev` splits dependencies into cached layers + uses ccache via
BuildKit cache mounts. Only the OLR compilation layer rebuilds on source changes
(~1-2 min with ccache warm, vs ~15 min cold).

## Tests

Tests use Google Test, fetched automatically via CMake FetchContent.

```bash
# Run redo log regression tests (no Oracle needed)
make test-redo

# Run SQL tests against live Oracle
make -C tests/sql/environments/free-23 up
make -C tests/sql/environments/free-23 test-sql
make -C tests/sql/environments/free-23 down
```

Pipeline tests run OLR in batch mode against captured redo log fixtures and
compare JSON output against golden files.

To generate fixtures, use `tests/sql/scripts/generate.sh` which runs SQL
scenarios against Oracle, captures redo logs, validates OLR output against
LogMiner, and saves golden files.
See [`tests/README.md`](tests/README.md) for details.
