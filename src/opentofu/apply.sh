#!/usr/bin/env bash
set -euo pipefail

umask 077
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
posse_load_environment

if [[ ! -f "$POSSE_PLAN_FILE" ]]; then
  printf '%s\n' 'No saved plan found. Run plan.sh and review the plan first.' >&2
  exit 1
fi

mkdir -p "$POSSE_REPO_ROOT/tmp/opentofu"
tofu -chdir="$POSSE_TOFU_DIR" init -input=false -lockfile=readonly
tofu -chdir="$POSSE_TOFU_DIR" show -no-color "$POSSE_PLAN_FILE"
printf '%s\n' 'Applying this plan creates or changes billable resources.'
read -r -p 'Type apply to continue: ' confirmation
if [[ "$confirmation" != apply ]]; then
  printf '%s\n' 'Apply cancelled.'
  exit 1
fi

tofu -chdir="$POSSE_TOFU_DIR" apply -input=false "$POSSE_PLAN_FILE"