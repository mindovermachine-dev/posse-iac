---
title: Implementation and operations
description: Proof-of-concept milestones and operational practices for the POSSE platform.
sidebar:
  order: 1
---

## Current state

No Hetzner resources or live services have been provisioned. The project-owned
Remark42 chart is at `src/helm/remark42`. Its offline render checks and the
disposable ARM64 k3d integration test pass; test details are in the
[chart test guide](../../../src/helm/remark42/tests/README.md). These local
tests do not exercise Hetzner networking, public DNS, or public certificate
issuance.

## Hetzner PoC Runbook

This is an operator-led proof-of-concept procedure, not a production-readiness
claim. Stop at any gate whose ownership, cost, or traffic impact is unclear.
Do not run the live steps from an unattended Copilot session.

### 1. Resolve placement and protect state

The OpenTofu configuration currently provisions only an Ubuntu server, firewall,
and SSH key, and attaches an existing Hetzner Primary IPv4. It does not create
K3s, install the chart, create DNS records, or issue certificates. The Primary
IP must be unassigned before apply and can be attached to only one server.

The DNS zone and records are managed outside this repository; use the DNS
provider as their source of truth. This configuration does not create or change
DNS records. Confirm who owns the selected Primary IP and what traffic it
serves, and agree the service hostname before changing infrastructure or
routes. Do not infer IP availability from DNS, or duplicate live DNS values in
documentation.

The configured OpenTofu backend is a local file at
`tmp/opentofu/posse.tfstate`; it is suitable only for a carefully protected
PoC. It is not a shared or production state backend. Choose protected durable
state storage before long-lived infrastructure. Never commit the state, API
token, private SSH key, or `posse.tfvars`.

### 2. Review and provision the Hetzner server

Provide `HCLOUD_TOKEN` through the operator's protected environment. Prepare
`src/opentofu/posse.tfvars` from the example with the approved unassigned
Primary IPv4, location, server type, SSH public key, and restricted SSH source
CIDR. Check current server sizing and price; do not assume the former CPX02
estimate is sufficient for K3s.

From `src/opentofu`, inspect the plan before any billable action:

```sh
tofu init
tofu validate
tofu plan -var-file=posse.tfvars
```

Confirm the IP attachment, server type, firewall rules, SSH CIDR, and cost in
the plan. Apply only after an operator approves that exact plan:

```sh
tofu apply -var-file=posse.tfvars
tofu output -raw server_ipv4
```

The firewall in `main.tf` allows SSH only from the configured CIDR and public
HTTP/HTTPS. It does not open the Kubernetes API port. Keep the API private.

### 3. Bootstrap and verify K3s

