이 디렉토리는 웹 인프라를 구성하기 위한 Terraform 코드들을
**역할 단위**로 분리하여 관리하는 구조입니다.

각 하위 디렉토리는 특정 인프라 영역을 담당하며,
세부 구현 및 사용 방법은 각 폴더 내부의 README 또는 코드 자체를 기준으로 합니다.

> Terraform state는 **S3 remote backend** 기준으로 관리됩니다. (DynamoDB lock)

---

## Remote State (S3)

State는 S3에 저장되고 S3 네이티브 잠금(`use_lockfile`)으로 locking됩니다. (Terraform 1.10+, DynamoDB 불필요)

**사전 준비:** S3 버킷 `example-eks-infra-tfstate` 생성 필요.

**초기화:** 각 디렉터리에서 `terraform init -backend-config`로 공통 설정 적용. `backend.hcl` 경로는 디렉터리 깊이에 따라 상대 경로 지정.

```bash
# terraform/env, iam, vpc, eks, efs (1단계 하위)
terraform init -backend-config=../backend.hcl

# terraform/eks/karpenter (2단계 하위)
terraform init -backend-config=../../backend.hcl

# terraform/eks/addons/* (3단계 하위)
terraform init -backend-config=../../../backend.hcl
```

---

## 디렉토리 구성

### `eks/`
EKS 클러스터 및 노드 관련 리소스를 정의합니다.

- EKS 클러스터
- Managed Node Group
- EKS Access Entry
- EKS Add-ons
- 공통 로컬 변수 및 출력 값

---

### `vpc/`
EKS에서 사용하는 네트워크 리소스를 정의합니다.

- VPC
- Subnet (Public / Private)
- NAT / Internet Gateway
- Routing 구성

---

### `iam/`
EKS 및 컨트롤러에서 사용하는 IAM 리소스를 정의합니다.

- IAM Role
- IAM Policy
- 컨트롤러(ALB 등)용 정책
- Terraform 변수 및 출력 값

---

## 운영 방향

- 각 디렉토리는 **독립적으로 관리 및 적용**될 수 있도록 구성되어 있습니다.
- 이후 앱 단위 확장, 자동 프로비저닝(Karpenter) 도입을 고려한 구조입니다.

---

## 리소스 생성 (Apply)

생성은 **의존성 순서**대로 진행합니다. 아래 순서대로 각 디렉토리에서 `terraform apply` 실행.

| 순서 | 디렉토리 | 설명 |
|------|----------|------|
| 1 | `env/` | 변수 및 출력 값 (AWS 리소스 없음) |
| 2 | `iam/` | ALB Controller / EFS CSI용 IAM Role, Policy |
| 3 | `vpc/` | VPC, 서브넷, NAT GW 등 |
| 4 | `eks/` | EKS 클러스터 + 노드 그룹 |
| 5 | `efs/` | EFS 파일시스템 + 마운트 타겟 (선택) |
| 6 | `eks/addons/alb-controller/` | ALB Controller Helm |
| 7 | `eks/addons/external-secrets/` | External Secrets Operator (AWS Secrets Manager 연동) |
| 8 | `eks/addons/efs-csi/` | EFS CSI Driver + StorageClass (동적 프로비저닝) |
| 9 | `eks/addons/monitoring/` | Prometheus + Grafana (efs-csi 선 적용 필요) |
| 10a | `eks/karpenter/` | Karpenter 1단계: 모듈(IAM/SQS) + Helm(CRD) |
| 10b | `eks/karpenter/` | Karpenter 2단계: EC2NodeClass, NodePool |
| 11 | `eks/addons/argocd/` | ArgoCD Helm + Ingress |

### 최초 설정 (1회)

각 디렉터리에서 `terraform init -backend-config=...` 실행. 경로는 디렉터리 깊이에 따라 다름.

```bash
cd terraform/env && terraform init -backend-config=../backend.hcl && cd -
cd terraform/iam && terraform init -backend-config=../backend.hcl && cd -
cd terraform/vpc && terraform init -backend-config=../backend.hcl && cd -
cd terraform/eks && terraform init -backend-config=../backend.hcl && cd -
cd terraform/efs && terraform init -backend-config=../backend.hcl && cd -
cd terraform/eks/addons/alb-controller && terraform init -backend-config=../../../backend.hcl && cd -
cd terraform/eks/addons/external-secrets && terraform init -backend-config=../../../backend.hcl && cd -
cd terraform/eks/addons/efs-csi && terraform init -backend-config=../../../backend.hcl && cd -
cd terraform/eks/addons/monitoring && terraform init -backend-config=../../../backend.hcl && cd -
cd terraform/eks/karpenter && terraform init -backend-config=../../backend.hcl && cd -
cd terraform/eks/addons/argocd && terraform init -backend-config=../../../backend.hcl && cd -
```

### 예시 명령 (Apply, 프로젝트 루트 기준)

