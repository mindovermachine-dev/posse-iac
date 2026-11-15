---
title: Remark42
description: First POSSE workload, deployment choices, persistence, and operational constraints.
sidebar:
  order: 2
---

## Role

Remark42 is the first planned service because comments complement static publishing without requiring a full application platform for the sites themselves. Static sites embed the Remark42 client and send comment requests to the configured service hostname.

Use the upstream application as the starting point. Maintain a fork if project-specific patches become necessary, and regularly review upstream releases and security fixes.

## Image and chart

Build an image from a pinned upstream release or fork commit and deploy it by immutable image digest. Record the upstream version, source commit, target architecture, and digest. Test and scan the image, and decide which registry and CI system will own builds and private image access.

Evaluate the [Groundhog2k Remark42 Helm chart](https://github.com/groundhog2k/helm-charts/tree/master/charts/remark42) for the deployment. Pin a chart version and check its image overrides, data paths, permissions, health probes, and upgrade behavior against the chosen application version. Use the upstream chart, with a maintained fork for required customizations.

## Configuration and data

Configure the service hostname consistently in `REMARK_URL`, the Remark42 `SITE` identifier, the embedded client, and authentication callback settings. Keep `SECRET`, OAuth credentials, registry credentials, and moderator access out of source control. Use non-production credentials and sample comments during the proof of concept.

Remark42 uses an embedded database, so its storage and rollout behavior are central design constraints:

- Run exactly one writer against the data directory.
- Verify the chart mounts all required data, including comments and media, onto storage that survives pod and node restarts.
- Configure the rollout and volume access policy to enforce one active writer at all times, including during upgrades.
- Test persistence and a controlled upgrade before relying on the service.

Select and test persistent storage before deployment. Document the single-writer requirement and the availability characteristics of the chosen host and storage.

## Backups and user data

The proof of concept uses sample data. Before onboarding users, define encrypted offsite backups, retention, access controls, and a tested restore procedure. Agree recovery point and recovery time objectives before making commitments.

Include avatars and pictures alongside comments in the recovery design. Follow the [backup](https://remark42.com/docs/backup/backup/) and [restore](https://remark42.com/docs/backup/restore/) documentation, and validate the complete recovery procedure against the deployment.
