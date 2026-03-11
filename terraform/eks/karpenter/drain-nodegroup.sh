#!/usr/bin/env bash
# 노드 그룹(nodepool)에 속한 노드에서 파드를 모두 제거(드레인)합니다.
# 사용: ./drain-nodegroup.sh <nodepool명> [--dry-run]
# 예:   ./drain-nodegroup.sh app-web
#       ./drain-nodegroup.sh core --dry-run

set -e

NODEPOOL="${1:?Usage: $0 <nodepool_name> [--dry-run]}"
DRY_RUN=""
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN="--dry-run"

echo "Nodepool: ${NODEPOOL}"

NODES=$(kubectl get nodes -l "nodepool=${NODEPOOL}" -o name)
if [[ -z "${NODES}" ]]; then
  echo "No nodes with label nodepool=${NODEPOOL}"
  exit 0
fi

for NODE in ${NODES}; do
  echo "Draining ${NODE}..."
  kubectl drain "${NODE}" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --force \
    --grace-period=300 \
    ${DRY_RUN}
done

echo "Done."
