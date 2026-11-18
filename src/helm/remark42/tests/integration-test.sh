#!/usr/bin/env bash
set -euo pipefail
umask 077

for tool in docker k3d helm kubectl curl openssl python3 jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Missing prerequisite: %s\n' "$tool" >&2
    exit 2
  fi
done

if ! docker info >/dev/null 2>&1; then
  printf 'Docker daemon is unavailable to the current user\n' >&2
  exit 2
fi

[[ "$(k3d version | sed -n 's/^k3d version //p')" == v5.8.3 ]] || {
  printf 'Expected k3d v5.8.3\n' >&2
  exit 2
}
[[ "$(helm version --short)" == v4.3.1+* ]] || {
  printf 'Expected Helm v4.3.1\n' >&2
  exit 2
}
kubectl version --client | grep -Fq 'Client Version: v1.37.2' || {
  printf 'Expected kubectl v1.37.2\n' >&2
  exit 2
}

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
chmod 700 "$work_dir"
suffix="$(date -u +%s)-${RANDOM}"
cluster="r42-test-${suffix}"
namespace="remark42-${suffix}"
host="remark42-${suffix}.test"
site="local-${suffix}"
cluster_created=0
watcher_pid=""

cleanup() {
  status=$?
  rm -f "$work_dir/watch-active"
  if [[ -n "$watcher_pid" ]]; then
    kill "$watcher_pid" >/dev/null 2>&1 || true
    wait "$watcher_pid" >/dev/null 2>&1 || true
  fi

  if [[ "$status" -ne 0 && "$cluster_created" -eq 1 ]]; then
    printf '\nIntegration test failed; collecting non-secret diagnostics:\n' >&2
    KUBECONFIG="$work_dir/kubeconfig" kubectl -n "$namespace" get pods,services,ingress,pvc 2>&1 || true
    KUBECONFIG="$work_dir/kubeconfig" kubectl -n "$namespace" describe pods 2>&1 || true
  fi

  if [[ "$cluster_created" -eq 1 ]]; then
    k3d cluster delete "$cluster" >/dev/null 2>&1 || {
      printf 'Warning: failed to delete test cluster %s\n' "$cluster" >&2
      status=1
    }
  fi
  rm -rf "$work_dir"
  if [[ "$status" -eq 0 ]]; then
    printf 'Cleanup complete: deleted only cluster %s and its temporary credentials\n' "$cluster"
  fi
  exit "$status"
}
trap cleanup EXIT

if k3d cluster list --no-headers | awk -v name="$cluster" '$1 == name { found=1 } END { exit !found }'; then
  printf 'Refusing to reuse pre-existing cluster name: %s\n' "$cluster" >&2
  exit 2
fi

https_port="$(python3 - <<'PY'
import socket

with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"

printf 'Creating disposable cluster %s with HTTPS bound to 127.0.0.1:%s\n' "$cluster" "$https_port"
k3d cluster create "$cluster" \
  --servers 1 \
  --agents 0 \
  --image rancher/k3s:v1.31.5-k3s1 \
  --port "127.0.0.1:${https_port}:443@loadbalancer" \
  --kubeconfig-update-default=false \
  --kubeconfig-switch-context=false \
  --wait \
  --timeout 180s
cluster_created=1
k3d kubeconfig get "$cluster" >"$work_dir/kubeconfig"
chmod 600 "$work_dir/kubeconfig"
export KUBECONFIG="$work_dir/kubeconfig"
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null
kubectl create namespace "$namespace" >/dev/null

openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
  -subj '/CN=Remark42 disposable local test CA' \
  -keyout "$work_dir/ca.key" -out "$work_dir/ca.crt" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=${host}" \
  -addext "subjectAltName=DNS:${host}" \
  -keyout "$work_dir/server.key" -out "$work_dir/server.csr" >/dev/null 2>&1
openssl x509 -req -days 2 \
  -in "$work_dir/server.csr" \
  -CA "$work_dir/ca.crt" -CAkey "$work_dir/ca.key" -CAcreateserial \
  -copy_extensions copy \
  -out "$work_dir/server.crt" >/dev/null 2>&1

