#!/usr/bin/env bash

POSSE_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POSSE_TOFU_DIR="$POSSE_REPO_ROOT/src/opentofu"
POSSE_PLAN_FILE="$POSSE_REPO_ROOT/tmp/opentofu/posse.tfplan"

posse_load_environment() {
  local token

  token="${HCLOUD_TOKEN:-}"
  if [[ -z "$token" ]]; then
    token="$(yq -er '.hetzner.token | select(type == "string" and length > 0)' "$POSSE_REPO_ROOT/tmp/keys.yml")" || return 1
  fi

  HCLOUD_TOKEN="$token"
  TF_DATA_DIR="$POSSE_REPO_ROOT/tmp/opentofu/tofu-data"
  export HCLOUD_TOKEN TF_DATA_DIR
}

posse_load_plan_inputs() {
  local primary_ipv4 public_key agent_keys ssh_client_ip ssh_comment

  primary_ipv4="${TF_VAR_primary_ipv4:-}"
  if [[ -z "$primary_ipv4" ]]; then
    primary_ipv4="$(yq -er '.hetzner.ip.primary | select(type == "string" and length > 0)' "$POSSE_REPO_ROOT/tmp/keys.yml")" || return 1
  fi

  public_key="${TF_VAR_ssh_public_key:-}"
  if [[ -z "$public_key" ]]; then
    ssh_comment="${POSSE_SSH_KEY_COMMENT:-lakruzz@Lakruzz-MacBook-Air.local}"
    agent_keys="$(ssh-add -L)" || return 1
    public_key="$(printf '%s\n' "$agent_keys" | awk -v comment="$ssh_comment" '$3 == comment {print}')"
  fi
  if [[ -z "$public_key" || "$public_key" == *$'\n'* ]]; then
    printf '%s\n' 'Expected exactly one matching SSH public key.' >&2
    return 1
  fi

  if [[ -z "${TF_VAR_ssh_allowed_cidr:-}" ]]; then
    ssh_client_ip="$(curl -4 -fsS https://api.ipify.org)" || return 1
    if [[ -z "$ssh_client_ip" ]]; then
      printf '%s\n' 'Could not determine the SSH client IPv4 address.' >&2
      return 1
    fi
    TF_VAR_ssh_allowed_cidr="${ssh_client_ip}/32"
  fi

  TF_VAR_primary_ipv4="$primary_ipv4"
  TF_VAR_ssh_public_key="$public_key"
  TF_VAR_location="${TF_VAR_location:-hel1}"
  TF_VAR_server_type="${TF_VAR_server_type:-cpx12}"
  export TF_VAR_primary_ipv4 TF_VAR_ssh_public_key TF_VAR_ssh_allowed_cidr
  export TF_VAR_location TF_VAR_server_type
}