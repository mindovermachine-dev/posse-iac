# POSSE OpenTofu

This configuration describes an Ubuntu 24.04 Hetzner Cloud server for the POSSE
proof of concept, an operator SSH key, and a firewall. It attaches an existing
Primary IPv4 address and allows public HTTP and HTTPS, with SSH restricted to an
operator's IPv4 CIDR. The Primary IP remains managed separately from this
configuration.

K3s, ingress, Remark42, persistent application volumes, and backups are later
steps. Treat the host and its data as a proof of concept until persistence,
security, and recovery have been designed and tested.

## Before planning

Gather the following:

- A Hetzner Cloud API token with read and write access to the project containing
  the reserved Primary IP. Store it in the ignored `tmp/keys.yml`; do not commit
  it or paste it into chat.
- The reserved Primary IPv4 address, its Hetzner location, and confirmation
  that it is unassigned and available for this server. A Primary IP can be
  attached to only one server at a time.
- A server type available in that location and an agreed monthly budget. Size it
  for K3s, ingress, and Remark42; validate resource use during the proof of
  concept.
- An SSH public key and the trusted public IPv4 CIDR from which you will connect
  to the server, usually an address ending in `/32`. The private key remains
  with the operator. Hetzner requires SSH public keys to be unique within the
  project; choose an unregistered key or adapt the configuration to use an
  existing key before applying.

This configuration uses local state at `tmp/opentofu/posse.tfstate`, separate
from any previous state. Local state can contain sensitive data. Protect and
back it up, keep it out of Git, and choose a durable shared state backend before
using this environment for long-lived workloads. Review any existing resources
and state independently before adopting or changing them.

## Initialize and plan

From the repository root, run:

```sh
bash src/opentofu/plan.sh
```

The script reads `hetzner.token` and `hetzner.ip.primary` from `tmp/keys.yml`,
selects the configured SSH agent key, and defaults to `hel1` and `cpx12`. It
initializes OpenTofu and saves the plan at
`tmp/opentofu/posse.tfplan`; running it again replaces that saved plan.

By default, the SSH firewall allows the public IPv4 address observed from the
dev container. Verify that this is also the address of the machine you will use
to connect. To override it, or change the location or server type, set the
relevant variables before running the script:

```sh
TF_VAR_ssh_allowed_cidr="YOUR_SSH_CLIENT_IPV4/32" bash src/opentofu/plan.sh
```

`TF_VAR_location` and `TF_VAR_server_type` are also optional overrides. The
script does not modify the environment of the shell that invokes it.

Review the plan, resource names, IP assignment, firewall, and costs before
approving an apply. To apply the saved plan explicitly, run:

```sh
bash src/opentofu/apply.sh
```

The script displays the saved plan and requires you to type `apply` before
creating or changing billable resources. The plan file can contain sensitive
data; keep it protected and out of Git.

To review and destroy the resources managed in this state, run:

```sh
bash src/opentofu/destroy.sh
```

OpenTofu displays the destruction plan and asks for confirmation. Destroying
removes the server, firewall, and registered key, including any data on the
server disk; the separately managed Primary IP remains. Keep state available
for future updates and cleanup.

## Shared environment

Other Bash scripts can source the shared setup and load only the inputs they
need:

```sh
source src/opentofu/env.sh
posse_load_environment
posse_load_plan_inputs
```

`posse_load_environment` exports the Hetzner token and OpenTofu data directory;
`posse_load_plan_inputs` additionally loads the Primary IP, SSH key, SSH CIDR,
location, and server type. Apply only needs the first function because the
saved plan already contains its inputs. When sourcing in an interactive shell,
unset `HCLOUD_TOKEN` after use.
