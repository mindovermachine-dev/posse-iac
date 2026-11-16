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
storage after a pod restart and node restart, and single-pod `Recreate` rollout behavior. It keeps
`AUTH_ANON=false`, maps a generated administrator password from the temporary
Kubernetes Secret, and uses synthetic content only. This local configuration
is not suitable for deployment.

## Observed results

- `src/helm/remark42/tests/render-test.sh` passed with Helm 4.3.1.
- Docker Engine 28.0.4 reported host architecture `x86_64`. Inspecting the
  pinned image index confirmed Linux `amd64` and `arm64` manifests. The
  integration test did not start a Remark42 pod, so runtime image ID and
  container architecture remain unverified.
- `src/helm/remark42/tests/integration-test.sh` was attempted with k3d 5.8.3
  and K3s `v1.31.5-k3s1`. k3d created its unique cluster and the test observed
  the node as Ready, but K3s did not install the Traefik IngressClass within
  120 seconds. The Helm installer logs reported
  `Kubernetes cluster unreachable: Get "https://10.43.0.1:443/version": dial tcp 10.43.0.1:443: i/o timeout`.
  The K3s API service ClusterIP was unreachable from the in-cluster Traefik
  installer pods. The script reported the failure and removed its cluster and
  temporary credentials.
- Consequently, the app install, ingress and CA validation, widget requests,
  comment creation/read, media persistence, moderator action, pod restart,
  Helm upgrade/single-writer observation, and node restart were not run.

The integration command above can be rerun when pod-to-service networking
works in the Docker environment. Neither the offline chart checks nor the
incomplete local cluster test verify Hetzner networking, public DNS,
certificate issuance, backups, or production recovery.
