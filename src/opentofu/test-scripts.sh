#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/src/opentofu" "$fixture/tmp"
cp "$script_dir"/{env,plan,apply,destroy}.sh "$fixture/src/opentofu/"

export TEST_FIXTURE="$fixture" TEST_LOG="$fixture/commands.log"
unset HCLOUD_TOKEN TF_VAR_primary_ipv4 TF_VAR_ssh_public_key TF_VAR_ssh_allowed_cidr
unset TF_VAR_location TF_VAR_server_type

yq() {
  if [[ "$*" == *'.hetzner.token'* ]]; then
    printf '%s\n' 'test-token'
  else
    printf '%s\n' '192.0.2.10'
  fi
}

ssh-add() {
  [[ "${TEST_NO_PLAN_INPUTS:-}" != 1 ]] || return 1
  printf '%s\n' 'ssh-ed25519 test-key lakruzz@Lakruzz-MacBook-Air.local'
}

curl() {
  [[ "${TEST_NO_PLAN_INPUTS:-}" != 1 ]] || return 1
  printf '%s\n' '192.0.2.20'
}

tofu() {
  [[ "$HCLOUD_TOKEN" == test-token && "$TF_DATA_DIR" == "$TEST_FIXTURE/tmp/opentofu/tofu-data" ]] || return 1
  printf '%s\n' "$2" >> "$TEST_LOG"
  case "$2" in
    plan)
      [[ "$TF_VAR_server_type" == cpx12 && "$TF_VAR_location" == hel1 && "$TF_VAR_ssh_allowed_cidr" == 192.0.2.20/32 ]] || return 1
      : > "$TEST_FIXTURE/tmp/opentofu/posse.tfplan"
      ;;
    destroy)
      [[ "$*" != *-auto-approve* && "$*" != *-input=false* ]] || return 1
      ;;
  esac
}
export -f yq ssh-add curl tofu

bash "$fixture/src/opentofu/plan.sh" >/dev/null
if printf 'no\n' | TEST_NO_PLAN_INPUTS=1 bash "$fixture/src/opentofu/apply.sh" >/dev/null; then
  printf '%s\n' 'Apply should reject a missing confirmation.' >&2
  exit 1
fi
if grep -qx apply "$TEST_LOG"; then
  printf '%s\n' 'Apply ran without confirmation.' >&2
  exit 1
fi
printf 'apply\n' | TEST_NO_PLAN_INPUTS=1 bash "$fixture/src/opentofu/apply.sh" >/dev/null
grep -qx apply "$TEST_LOG"
bash "$fixture/src/opentofu/destroy.sh" >/dev/null
grep -qx destroy "$TEST_LOG"
printf '%s\n' 'Lifecycle script checks passed.'