# Remark42 Helm chart

This independently maintained chart deploys one Remark42 replica using a
digest-pinned image and persistent storage.

## Provenance and license

This chart starts from `charts/remark42` in
[groundhog2k/helm-charts](https://github.com/groundhog2k/helm-charts) at commit
`9a39f809afb43e6a02b2081f9f2a2a998a6adedf`, chart version `0.11.6`. It is
maintained here independently; there is no synchronization commitment. The
copied chart is licensed under MIT; see [`LICENSE`](LICENSE) for its copyright
notice. The optional upstream Redis dependency was removed, so no dependency
chart or Redis license is included.

## Configuration and installation

Supply a values file outside source control for environment-specific settings.
At minimum, configure:

```yaml
settings:
  url: https://comments.example.test
  site: my-site

secret:
  name: remark42-auth
  key: SECRET
  env:
    - name: AUTH_GITHUB_CID
      key: AUTH_GITHUB_CID
    - name: AUTH_GITHUB_CSEC
      key: AUTH_GITHUB_CSEC

storage:
  requestedSize: 5Gi
  className: local-path
  keepPvc: true

ingress:
  enabled: true
  className: traefik
  hosts:
    - host: comments.example.test
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - comments.example.test
      secretName: comments-example-tls
```

Create `remark42-auth` and the referenced TLS Secret before installing. The
chart requires `SECRET` from the external Secret; optional authentication or
integration credentials can be listed under `secret.env` as environment/key
pairs. Only Secret names and keys are stored in Helm values and release
metadata. Do not put credential values in Helm values or command-line
arguments. For example, create a secret from protected files with
`kubectl create secret generic remark42-auth --from-file=SECRET=/secure/path/secret`.

The application and init container use
`ghcr.io/umputun/remark42@sha256:00a803ffdde34e8f239eef3e46adbeac44b9ef1a2f366e8b86b413d6908f3ac3`
(Remark42 `v1.18.0`). This is the supplied multi-platform image-index digest
for Linux AMD64 and ARM64. There is no architecture node selector.

The chart creates a single-replica `Recreate` Deployment and a ClusterIP
Service. It mounts the claim at `/srv`; Remark42 keeps its database, comments,
avatars, and uploaded pictures under `/srv/var`. The default pod identity is
non-root UID/GID 1001 with `fsGroup: 1001`. The claim uses `ReadWriteOnce`,
which by itself does **not** guarantee a single writer. `Recreate` prevents the
Deployment from intentionally overlapping old and new pods during a rollout;
it does not replace operational checks of node and volume behavior.

Chart-created PVCs have `helm.sh/resource-policy: keep` by default. Uninstall
leaves the PVC and its data behind; an operator must deliberately identify and
delete it when retention is no longer required. A chart-managed PVC must be
given `storage.requestedSize`; an existing PVC can instead be named with
`storage.persistentVolumeClaimName`.

The default `AUTH_ANON` is false. Do not enable anonymous or development
authentication in live values. Before deployment, configure and verify the
trusted proxy path for forwarded client headers; this chart does not establish
or verify IP-based protections.

## Checks

Run the offline assertions with
[`tests/render-test.sh`](tests/render-test.sh). The disposable local integration
workflow and its prerequisites, commands, results, and limitations are
documented in [`tests/README.md`](tests/README.md).

For the operator-led Hetzner PoC sequence and the infrastructure steps this
chart does not automate, see the
[deployment runbook](../../../docs/content/delivery/implementation/).
