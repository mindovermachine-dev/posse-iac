# POSSE OpenTofu

This configuration describes an Ubuntu 24.04 Hetzner Cloud server for the POSSE
proof of concept, an operator SSH key, and a firewall. It attaches an existing
Primary IPv4 address and allows public HTTP and HTTPS, with SSH restricted to an
operator's IPv4 CIDR. The Primary IP remains managed separately from this
configuration.

K3s, ingress, Remark42, persistent application volumes, and backups are later
steps. Treat the host and its data as a proof of concept until persistence,
security, and recovery have been designed and tested.

For the staged operator procedure from infrastructure preflight through the
local-to-live boundary, see the
[Hetzner Remark42 PoC runbook](../../docs/content/delivery/implementation/).

## Before planning

Gather the following:

- A Hetzner Cloud API token with read and write access to the project containing
  the reserved Primary IP. Set `HCLOUD_TOKEN` on the host and make it available
  in the dev container; do not commit it or paste it into chat.
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

If you don't already have a configuration file, copy
`src/opentofu/posse.tfvars.example` to `src/opentofu/posse.tfvars` and fill in
the Primary IPv4, SSH public key, and allowed SSH CIDR. Adjust the location and
server type as needed. The configuration file is ignored by Git; do not put
tokens or private keys in it. The allowed CIDR must match the public address of
the machine you will use to connect.

From the tofu root `src/opentofu` repository root, prepare the working directory and initialize OpenTofu:

```sh
tofu init
```

The commands below assume you are still in `src/opentofu`. Use another
`-var-file` path to select a different configuration. Different variable files
still use the same configured state; they do not create separate deployments.

Preview changes:

```sh
tofu plan -var-file=posse.tfvars
```

To apply, run:

```sh
tofu apply -var-file=posse.tfvars
```

OpenTofu generates a fresh plan and asks for confirmation. Review the resource
names, IP assignment, firewall, and costs before approving changes to billable
resources.

To review and destroy the resources managed in this state, run:

```sh
tofu destroy -var-file=posse.tfvars
```

OpenTofu displays the destruction plan and asks for confirmation. Destroying
removes the server, firewall, and registered key, including any data on the
server disk; the separately managed Primary IP remains. Keep state available
for future updates and cleanup.
