# Remark42 chart tests

## Offline/render test

Prerequisites: Helm 4.3.1 and Bash.

```sh
src/helm/remark42/tests/render-test.sh
```

The script runs `helm lint` and `helm template`, asserts the digest-pinned
image, one replica, `Recreate` rollout, PVC and `/srv` mount, ClusterIP,
Traefik ingress/TLS, all probes, non-root security, resource requests, and
external Secret key references, and a configured LoadBalancer source range.
It also checks that a synthetic sentinel is absent from rendered resources,
an empty required URL fails rendering, and an invalid image digest is rejected.
Temporary rendered output and error diagnostics are removed on exit; no
cluster is created.

## Disposable K3s integration

Prerequisites:

- Docker Engine reachable by the current user
- k3d 5.8.3, which runs K3s `v1.31.5-k3s1`
- Helm 4.3.1, kubectl 1.37.2, curl, OpenSSL, and Python 3
- jq

Run non-interactively:

```sh
src/helm/remark42/tests/integration-test.sh
```

The script is designed to create a uniquely named one-node k3d cluster, a
temporary kubeconfig, namespace, ephemeral CA/server certificate, TLS Secret,
application Secret, and Helm release. Its HTTPS port is bound to
`127.0.0.1` only. It refuses a pre-existing generated cluster name. A trap
deletes only that invocation's cluster and removes its mode-0700 temporary
directory, including private keys and secret input files, on success or
failure. Failure diagnostics include resource status, pod descriptions, and
K3s Traefik installer logs, but not application logs or secret values.
If k3d cluster creation itself fails, k3d rolls back by default; the script
deletes the uniquely named cluster after successful creation.

The cluster uses K3s's bundled Traefik and local-path provisioner. On a
successful run, the script validates HTTPS with `curl --resolve` and the
generated CA, the widget endpoint and assets, pod image and node architecture,
storage after a pod restart and node restart, and single-pod `Recreate` rollout
behavior. It keeps `AUTH_ANON=false`, maps a generated administrator password
from the temporary Kubernetes Secret, and uses synthetic content only. This
local configuration is not suitable for deployment. After pod, Helm, and node
restarts, API checks retry transient ingress 404 responses for up to 30 seconds
while Traefik refreshes its service endpoints.

## Observed results

- `src/helm/remark42/tests/render-test.sh` passed with Helm 4.3.1.
- `src/helm/remark42/tests/integration-test.sh` passed with k3d 5.8.3 and K3s
  `v1.31.5-k3s1` on the local ARM64 Docker daemon. It verified loopback-only
  HTTPS and the generated CA, loaded the widget asset, created and read a
  synthetic comment, uploaded and served media, and confirmed the pinned image
  ran as ARM64. The comment and media survived pod restart, a `Recreate` Helm
  upgrade with no overlapping pods, and a K3s node restart. Moderator deletion
  succeeded, and the script removed its test cluster and temporary credentials.

Neither the offline chart checks nor the local integration test verify Hetzner
networking, public DNS, certificate issuance, backups, or production recovery.
