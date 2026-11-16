---
title: Remark42
description: First POSSE workload, deployment choices, persistence, and operational constraints.
sidebar:
  order: 2
---

## Role

Remark42 is the first planned service because comments complement static publishing without requiring a full application platform for the sites themselves. Static sites embed the Remark42 client and send comment requests to the configured service hostname.

Use the upstream application as the starting point. The project owns and
maintains its Helm chart in `src/helm/remark42`; the chart is based on a pinned
upstream chart revision but is not synchronized with it. Review application
releases and security fixes independently.

## Image and chart ownership

The chart uses Remark42 `v1.18.0`, pinned to the supplied multi-platform
`ghcr.io/umputun/remark42` image-index digest. The image index supports Linux
AMD64 and ARM64; the chart deliberately has no mandatory architecture selector.
The chart provenance, license, tests, and current local-test instructions are
recorded alongside the chart. The offline render test passes. The current
Docker-host K3s integration attempt is blocked because in-cluster requests to
the Kubernetes service IP time out; no Remark42 pod or application flow was
tested.

The chart is chart-specific application configuration, separate from cluster
bootstrap. It deploys one replica with a `Recreate` strategy, a ClusterIP
service, health probes, non-root security settings, and a persistent claim
mounted at `/srv`, where Remark42 stores its database and media under `/srv/var`.
Chart-created PVCs are retained after Helm uninstall by default; removal of
retained data is an explicit operator action. `ReadWriteOnce` is not itself a
single-writer guarantee, so rollout and recovery behavior must continue to be
checked.

## Configuration and data

Configure the external service URL, Remark42 `SITE` identifier, ingress
hostname, TLS Secret name, and storage through values. Create the Kubernetes
Secret containing `SECRET` and any optional authentication credentials
separately; the chart accepts only Secret names and key references. Keep secret
values out of Helm values, release metadata, logs, and source control. Do not
enable anonymous login or development authentication in live configuration.

Remark42 uses an embedded database, so its storage and rollout behavior are central design constraints:

- Run exactly one writer against the data directory.
- Verify the chart mounts all required data, including comments and media, onto storage that survives pod and node restarts.
- Configure the rollout and volume access policy to enforce one active writer at all times, including during upgrades.
- Test persistence and a controlled upgrade before relying on the service.

Select and test persistent storage before any live deployment. Document the
single-writer requirement and the availability characteristics of the chosen
host and storage. Validate the ingress forwarding path and configure trusted
proxies before relying on IP-based protections; the local chart test does not
establish that live proxy-header trust.

## Backups and user data

The proof of concept uses sample data. Before onboarding users, define encrypted offsite backups, retention, access controls, and a tested restore procedure. Agree recovery point and recovery time objectives before making commitments.

Include avatars and pictures alongside comments in the recovery design. Follow the [backup](https://remark42.com/docs/backup/backup/) and [restore](https://remark42.com/docs/backup/restore/) documentation, and validate the complete recovery procedure against the deployment.
