#!/usr/bin/env bash
set -euo pipefail

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

helm lint "$chart_dir" --values "$chart_dir/tests/render-values.yaml"
helm template remark42 "$chart_dir" --namespace remark42-test \
  --values "$chart_dir/tests/render-values.yaml" >"$work_dir/rendered.yaml"

assert_rendered() {
  local description="$1"
  local pattern="$2"
  if ! grep -Eq "$pattern" "$work_dir/rendered.yaml"; then
    printf 'FAIL: %s\n' "$description" >&2
    exit 1
  fi
}

assert_rendered "pinned digest image" 'image: "?ghcr\.io/umputun/remark42@sha256:00a803ffdde34e8f239eef3e46adbeac44b9ef1a2f366e8b86b413d6908f3ac3"?'
if [[ "$(grep -Fc 'ghcr.io/umputun/remark42@sha256:00a803ffdde34e8f239eef3e46adbeac44b9ef1a2f366e8b86b413d6908f3ac3' "$work_dir/rendered.yaml")" -ne 2 ]]; then
  printf 'FAIL: expected the pinned image on both init and application containers\n' >&2
  exit 1
fi
assert_rendered "single replica" 'replicas: 1'
assert_rendered "Recreate deployment strategy" 'type: Recreate'
assert_rendered "persistent data volume mounted at /srv" 'mountPath: /srv'
assert_rendered "deployment uses the chart-created PVC" 'claimName: remark42'
assert_rendered "PVC retention on uninstall" '"?helm\.sh/resource-policy"?: keep'
assert_rendered "ClusterIP service" 'type: ClusterIP'
assert_rendered "Traefik ingress host and TLS secret" 'ingressClassName: traefik'
assert_rendered "ingress hostname" 'host: "remark42\.test"'
assert_rendered "TLS host and secret" 'secretName: remark42-tls'
assert_rendered "startup probe" 'startupProbe:'
assert_rendered "readiness probe" 'readinessProbe:'
assert_rendered "liveness probe" 'livenessProbe:'
assert_rendered "non-root pod security" 'runAsNonRoot: true'
assert_rendered "non-root filesystem group" 'fsGroup: 1001'
assert_rendered "read-only root filesystem" 'readOnlyRootFilesystem: true'
assert_rendered "no privilege escalation" 'allowPrivilegeEscalation: false'
assert_rendered "resource requests" 'cpu: 50m'
assert_rendered "SECRET references an existing Secret" 'name: SECRET'
assert_rendered "SECRET key reference" 'key: SECRET'
assert_rendered "external Secret name" 'name: remark42-auth'
assert_rendered "SECRET uses secretKeyRef" 'secretKeyRef:'
assert_rendered "optional credentials reference an existing Secret" 'key: ADMIN_PASSWD'

helm template remark42 "$chart_dir" --namespace remark42-test \
  --values "$chart_dir/tests/render-values.yaml" \
  --set service.type=LoadBalancer \
  --set-string 'service.loadBalancerSourceRanges[0]=192.0.2.0/24' \
  >"$work_dir/load-balancer.yaml"
if ! grep -Fq '192.0.2.0/24' "$work_dir/load-balancer.yaml"; then
  printf 'FAIL: configured LoadBalancer source range was not rendered\n' >&2
  exit 1
fi

if grep -Fq 'RENDER-TEST-SYNTHETIC-NOT-A-SECRET' "$work_dir/rendered.yaml"; then
  printf 'FAIL: synthetic credential was rendered into a Kubernetes resource\n' >&2
  exit 1
fi

if grep -Eq '^kind: Secret$' "$work_dir/rendered.yaml"; then
  printf 'FAIL: chart rendered a Secret instead of referencing an existing Secret\n' >&2
  exit 1
fi

if grep -Fq 'kubernetes.io/arch:' "$work_dir/rendered.yaml"; then
  printf 'FAIL: rendered workload has a mandatory architecture selector\n' >&2
  exit 1
fi

if helm template remark42 "$chart_dir" --namespace remark42-test \
  --values "$chart_dir/tests/render-values.yaml" --set settings.url= \
  >"$work_dir/missing-required.yaml" 2>"$work_dir/missing-required.err"; then
  printf 'FAIL: rendering succeeded without the required external URL\n' >&2
  exit 1
fi

if ! grep -Fq '.settings.url must contain valid URL' "$work_dir/missing-required.err"; then
  printf 'FAIL: missing-URL render failed for an unexpected reason\n' >&2
  cat "$work_dir/missing-required.err" >&2
  exit 1
fi

if helm template remark42 "$chart_dir" --namespace remark42-test \
  --values "$chart_dir/tests/render-values.yaml" --set image.digest=invalid \
  >"$work_dir/invalid-digest.yaml" 2>"$work_dir/invalid-digest.err"; then
  printf 'FAIL: rendering succeeded with an invalid image digest\n' >&2
  exit 1
fi

if ! grep -Fq '.image.digest must be a valid sha256 digest' "$work_dir/invalid-digest.err"; then
  printf 'FAIL: invalid image digest render failed for an unexpected reason\n' >&2
  cat "$work_dir/invalid-digest.err" >&2
  exit 1
fi

printf 'PASS: Helm lint, rendered-resource assertions, synthetic-value absence, required-configuration rejection, and LoadBalancer source ranges\n'