K3s installation and host hardening are not automated by this repository yet.
On the approved server, install a currently supported, explicitly pinned K3s
release using the [official K3s installation guide](https://docs.k3s.io/installation).
Do not copy the old K3s `v1.31.5` used by the local integration test as a live
version recommendation. Keep the API operator-only, verify the node is Ready,
and record the K3s version and configuration.

K3s normally installs Traefik and its local-path storage provisioner. Verify
both are healthy and that the storage class and node-local failure behavior
meet the PoC requirements before proceeding. A single-node cluster is still
one server and one storage failure domain.

### 4. Configure DNS and HTTPS

Verify the approved hostname resolves to the intended ingress IP. The chart
requires an existing TLS Secret; it does not install cert-manager or create a
certificate. For the proposed live design, install and pin cert-manager, then
configure a Let's Encrypt HTTP-01 issuer using Traefik. Test against the
Let's Encrypt staging endpoint first. HTTP port 80 must reach the challenge
solver and HTTPS port 443 must reach Traefik before requesting a production
certificate. A DNS wildcard does not itself issue a certificate; a wildcard
certificate would require DNS-01 and DNS-provider credentials.

Create a cert-manager `Certificate` for the approved hostname and wait for its
TLS Secret to be Ready before installing the application. Do not copy the
ephemeral local CA or certificate from the k3d test to Hetzner.

### 5. Create secrets and deploy Remark42

Choose the authentication provider, moderator identity, `SITE` identifier,
hostname, and comment-embedding site. Configure provider callback URLs using
the [Remark42 authorization documentation](https://remark42.com/docs/configuration/authorization/).
Generate a new high-entropy `SECRET` and store it, OAuth credentials, and any
admin password in a protected secret manager or protected files. Create a
Kubernetes Secret out of band; never place secret values in Helm values or
command arguments. The chart values should contain only the Secret name and
key references.

Review the example values and storage requirements in the
[chart README](../../../src/helm/remark42/README.md). In particular:

- Set the service URL, site ID, ingress hostname, TLS Secret, and a persistent
  claim size.
- Keep one replica and the `Recreate` deployment strategy. Confirm the
  deployment has one writer before and after each upgrade.
- Keep anonymous and development authentication disabled for a live hostname.
- Confirm the chart's image repository and digest match the release approved
  for deployment.

From the repository root, render and inspect the chart using a protected values
file (it contains references, not secret values):

```sh
helm lint src/helm/remark42 --values /secure/path/remark42-values.yaml
helm template remark42 src/helm/remark42 \
  --namespace remark42 \
  --values /secure/path/remark42-values.yaml
```

Ensure the certificate controller creates the TLS Secret named in the values
before Helm creates the Ingress. Connect `kubectl` and Helm through an
operator-controlled private access path; do not expose the Kubernetes API
publicly for convenience. This repository does not yet provision that access
path. Before deployment, establish it (for example, an SSH tunnel to the
private K3s API), protect the kubeconfig, and confirm `kubectl cluster-info`
works through it.

Create the namespace and application Secret before Helm, using protected files
for all secret values. For example:

```sh
kubectl create namespace remark42
kubectl -n remark42 create secret generic remark42-auth \
  --from-file=SECRET=/secure/path/remark42-secret \
  --from-file=AUTH_GITHUB_CID=/secure/path/github-client-id \
  --from-file=AUTH_GITHUB_CSEC=/secure/path/github-client-secret
```

Include only credentials for the chosen authentication provider. Do not put
secret contents in shell arguments, Helm values, or Git; create the TLS Secret
through the verified certificate controller rather than copying the local test
certificate.

After both Secrets exist, install the chart:

```sh
helm upgrade --install remark42 src/helm/remark42 \
  --namespace remark42 \
  --values /secure/path/remark42-values.yaml
```

### 6. Validate and operate

Check `kubectl -n remark42 rollout status deployment/remark42`, the Ingress,
TLS Secret, PVC, pod events, and logs. From an external client, verify the
certificate chain and the widget asset at
`https://<approved-hostname>/web/embed.js`. Then test the embedded widget,
authentication, comment creation, moderation, and the OAuth callback.

Before and after any Helm upgrade, confirm exactly one Remark42 writer. Verify
comments and uploaded media survive pod and node restarts. The local integration
test is a useful reference for the expected checks, but its local certificates,
secrets, and test configuration are disposable and must not be reused.

The chart keeps its PVC on Helm uninstall by default. This protects against an
accidental chart uninstall, but does not protect data from server loss or
`tofu destroy`. Never destroy the server as a cleanup shortcut. Before real
users, implement independent encrypted backups of comments and media, perform
a restore test, and define retention, RPO/RTO, monitoring, privacy, moderation,
and incident-response responsibilities.

## Remaining Automation and Production Gates

- Add reviewed K3s bootstrap and host-hardening automation; this is currently a
  manual operator step.
- Select protected durable OpenTofu state and a secret-delivery mechanism.
- Confirm Primary IP ownership, DNS impact, server sizing, costs, and operator
  access before apply.
- Install and test cert-manager, the staging issuer, production issuer, and
  renewal monitoring; none is currently provisioned by this repository.
- Implement and test independent backups and restore before accepting real
  user data. The local-path PVC on a single node is not a backup.

## References

- [Remark42 installation](https://remark42.com/docs/getting-started/installation/) and [configuration](https://remark42.com/docs/configuration/parameters/)
- [Remark42 backup](https://remark42.com/docs/backup/backup/) and [restore](https://remark42.com/docs/backup/restore/)
- [Pinned Groundhog2k Remark42 chart source](https://github.com/groundhog2k/helm-charts/tree/9a39f809afb43e6a02b2081f9f2a2a998a6adedf/charts/remark42)
- [Project-owned Remark42 chart and local test instructions](../../../src/helm/remark42/README.md)
- [K3s installation requirements](https://docs.k3s.io/installation/requirements) and [networking services](https://docs.k3s.io/networking/networking-services)
- [cert-manager installation](https://cert-manager.io/docs/installation/) and [HTTP-01 challenges](https://cert-manager.io/docs/configuration/acme/http01/)
- [Hetzner Cloud pricing](https://www.hetzner.com/cloud/regular-performance/)