openssl rand -hex 32 | tr -d '\n' >"$work_dir/remark-secret"
openssl rand -hex 32 | tr -d '\n' >"$work_dir/admin-password"
kubectl -n "$namespace" create secret tls remark42-tls \
  --cert="$work_dir/server.crt" --key="$work_dir/server.key" >/dev/null
kubectl -n "$namespace" create secret generic remark42-auth \
  --from-file=SECRET="$work_dir/remark-secret" \
  --from-file=ADMIN_PASSWD="$work_dir/admin-password" >/dev/null
printf 'user = "admin:%s"\n' "$(cat "$work_dir/admin-password")" >"$work_dir/basic-auth.conf"
chmod 600 "$work_dir/basic-auth.conf"

cat >"$work_dir/values.yaml" <<EOF
image:
  repository: ghcr.io/umputun/remark42
  digest: sha256:00a803ffdde34e8f239eef3e46adbeac44b9ef1a2f366e8b86b413d6908f3ac3
settings:
  url: https://${host}
  site: ${site}
  auth:
    anonymous: false
secret:
  name: remark42-auth
  key: SECRET
  env:
    - name: ADMIN_PASSWD
      key: ADMIN_PASSWD
storage:
  requestedSize: 1Gi
  keepPvc: true
ingress:
  enabled: true
  className: traefik
  hosts:
    - host: ${host}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - ${host}
      secretName: remark42-tls
EOF

traefik_ready=0
for _ in $(seq 1 60); do
  if kubectl get ingressclass traefik >/dev/null 2>&1; then
    traefik_ready=1
    break
  fi
  sleep 2
done
[[ "$traefik_ready" -eq 1 ]] || {
  printf 'K3s did not install the Traefik IngressClass within 120 seconds\n' >&2
  kubectl -n kube-system get pods 2>&1 || true
  kubectl -n kube-system get helmchart traefik traefik-crd \
    -o jsonpath='{range .items[*]}{.metadata.name}: {.status.conditions}{"\n"}{end}' 2>&1 || true
  for pod in $(kubectl -n kube-system get pods -o name | grep 'helm-install-traefik' || true); do
    printf '%s\n' "--- $pod installer output ---" >&2
    kubectl -n kube-system logs "$pod" --tail=50 2>&1 || true
  done
  exit 1
}
helm upgrade --install remark42 "$chart_dir" \
  --namespace "$namespace" --values "$work_dir/values.yaml"
kubectl -n "$namespace" rollout status deployment/remark42 --timeout=300s
kubectl -n "$namespace" wait --for=jsonpath='{.status.phase}'=Bound pvc/remark42 --timeout=180s

curl_local() {
  curl --silent --show-error --fail \
    --resolve "${host}:${https_port}:127.0.0.1" \
    --cacert "$work_dir/ca.crt" \
    --connect-timeout 5 --max-time 30 "$@"
}

retry_curl_local() {
  local attempt
  for attempt in $(seq 1 30); do
    if curl_local "$@" 2>"$work_dir/curl-retry.err"; then
      return 0
    fi
    sleep 1
  done
  cat "$work_dir/curl-retry.err" >&2
  return 1
}

ready=0
for _ in $(seq 1 60); do
  if curl_local -o /dev/null "https://${host}:${https_port}/web/"; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" -eq 1 ]] || {
  printf 'HTTPS ingress did not serve Remark42 /web/ with the generated CA\n' >&2
  exit 1
}
curl_local -o "$work_dir/embed.js" "https://${host}:${https_port}/web/embed.js"
test -s "$work_dir/embed.js"
printf 'PASS: loopback-only HTTPS ingress, generated CA validation, and widget embed asset\n'

python3 - "$work_dir/pixel.png" <<'PY'
import struct
import sys
import zlib

def chunk(name, data):
    return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"\x00\x20\x80\xff\xff"))
png += chunk(b"IEND", b"")
with open(sys.argv[1], "wb") as image:
    image.write(png)
PY

curl_local --config "$work_dir/basic-auth.conf" \
  --form "file=@$work_dir/pixel.png" \
  "https://${host}:${https_port}/api/v1/picture?site=${site}" >"$work_dir/picture.json"
