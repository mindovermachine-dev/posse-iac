---
title: Platform architecture
description: Proposed Hetzner-hosted foundation for POSSE services, starting with Remark42.
sidebar:
  order: 1
---

## Design

POSSE infrastructure starts with a small, deliberately understandable platform for services that support publishing on our own sites and syndicating content elsewhere. The first workload is [Remark42](./remark42/), providing comments for static sites. Later services should be added only when a concrete need and operating model are clear.

The proposed platform is one Hetzner Cloud VPS running K3s. OpenTofu will describe the cloud resources; K3s will host independently deployed services; a shared ingress will route HTTPS traffic by hostname. The single node is a failure point for the server, its storage, and its network, so recovery depends on tested backups and replacement infrastructure.

```text
Static sites -> comments.foss.mom -> HTTPS ingress -> Remark42 -> persistent data
                                                   -> future POSSE services
```

The diagram shows the proposed request path. Namespaces organize workloads within the cluster; separate servers provide stronger failure isolation.

## Why K3s

A single-node K3s platform supports multiple separately deployed services through shared ingress and Kubernetes deployment practices. It also requires additional memory and operational work, which should be included in server sizing and ongoing operations.

Start with one cluster, one node, and Remark42. Add workloads as their requirements and operating practices are defined.

## Components

- **OpenTofu:** Provision approved Hetzner resources, firewall rules, and server access. Keep state protected and out of version control.
- **K3s:** Provide the single-node workload platform. Keep its API private to operators and patch the host and cluster regularly.
- **Ingress:** Terminate HTTPS and route configured hostnames to services. Trust forwarded client headers only from the known proxy path.
- **Applications:** Deploy independently, initially using a pinned Helm chart and image for Remark42. Keep application source in its own repository or fork.
- **Data:** Use storage with filesystem and locking behavior supported by the application, and configure each workload for its supported writer model.

## Networking and placement

`comments.foss.mom` is the candidate initial hostname, subject to confirming DNS ownership and configuration. Point the selected hostname at the approved public ingress and configure certificates for it.

Provision dedicated Hetzner resources for the POSSE platform. Select the server, network, and DNS configuration for the chosen hostname before provisioning.

## Future services

A future `posse_utils` backend might support event registration, newsletter or mailing-list subscriptions, and forms. Select storage, authentication, and email delivery after defining data, privacy, delivery, and moderation requirements. Email and mailing-list capabilities require a delivery service in addition to data storage.
