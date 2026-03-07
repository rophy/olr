"""Pytest configuration for OLR tests."""

import os
import re
import glob

import pytest

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
INPUTS_DIR = os.path.join(TESTS_DIR, "sql", "inputs")

# Tags parsed from SQL input files, keyed by scenario name
_TAG_CACHE = {}


def _parse_sql_tags(scenario):
    """Parse @DDL, @TAG, and .rac.sql markers from SQL input files."""
    if scenario in _TAG_CACHE:
        return _TAG_CACHE[scenario]

    tags = set()
    sql_files = []

    # Single-file inputs
    for ext in [".sql", ".rac.sql"]:
        path = os.path.join(INPUTS_DIR, scenario + ext)
        if os.path.isfile(path):
            sql_files.append(path)
            if ext == ".rac.sql":
                tags.add("rac")

    # Split-dir inputs
    for name in ["setup.sql", "test.sql"]:
        path = os.path.join(INPUTS_DIR, scenario, name)
        if os.path.isfile(path):
            sql_files.append(path)

    for path in sql_files:
        with open(path) as f:
            for line in f:
                if m := re.match(r"^-- @TAG\s+(\S+)", line):
                    tags.add(m.group(1))
                elif re.match(r"^-- @DDL\b", line):
                    tags.add("ddl")

    _TAG_CACHE[scenario] = tags
    return tags


def _fixture_to_scenario(fixture_name):
    """Extract scenario name from fixture name (strip environment suffix)."""
    # e.g. "basic-crud-free-23" -> "basic-crud"
    for sql_file in glob.glob(os.path.join(INPUTS_DIR, "*.sql")):
        name = os.path.basename(sql_file).removesuffix(".rac.sql").removesuffix(".sql")
        if fixture_name.startswith(name):
            return name
    for d in glob.glob(os.path.join(INPUTS_DIR, "*/test.sql")):
        name = os.path.basename(os.path.dirname(d))
        if fixture_name.startswith(name):
            return name
    return fixture_name


def discover_fixtures():
    """Find all fixture directories with expected output."""
    fixtures = []
    for base in ["fixtures", "sql/generated"]:
        base_dir = os.path.join(TESTS_DIR, base)
        if not os.path.isdir(base_dir):
            continue
        for entry in sorted(os.listdir(base_dir)):
            expected = os.path.join(base_dir, entry, "expected", "output.json")
            if os.path.isfile(expected):
                fixtures.append((base, entry))
    return fixtures


def discover_scenarios():
    """Find all SQL scenario input files."""
    scenarios = set()
    # Single-file: *.sql and *.rac.sql
    for sql_file in glob.glob(os.path.join(INPUTS_DIR, "*.sql")):
        name = os.path.basename(sql_file)
        name = name.removesuffix(".rac.sql").removesuffix(".sql")
        scenarios.add(name)
    # Split-dir: */test.sql
    for test_sql in glob.glob(os.path.join(INPUTS_DIR, "*/test.sql")):
        name = os.path.basename(os.path.dirname(test_sql))
        scenarios.add(name)
    return sorted(scenarios)


def pytest_addoption(parser):
    """Add custom CLI options."""
    parser.addoption(
        "--oracle-env",
        default=os.environ.get("ORACLE_TARGET", "free-23"),
        help="Oracle environment name (default: free-23)",
    )
    parser.addoption(
        "--oracle-driver",
        default=os.environ.get("ORACLE_DRIVER", "docker"),
        help="Oracle driver: docker, local, rac (default: docker)",
    )


@pytest.fixture(scope="session")
def oracle_env(request):
    return request.config.getoption("--oracle-env")


@pytest.fixture(scope="session")
def oracle_driver(request):
    return request.config.getoption("--oracle-driver")


def pytest_collection_modifyitems(config, items):
    """Auto-apply markers based on SQL input file tags."""
    for item in items:
        if not hasattr(item, "callspec"):
            continue
        # Try fixture_name (test_fixtures) or scenario (test_generate)
        name = item.callspec.params.get(
            "fixture_name",
            item.callspec.params.get("scenario", ""),
        )
        scenario = _fixture_to_scenario(name)
        tags = _parse_sql_tags(scenario)
        for tag in tags:
            item.add_marker(getattr(pytest.mark, tag))
