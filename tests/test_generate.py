"""SQL fixture generation tests — runs generate.sh per scenario against a live Oracle."""

import os
import subprocess

import pytest

from conftest import discover_scenarios

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
GENERATE_SH = os.path.join(TESTS_DIR, "sql", "scripts", "generate.sh")


def pytest_generate_tests(metafunc):
    if "scenario" in metafunc.fixturenames:
        metafunc.parametrize("scenario", discover_scenarios())


def test_generate(scenario, oracle_env, oracle_driver):
    """Run generate.sh for one scenario and assert it passes."""
    env = {
        **os.environ,
        "ORACLE_TARGET": oracle_env,
        "ORACLE_DRIVER": oracle_driver,
    }

    result = subprocess.run(
        [GENERATE_SH, scenario],
        env=env,
        capture_output=True,
        text=True,
        timeout=300,
    )

    # generate.sh exits 0 for both PASS and SKIP (tagged scenarios)
    if result.returncode == 0:
        if "SKIP:" in result.stdout:
            pytest.skip(result.stdout.strip().split("\n")[-1])
        return

    # Failure — show output for debugging
    msg = f"generate.sh failed for {scenario} (exit {result.returncode})\n"
    if result.stdout:
        msg += f"\n--- stdout ---\n{result.stdout[-2000:]}"
    if result.stderr:
        msg += f"\n--- stderr ---\n{result.stderr[-2000:]}"
    pytest.fail(msg)