picture_id="$(jq -er '.id' "$work_dir/picture.json")"
curl_local -o "$work_dir/picture-before.png" \
  "https://${host}:${https_port}/api/v1/picture/${picture_id}"
test -s "$work_dir/picture-before.png"

comment="persist-${suffix}"
page="https://example.invalid/remark42-${suffix}"
media_url="https://${host}:${https_port}/api/v1/picture/${picture_id}"
printf '{"text":"%s ![local media](%s)","locator":{"url":"%s","site":"%s"}}' \
  "$comment" "$media_url" "$page" "$site" >"$work_dir/comment.json"
curl_local --config "$work_dir/basic-auth.conf" \
  --header 'Content-Type: application/json' \
  --data-binary "@$work_dir/comment.json" \
  "https://${host}:${https_port}/api/v1/comment?site=${site}" >"$work_dir/comment.json.response"
comment_id="$(jq -er '.id' "$work_dir/comment.json.response")"

find_comment() {
  curl_local --get \
    --data-urlencode "site=${site}" \
    --data-urlencode "url=${page}" \
    "https://${host}:${https_port}/api/v1/find"
}

find_comment >"$work_dir/find.json"
jq -e --arg comment "$comment" 'tostring | contains($comment)' "$work_dir/find.json" >/dev/null
printf 'PASS: synthetic comment created and read; local media uploaded and served\n'

assert_single_ready_pod() {
  kubectl -n "$namespace" get pods -l app.kubernetes.io/instance=remark42 -o json |
    jq -e '[.items[] | select(.status.phase == "Running")] | length == 1' >/dev/null
}

runtime_pod="$(kubectl -n "$namespace" get pods \
  -l app.kubernetes.io/instance=remark42 -o jsonpath='{.items[0].metadata.name}')"
runtime_node="$(kubectl -n "$namespace" get pod "$runtime_pod" -o jsonpath='{.spec.nodeName}')"
runtime_arch="$(kubectl get node "$runtime_node" -o jsonpath='{.status.nodeInfo.architecture}')"
runtime_image="$(kubectl -n "$namespace" get pod "$runtime_pod" -o jsonpath='{.spec.containers[0].image}')"
runtime_image_id="$(kubectl -n "$namespace" get pod "$runtime_pod" -o jsonpath='{.status.containerStatuses[0].imageID}')"
expected_image='ghcr.io/umputun/remark42@sha256:00a803ffdde34e8f239eef3e46adbeac44b9ef1a2f366e8b86b413d6908f3ac3'
[[ "$runtime_image" == "$expected_image" ]] || {
  printf 'Unexpected image in running pod: %s\n' "$runtime_image" >&2
  exit 1
}
[[ -n "$runtime_image_id" ]] || {
  printf 'Kubernetes did not report the runtime image ID\n' >&2
  exit 1
}
assert_single_ready_pod
printf 'Runtime image: %s\nRuntime image ID: %s\nRuntime node architecture: %s\n' \
  "$runtime_image" "$runtime_image_id" "$runtime_arch"

kubectl -n "$namespace" rollout restart deployment/remark42 >/dev/null
kubectl -n "$namespace" rollout status deployment/remark42 --timeout=300s
assert_single_ready_pod
retry_curl_local --get \
  --data-urlencode "site=${site}" \
  --data-urlencode "url=${page}" \
  "https://${host}:${https_port}/api/v1/find" >"$work_dir/find-after-pod-restart.json"
jq -e --arg comment "$comment" 'tostring | contains($comment)' "$work_dir/find-after-pod-restart.json" >/dev/null
if ! retry_curl_local -o "$work_dir/picture-after-pod-restart.png" \
  "https://${host}:${https_port}/api/v1/picture/${picture_id}"; then
  printf 'Picture %s was unavailable after pod restart; files under /srv/var:\n' "$picture_id" >&2
  kubectl -n "$namespace" exec deployment/remark42 -- find /srv/var -maxdepth 5 -type f -print >&2 || true
  exit 1
fi
cmp "$work_dir/picture-before.png" "$work_dir/picture-after-pod-restart.png"

