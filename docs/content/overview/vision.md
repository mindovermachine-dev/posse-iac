---
title: POSSE platform vision
description: Why this project exists and the first capability it will support.
sidebar:
  order: 1
redirectFrom: /
# cspell:ignore lsewhere ublish yndicate
---

## Purpose

Mind over Machine wants to demonstrate a small, self-hosted foundation for a POSSE publishing strategy: **P**ublish on your **O**wn **S**ite, then **S**yndicate **E**lsewhere to other platforms. The canonical publication stays under the publisher's control, while supporting services can be hosted independently. While restraining from pointing visitors _off_ you own site.

It's related to the concept of a JAM stack: **J**avaScript **A**PI's and **M**arkDown; essentially a static website, where the webserver itself has no backend or Server Side Scripting capabilities (to optimize speed and security) and all backend features are utilized through APIs. In a JAM strategy, these APIs are often driving users to other services like newsletter signups, comments, forms, event signups etc. We're building a POSSE strategy based on Digital Sovereignty principles.

This repository is the infrastructure home for the platform. Its focus is a Hetzner-hosted environment and the infrastructure-as-code needed to provision and operate it.

## First capability

Start with comments. Remark42 can serve comments embedded in static sites and gives the project a concrete service to deploy, secure, back up, and operate. The first milestone is a proof of concept on a single Hetzner node.

The platform and Remark42 designs are documented in [Platform architecture](../architecture/platform/) and [Remark42](../architecture/remark42/).

## Principles

- Keep each publisher's website as the canonical place for their content.
- Prefer small, independently deployable services over one large application stack.
- Keep application code, container builds, and infrastructure configuration in clear ownership boundaries.
- Make data persistence, recovery, security, and operating cost explicit design concerns.
- Build only what current requirements justify; keep future ideas as options, not implied commitments.

## Possible next capabilities

A future `posse_utils` backend could provide APIs for event registration, forms, questionnaires, or newsletter and mailing-list subscriptions. These capabilities require clear decisions about email delivery, consent, data retention, authentication, and moderation.
