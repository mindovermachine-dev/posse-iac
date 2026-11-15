#!/usr/bin/env bash
set -euo pipefail

umask 077
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
posse_load_environment
posse_load_plan_inputs

mkdir -p "$POSSE_REPO_ROOT/tmp/opentofu"
tofu -chdir="$POSSE_TOFU_DIR" init -input=false -lockfile=readonly
tofu -chdir="$POSSE_TOFU_DIR" destroy