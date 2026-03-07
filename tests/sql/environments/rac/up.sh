#!/bin/bash
# RAC VM is managed externally — just verify it's reachable.
set -euo pipefail
SSH_KEY="$(cd "$(dirname "$0")/../../../.." && pwd)/oracle-rac/assets/vm-key"
HOST=192.168.122.248
echo "Checking RAC VM connectivity..."
ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$SSH_KEY" root@$HOST "echo 'RAC VM is reachable'" || {
    echo "ERROR: Cannot reach RAC VM at $HOST" >&2
    exit 1
}