```bash
cd terraform/env                      && terraform apply -auto-approve && cd -
cd terraform/iam                    && terraform apply -auto-approve && cd -
cd terraform/vpc                    && terraform apply -auto-approve && cd -
cd terraform/eks                     && terraform apply -auto-approve && cd -
cd terraform/efs                    && terraform apply -auto-approve && cd -  # EFS 사용 시
cd terraform/eks/addons/alb-controller && terraform apply -auto-approve && cd -
cd terraform/eks/addons/external-secrets && terraform apply -target=helm_release.external_secrets -auto-approve && terraform apply -auto-approve && cd -
cd terraform/eks/addons/efs-csi      && terraform apply -auto-approve && cd -  # EFS 사용 시
cd terraform/eks/addons/monitoring   && terraform apply -auto-approve && cd -
cd terraform/eks/karpenter           && \
  terraform apply -target=module.karpenter -target=helm_release.karpenter -auto-approve && \
  terraform apply -auto-approve && cd -  # 1단계: 모듈+Helm(CRD) → 2단계: EC2NodeClass/NodePool
cd terraform/eks/addons/argocd       && terraform apply -auto-approve && cd -
```

- 각 단계의 state는 S3에 저장됩니다 (로컬에 tfstate 파일 생성 안 함).
- VPC, IAM이 있어야 EKS를 생성할 수 있습니다.
- EFS CSI, ArgoCD 등 Addon은 EKS 클러스터 생성 후 적용합니다.
- **Karpenter**는 CRD가 Helm으로 설치된 뒤에 EC2NodeClass/NodePool을 생성해야 하므로 2단계 apply 필요. 상세는 `terraform/eks/karpenter/README.md` 참고.
- **External Secrets**는 Helm(CRD) 설치 후 ClusterSecretStore를 생성해야 하므로 2단계 apply 필요.

### 기존 monitoring → 동적 프로비저닝 전환 시 (efs-csi StorageClass 적용)

정적 PV → 동적 프로비저닝 전환 시, 아래 순서대로 진행. (프로젝트 루트 기준)

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

---

## 리소스 정리 (Tear down)

삭제는 **만들어진 순서의 역순**으로 진행합니다. 아래 순서대로 각 디렉토리에서 `terraform destroy` 실행.

| 순서 | 디렉토리 | 설명 |
|------|----------|------|
| 1 | `eks/addons/argocd/` | ArgoCD Helm + Ingress (ArgoCD가 배포한 Application 포함) |
| 2 | `eks/addons/monitoring/` | Prometheus + Grafana |
| 3 | `eks/addons/external-secrets/` | External Secrets Operator |
| 4 | `eks/addons/efs-csi/` | EFS CSI Driver + StorageClass |
| 5 | `eks/addons/alb-controller/` | ALB Controller Helm |
| 6 | `eks/karpenter/` | Karpenter NodePool, EC2NodeClass, Helm |
| 7 | `efs/` | EFS 파일시스템 + 마운트 타겟 (보안 그룹 의존성으로 EKS보다 먼저) |
| 8 | `eks/` | EKS 클러스터 + 노드 그룹 |
| 9 | `vpc/` | VPC, 서브넷, NAT GW 등 |
| (선택) | `iam/` | ALB Controller / EFS CSI용 IAM — 비용 없음, 남겨둬도 됨 |

`env/`는 AWS 리소스가 없고 변수/출력만 있으므로 destroy 불필요.

### 예시 명령 (Destroy, 프로젝트 루트 기준)

```bash
cd terraform/eks/addons/argocd       && terraform destroy -auto-approve && cd -
cd terraform/eks/addons/monitoring   && terraform destroy -auto-approve && cd -
cd terraform/eks/addons/external-secrets && terraform destroy -auto-approve && cd -
cd terraform/eks/addons/efs-csi      && terraform destroy -auto-approve && cd -
cd terraform/eks/addons/alb-controller && terraform destroy -auto-approve && cd -
cd terraform/eks/karpenter           && terraform destroy -auto-approve && cd -
cd terraform/efs                    && terraform destroy -auto-approve && cd -  # EKS보다 먼저 (보안 그룹 의존성)
cd terraform/eks                     && terraform destroy -auto-approve && cd -
cd terraform/vpc                    && terraform destroy -auto-approve && cd -
# (선택) cd terraform/iam && terraform destroy -auto-approve && cd -
```

- 각 단계의 state는 S3에 저장됨. 새 환경에서 destroy 시에는 먼저 `terraform init -backend-config=...` 실행 후 destroy.
- Addon(ArgoCD, monitoring, external-secrets, efs-csi, ALB Controller, Karpenter)을 먼저 제거한 뒤 EKS를 삭제해야 합니다.
- **EFS**는 EKS 노드 보안 그룹을 참조하므로 EKS보다 먼저 destroy.
- **EFS destroy** 시 파일시스템과 데이터가 삭제됩니다. 남겨두려면 `efs/` 단계를 건너뛰세요.
