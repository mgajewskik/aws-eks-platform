"""Read-only access to the deployment named by the committed configuration.

Selected explicitly by `mise run verify-live`; never in CI.
"""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def run(*args, check=True):
    # stderr is left to pytest so a failing command explains itself.
    return subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, text=True, check=check)


@pytest.fixture(scope="session")
def terraform():
    return lambda *args, check=True: run("terraform", "-chdir=platform", *args, check=check)


@pytest.fixture(scope="session")
def target(tmp_path_factory):
    # Variables and locals only: no backend, state lock, or provider.
    config = tmp_path_factory.mktemp("config")
    for name in ("variables.tf", "locals.tf"):
        shutil.copy(ROOT / "platform" / name, config)
    expression = "jsonencode({account = var.account_id, region = var.region})"
    output = subprocess.run(["terraform", f"-chdir={config}", "console", f"-var-file={ROOT / 'platform/default.tfvars'}"],
                            input=expression, stdout=subprocess.PIPE, text=True, check=True).stdout
    return json.loads(json.loads(output))


@pytest.fixture(scope="session")
def aws(target):
    def call(*args):
        return json.loads(run("aws", *args, "--region", target["region"], "--output", "json").stdout)

    caller = call("sts", "get-caller-identity")["Account"]
    assert caller == target["account"], f"credentials are for account {caller}, not {target['account']}"
    return call
