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
Static sites -> comments.example.org -> HTTPS ingress -> Remark42 -> persistent data
                                                   -> future POSSE services
```

`comments.example.org` is a documentation placeholder, not a configured or
registered hostname. The deployment hostname is an operator-managed input.
The diagram shows the proposed request path. Namespaces organize workloads
within the cluster; separate servers provide stronger failure isolation.

## Why K3s

A single-node K3s platform supports multiple separately deployed services through shared ingress and Kubernetes deployment practices. It also requires additional memory and operational work, which should be included in server sizing and ongoing operations.

Start with one cluster, one node, and Remark42. Add workloads as their requirements and operating practices are defined.

## Components

- **OpenTofu:** Provision approved Hetzner resources, firewall rules, and server access. Keep state protected and out of version control.
- **K3s:** Provide the single-node workload platform. Keep its API private to operators and patch the host and cluster regularly.
- **Ingress:** Terminate HTTPS and route configured hostnames to services. Trust forwarded client headers only from the known proxy path.
- **Applications:** Deploy independently, initially using the project-owned
  `src/helm/remark42` chart and pinned Remark42 image. The chart does not
  provision Hetzner resources or install K3s, ingress, or certificate
  management. Its offline render checks and disposable local K3s integration
  test pass; neither verifies the live Hetzner network or public DNS.
- **Data:** Use storage with filesystem and locking behavior supported by the application, and configure each workload for its supported writer model.

## Networking and placement

DNS records are managed outside this repository. Confirm the selected hostname
and its records with the DNS provider, then use that hostname consistently in
the Remark42 URL, ingress rule, certificate, and authentication-provider
callbacks. The chart and OpenTofu configuration do not provision DNS.

Provision dedicated Hetzner resources for the POSSE platform. Select the server, network, and DNS configuration for the chosen hostname before provisioning.

The current OpenTofu configuration provisions only a server, firewall, SSH
key, and attachment of an existing Primary IPv4. It does not bootstrap K3s,
install cert-manager, create DNS records, or deploy applications. Follow the
[operator-led PoC runbook](../delivery/implementation/) and resolve its explicit
approval gates before provisioning. The configured local state backend is not
appropriate for long-lived production infrastructure.

## Future services

A future `posse_utils` backend might support event registration, newsletter or mailing-list subscriptions, and forms. Select storage, authentication, and email delivery after defining data, privacy, delivery, and moderation requirements. Email and mailing-list capabilities require a delivery service in addition to data storage.
