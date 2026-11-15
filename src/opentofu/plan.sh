#!/usr/bin/env bash
set -euo pipefail

umask 077
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
posse_load_environment
posse_load_plan_inputs

printf 'Server: %s in %s\nSSH allowed from: %s\n' "$TF_VAR_server_type" "$TF_VAR_location" "$TF_VAR_ssh_allowed_cidr"
printf '%s\n' 'Verify the SSH address matches the machine you will connect from.'

mkdir -p "$POSSE_REPO_ROOT/tmp/opentofu"
tofu -chdir="$POSSE_TOFU_DIR" init -input=false -lockfile=readonly
tofu -chdir="$POSSE_TOFU_DIR" plan -input=false -out="$POSSE_PLAN_FILE"