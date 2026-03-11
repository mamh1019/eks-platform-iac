# EFS 연동 (EKS 노드 그룹용)

EKS 노드(예: `example-eks-infra-eks-app-nodes`)에서 **Amazon EFS**를 스토리지로 사용하기 위한 Terraform 모듈이다.

## 적용 순서

| 순서 | 대상 | 설명 |
|------|------|------|
| 0 | **EKS outputs 갱신** | `terraform/eks` 에서 `node_security_group_id` output이 추가되어 있으므로, EKS 디렉터리에서 **한 번** `terraform apply` 실행해 state/output 갱신. |
| 1 | **IAM** | EFS CSI Driver용 Role 추가 후 `terraform apply` |
| 2 | **EFS** (`terraform/efs`) | EFS 파일 시스템 + Mount Target + SG 생성 |
| 3 | **EFS CSI Addon** (`terraform/eks/addons/efs-csi`) | CSI 드라이버 + 정적 PV `efs-web` (루트 마운트) |

---

## 0. EKS output 갱신 (최초 1회)

EFS가 EKS 노드 보안 그룹 ID를 참조하므로, output 추가 후 state를 갱신한다.

```bash
cd terraform/eks
terraform apply   # 리소스 변경 없음, output만 반영
```

---

## 1. IAM 적용 (EFS CSI Driver Role)

```bash
cd terraform/iam
terraform init
terraform plan
terraform apply
```

- `efs_csi_driver_role_arn` output 확인.

---

## 2. EFS 생성 (terraform/efs)

**사전 조건:** VPC, EKS 적용 완료. EKS에 `node_security_group_id` output이 있어야 함.

```bash
cd terraform/efs
terraform init
terraform plan   # aws_efs_file_system, aws_efs_mount_target, aws_security_group 확인
terraform apply
```

- 생성되는 리소스:
  - `aws_efs_file_system`: 암호화된 EFS
  - `aws_security_group`: EKS 노드 보안 그룹에서 NFS(2049) 허용
  - `aws_efs_mount_target`: Private 서브넷당 1개 (EKS 노드와 동일 서브넷)

- **output:** `file_system_id` → EFS CSI addon에서 정적 PV에 사용됨.

---

## 3. EFS CSI Addon 적용 (terraform/eks/addons/efs-csi)

**사전 조건:** EFS apply 완료 (remote state에 `file_system_id` 존재).

```bash
cd terraform/eks/addons/efs-csi
terraform init
terraform plan
terraform apply
```

- 생성되는 리소스:
  - ServiceAccount: `efs-csi-controller-sa`, `efs-csi-node-sa`
  - Pod Identity 연동 (IAM Role 연결)
  - Helm: `aws-efs-csi-driver`
  - 정적 PV: `efs-web` (EFS 루트 그대로 마운트, 여러 앱/EC2에서 동일 경로 공유)

---

## 4. 동작 확인

```bash
kubectl get pv efs-web
# efs-web PV 존재 확인

kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-efs-csi-driver
# controller, node(daemonset) Running 확인
```

---

## 5. EFS 사용 방식 (정적 PV, 루트 마운트)

EFS **루트**를 그대로 마운트. EKS Pod는 `/var/shared`에 마운트하고, 다른 EC2에서도 동일 EFS 루트를 마운트하면 같은 디렉터리 구조를 볼 수 있음.

웹 앱은 **정적 PV `efs-web`** + PVC `web-data`(volumeName: efs-web) + **마운트 경로 `/var/shared`** 로 설정되어 있음.

## 6. 웹 노드 그룹에서 PVC 사용 예시

```yaml
# pvc.yaml - 정적 바인딩 (EFS 루트)
spec:
  volumeName: efs-web
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 10Gi
```

```yaml
# Deployment에서
spec:
  volumes:
    - name: dw
      persistentVolumeClaim:
        claimName: web-data
  containers:
    - name: app
      volumeMounts:
        - name: dw
          mountPath: /var/shared
```

---

## 7. 삭제 순서

Addon → EFS 순서로 제거.

```bash
cd terraform/eks/addons/efs-csi
terraform destroy

cd ../../../efs
terraform destroy
```
