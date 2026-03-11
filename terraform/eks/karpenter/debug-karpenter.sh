#!/bin/bash
# Karpenter 프로비저닝 안 될 때 상태 확인
set -e
echo "=== 1. Pending Pod 이벤트 ==="
kubectl describe pod test-karpenter-app-web 2>/dev/null | tail -20 || true

echo ""
echo "=== 2. NodeClaim (Karpenter가 만든 노드 요청) ==="
kubectl get nodeclaims -o wide 2>/dev/null || true

echo ""
echo "=== 3. NodePool 상태 (conditions) ==="
kubectl get nodepool -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null || true
kubectl get nodepool app-web -o yaml | grep -A 20 "status:" || true

echo ""
echo "=== 4. EC2NodeClass 상태 ==="
kubectl get ec2nodeclass default -o yaml 2>/dev/null | grep -A 30 "status:" || true

echo ""
echo "=== 5. Karpenter Pod 동작 여부 ==="
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter -o wide

echo ""
echo "=== 6. Karpenter 로그 (마지막 50줄) ==="
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50 2>/dev/null || true
