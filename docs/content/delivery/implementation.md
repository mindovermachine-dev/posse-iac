---
title: Implementation and operations
description: Proof-of-concept milestones and operational practices for the POSSE platform.
sidebar:
  order: 1
---

## Current state

The Hetzner POSSE platform remains in the design stage; no live resources or
services have been deployed. The independently maintained Remark42 chart is in
`src/helm/remark42`; its offline checks pass. The disposable K3s integration
attempt is documented in the chart test README and is blocked by unreachable
in-cluster Kubernetes service networking in this Docker environment. This
local work does not authorize or perform a Hetzner deployment.

## Milestones

1. **Agree placement:** Select the Hetzner location, DNS zone, candidate hostname, operator access, and budget for the POSSE project.
2. **Size and provision:** Check current Hetzner pricing and K3s resource requirements. The previously considered CPX02 has 1 GB RAM; measure the resource needs of K3s, ingress, and Remark42 before selecting a server. Provision the selected resources with OpenTofu and restrict administrative access.
3. **Prepare the application:** Review the pinned Remark42 image release and digest, independently test and scan it, and define image ownership. Maintain the project-owned chart separately from cluster bootstrap; review its storage and upgrade behavior before live use.
4. **Deploy the proof of concept:** After explicit approval, configure dedicated K3s, ingress, HTTPS, the hostname, a single Remark42 writer, persistent data, and test authentication. Use sample data while recovery and security practices are established.
5. **Validate and record:** Test the embedded widget, authentication, posting, moderation, persistence after pod and node restarts, and a controlled upgrade without overlapping writers. Measure actual memory, CPU, and disk usage; record commands and operational findings.
6. **Review production readiness:** Before accepting real users or personal data, implement independent encrypted backups including media, test a restore, define retention and recovery objectives, and review privacy, spam controls, monitoring, and incident access.

## Operating constraints

- A single VPS is a single point of failure. Plan recovery around tested backups and replacement infrastructure.
- Keep OpenTofu state and credentials out of Git. Use protected state storage and choose a durable backend for the long-lived POSSE environment.
- Expose only required public ports. Restrict SSH and the Kubernetes API to operators, patch the host and K3s, and keep application secrets outside committed configuration.
- Monitor basic service health and disk capacity. Agree who responds to failures before the service is used by others.
- Include media in comment backups and validate recovery with a restore test.

## Decisions to resolve

- Which DNS zone is available, and what hostname should be used first?
- Which Hetzner server type and storage arrangement meet measured resource and persistence needs?
- Which image registry and build/scan pipeline will own the pinned application image?
- Which authentication provider, test site, `SITE` identifier, and moderator identity will be used?
- What requirements must future event registration, forms, or mailing-list services meet for privacy, retention, authentication, and email delivery?

## References

- [Remark42 installation](https://remark42.com/docs/getting-started/installation/) and [configuration](https://remark42.com/docs/configuration/parameters/)
- [Remark42 backup](https://remark42.com/docs/backup/backup/) and [restore](https://remark42.com/docs/backup/restore/)
- [Pinned Groundhog2k Remark42 chart source](https://github.com/groundhog2k/helm-charts/tree/9a39f809afb43e6a02b2081f9f2a2a998a6adedf/charts/remark42)
- [Project-owned Remark42 chart and local test instructions](../../../src/helm/remark42/README.md)
- [K3s installation requirements](https://docs.k3s.io/installation/requirements) and [networking services](https://docs.k3s.io/networking/networking-services)
- [Hetzner Cloud pricing](https://www.hetzner.com/cloud/regular-performance/)
