---
title: Implementation and operations
description: Proof-of-concept milestones and operational practices for the POSSE platform.
sidebar:
  order: 1
---

## Current state

The POSSE platform is in the design stage. The first delivery milestone is to define and provision dedicated Hetzner resources with OpenTofu, then configure K3s, ingress, persistent storage, and Remark42. Record the provisioned resources and operating procedures as implementation proceeds.

## Milestones

1. **Agree placement:** Select the Hetzner location, DNS zone, candidate hostname, operator access, and budget for the POSSE project.
2. **Size and provision:** Check current Hetzner pricing and K3s resource requirements. The previously considered CPX02 has 1 GB RAM; measure the resource needs of K3s, ingress, and Remark42 before selecting a server. Provision the selected resources with OpenTofu and restrict administrative access.
3. **Prepare the application:** Select an upstream Remark42 release, fork only if useful, build for the server architecture, test and scan the image, publish it, and record its digest. Select and pin the Helm chart after checking its compatibility and storage behavior.
4. **Deploy the proof of concept:** Configure K3s, ingress, HTTPS, the hostname, a single Remark42 writer, persistent data, and test authentication. Use sample data while recovery and security practices are established.
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
- Which registry, CI system, and fork repository will produce and publish images?
- Which chart version, authentication provider, test site, `SITE` identifier, and moderator identity will be used?
- What requirements must future event registration, forms, or mailing-list services meet for privacy, retention, authentication, and email delivery?

## References

- [Remark42 installation](https://remark42.com/docs/getting-started/installation/) and [configuration](https://remark42.com/docs/configuration/parameters/)
- [Remark42 backup](https://remark42.com/docs/backup/backup/) and [restore](https://remark42.com/docs/backup/restore/)
- [Groundhog2k Remark42 Helm chart](https://github.com/groundhog2k/helm-charts/tree/master/charts/remark42)
- [K3s installation requirements](https://docs.k3s.io/installation/requirements) and [networking services](https://docs.k3s.io/networking/networking-services)
- [Hetzner Cloud pricing](https://www.hetzner.com/cloud/regular-performance/)
