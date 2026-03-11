# Monitoring Addon (Prometheus + Grafana)

Prometheus, Alertmanager, Grafana를 포함한 kube-prometheus-stack을 설치합니다.
**모니터링 전용 노드 그룹**(nodepool=monitoring, 노드 1개)에만 스케줄됩니다.

## 기능

- **Prometheus**: 메트릭 수집 (efs-prometheus-sc StorageClass, retention 15d)
- **Alertmanager**: 기본 설치 (efs-prometheus-sc, 알림은 Grafana UI에서 설정)
- **Grafana**: 대시보드 (efs-grafana-sc StorageClass로 설정 영구 저장)

## 적용 순서

**사전 요구:** `efs` → `eks`(monitoring 노드 그룹 포함) → `efs-csi` 순서로 적용.
Prometheus/Grafana/Alertmanager는 efs-csi addon의 StorageClass(동적 프로비저닝)로 EFS 사용.

### 신규 설치

```bash
cd terraform/eks/addons/monitoring
terraform init -backend-config=../../../backend.hcl
terraform plan
terraform apply
```

### 기존 monitoring → 동적 프로비저닝 전환 시

```bash
# 1) monitoring destroy (Helm uninstall)
cd terraform/eks/addons/monitoring
terraform destroy -auto-approve

# 2) 남은 PVC 정리 (StatefulSet 삭제 시 PVC는 기본 유지됨)
kubectl delete pvc -n monitoring --all
kubectl patch pv efs-grafana -p '{"spec":{"claimRef": null}}' 2>/dev/null || true
kubectl patch pv efs-prometheus -p '{"spec":{"claimRef": null}}' 2>/dev/null || true

# 3) efs-csi apply (StorageClass 생성, 정적 PV 제거)
cd terraform/eks/addons/efs-csi
terraform init -backend-config=../../../backend.hcl
terraform apply -auto-approve

# 4) monitoring apply
cd terraform/eks/addons/monitoring
terraform init -backend-config=../../../backend.hcl
terraform apply -auto-approve
```

## 알림 설정

Grafana UI에서 알림/채널 설정 (EFS에 저장되어 유지됨)

## Grafana 접속

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

- **로그인:** http://localhost:3000 (admin / 비밀번호는 `kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d` 로 확인)
- **클러스터 모니터링 대시보드:**
  http://localhost:3000/d/ecf626759/kubernetes-all-in-one-cluster-monitoring-ko-kr?var-duration=5m&orgId=1&from=now-15m&to=now&timezone=browser&var-node=ip-10-20-xx-xx.ap-northeast-1.compute.internal&var-instance=10.20.xx.xx:9100&var-namespace=argocd&var-pod=argocd-application-controller-0&refresh=30s