cat >"$work_dir/watch-pods.sh" <<'WATCH'
#!/usr/bin/env bash
set -eu
touch "$WATCH_DIR/watcher-ready"
while [[ -e "$WATCH_DIR/watch-active" ]]; do
  count="$(kubectl -n "$WATCH_NAMESPACE" get pods \
    -l app.kubernetes.io/instance=remark42 -o json 2>/dev/null |
    jq '[.items[] | select(.status.phase != "Succeeded" and .status.phase != "Failed")] | length' || echo 0)"
  if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 1 )); then
    printf '%s\n' "$count" >"$WATCH_DIR/overlapping-pods"
    exit 0
  fi
  sleep 0.2
done
WATCH
chmod 700 "$work_dir/watch-pods.sh"
export WATCH_DIR="$work_dir" WATCH_NAMESPACE="$namespace"
touch "$work_dir/watch-active"
"$work_dir/watch-pods.sh" &
watcher_pid=$!
for _ in $(seq 1 50); do
  [[ -e "$work_dir/watcher-ready" ]] && break
  sleep 0.1
done
[[ -e "$work_dir/watcher-ready" ]] || {
  printf 'Pod overlap watcher did not start\n' >&2
  exit 1
}
helm upgrade remark42 "$chart_dir" \
  --namespace "$namespace" --values "$work_dir/values.yaml" \
  --set-string podAnnotations.test-revision=changed
kubectl -n "$namespace" rollout status deployment/remark42 --timeout=300s
rm -f "$work_dir/watch-active"
wait "$watcher_pid"
watcher_pid=""
if [[ -e "$work_dir/overlapping-pods" ]]; then
  printf 'More than one Remark42 pod existed during Recreate rollout\n' >&2
  exit 1
fi
assert_single_ready_pod
retry_curl_local --get \
  --data-urlencode "site=${site}" \
  --data-urlencode "url=${page}" \
  "https://${host}:${https_port}/api/v1/find" >"$work_dir/find-after-upgrade.json"
jq -e --arg comment "$comment" 'tostring | contains($comment)' "$work_dir/find-after-upgrade.json" >/dev/null
retry_curl_local -o "$work_dir/picture-after-upgrade.png" \
  "https://${host}:${https_port}/api/v1/picture/${picture_id}"
cmp "$work_dir/picture-before.png" "$work_dir/picture-after-upgrade.png"
printf 'PASS: comment and media persisted after pod restart and Recreate Helm upgrade with no overlapping pods\n'

node_container="$(docker ps --filter "name=^/k3d-${cluster}-server-0$" --format '{{.ID}}')"
[[ -n "$node_container" ]] || {
  printf 'Could not identify the unique test cluster node container\n' >&2
  exit 1
}
docker restart "$node_container" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=240s >/dev/null
kubectl -n "$namespace" rollout status deployment/remark42 --timeout=300s
assert_single_ready_pod
retry_curl_local --get \
  --data-urlencode "site=${site}" \
  --data-urlencode "url=${page}" \
  "https://${host}:${https_port}/api/v1/find" >"$work_dir/find-after-node-restart.json"
jq -e --arg comment "$comment" 'tostring | contains($comment)' "$work_dir/find-after-node-restart.json" >/dev/null
retry_curl_local -o "$work_dir/picture-after-node-restart.png" \
  "https://${host}:${https_port}/api/v1/picture/${picture_id}"
cmp "$work_dir/picture-before.png" "$work_dir/picture-after-node-restart.png"
printf 'PASS: comment and media persisted after restart of the disposable K3s node\n'

delete_status="$(curl_local --config "$work_dir/basic-auth.conf" \
  --output "$work_dir/moderation.json" --write-out '%{http_code}' \
  --request DELETE \
  "https://${host}:${https_port}/api/v1/admin/comment/${comment_id}?site=${site}&url=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$page")")"
[[ "$delete_status" == 200 ]] || {
  printf 'Moderator delete returned HTTP %s, expected 200\n' "$delete_status" >&2
  exit 1
}
find_comment >"$work_dir/find-after-moderation.json"
if jq -e --arg comment "$comment" 'tostring | contains($comment)' "$work_dir/find-after-moderation.json" >/dev/null; then
  printf 'Moderator deletion left the comment visible\n' >&2
  exit 1
fi
printf 'PASS: moderator authenticated locally and removed the synthetic comment\n'
