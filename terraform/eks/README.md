# EKS Provisioning Guide (PoC)

> 이 문서는 **이미 VPC가 생성되어 있다는 전제** 하에
> EKS 클러스터 생성 → 기본 애드온 확인 → ALB Controller 애드온 설치까지의 절차를 설명한다.

---

## 전체 적용 순서 (요약)

| 순서 | 대상 | 설명 |
|------|------|------|
| 1 | **EKS** (`terraform/eks`) | 클러스터 + 노드 그룹(core, monitoring). 앱 노드는 Karpenter NodePool로 오토스케일. |
| 2 | **ALB Controller** (`terraform/eks/addons/alb-controller`) | Ingress 리소스가 생성될 때 ALB를 만들어 주는 컨트롤러. **Ingress를 쓰는 앱을 배포하기 전에** 반드시 설치. |
| 3 | Ingress 사용 앱 (예: `apps/mi`, `addons/argocd`) | Deployment/Service/Ingress 적용. 이때 ALB Controller가 Ingress를 보고 ALB 생성. |

- **앱 노드** = Karpenter NodePool(app-web, app-api 등)로 오토스케일.
- **Ingress(ALB)** = 앱 Terraform에서 Ingress 리소스를 만들 때 필요 → 그 **전에** ALB Controller만 설치해 두면 됨.

---

## 0. 사전 조건

- AWS CLI 설치
- Terraform 설치 (>= 1.4)
- VPC Terraform 적용 완료
  - `terraform/vpc/terraform.tfstate` 존재
- IAM Role 존재 (`terraform/iam` apply 완료)
  - EBS CSI, ALB Controller, EFS CSI, External Secrets용 Pod Identity Role
- 프로젝트 루트에서 환경 스크립트 사용

```bash
source scripts/env.sh
aws sts get-caller-identity
```

---

## 1. EKS 디렉토리 이동

```bash
cd terraform/eks
```

---

## 2. Terraform 초기화 및 검증

```bash
terraform fmt -recursive
terraform init
terraform validate
```

---

## 3. Plan 확인

```bash
terraform plan -out tfplan
```

### plan 에 반드시 포함되어야 하는 리소스

- `aws_eks_cluster`
- `aws_eks_node_group`
- `aws_eks_addon`
- `aws_eks_access_entry`
- `aws_eks_access_policy_association`

---

## 4. EKS 생성

```bash
terraform apply tfplan
```

> 약 15~25분 소요

---

## 5. kubeconfig 설정

> **클러스터 생성/재생성 후 반드시 실행**

```bash
aws eks update-kubeconfig   --region ap-northeast-1   --name example-eks-infra-eks
```

---

## 6. 노드 상태 확인

```bash
kubectl get nodes
```

정상 출력 예시:

```text
NAME                                               STATUS   ROLES    AGE   VERSION
ip-10-20-xx-xx.ap-northeast-1.compute.internal     Ready    <none>   Xm    v1.34.x
```

---

## 7. 핵심 시스템 파드 확인

```bash
kubectl -n kube-system get pods | egrep "coredns|aws-node|kube-proxy|pod-identity|ebs-csi"
```

모두 `Running` 상태여야 함.

---

## 8. Pod Identity (EBS CSI) 확인

```bash
aws eks list-pod-identity-associations   --cluster-name example-eks-infra-eks
```

다음 항목이 존재해야 함:

- `serviceAccount`: `ebs-csi-controller-sa`
- `roleArn`: IAM 모듈의 `ebs_csi_driver_role_arn` (Pod Identity)

---

# 9. Addons: AWS Load Balancer Controller 설치

> EKS core와 애드온은 **분리 관리**한다.
> ALB Controller는 Helm 기반 애드온이며 **별도 Terraform apply** 대상이다.

---

## 9.1 디렉토리 이동

```bash
cd terraform/eks/addons/alb-controller
```

---

## 9.2 Terraform 초기화

```bash
terraform init -upgrade
terraform validate
```

---

## 9.3 Plan 확인

```bash
terraform plan
```

### 생성되는 리소스

- `kubernetes_service_account_v1`
- `aws_eks_pod_identity_association`
- `helm_release` (aws-load-balancer-controller)

---

## 9.4 애드온 적용

```bash
terraform apply
```

---

## 9.5 ALB Controller 동작 확인

```bash
kubectl -n kube-system get sa aws-load-balancer-controller
kubectl -n kube-system get deploy aws-load-balancer-controller
kubectl -n kube-system get pods | grep load-balancer
```

로그 확인:

```bash
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=200
```
---

## 10. 앱별 NodePool (Karpenter)

앱마다 **전용 NodePool**을 두어, 한 앱의 부하/장애가 다른 앱으로 전파되지 않도록 구성할 수 있다.

### 10.1 동작 방식

- **core** 노드 그룹: 시스템/공통 워크로드용 (EKS Managed Node Group)
- **monitoring** 노드 그룹: Prometheus, Grafana 전용
- **앱별** NodePool: Karpenter(`terraform/eks/karpenter`)의 `var.app_node_groups`에 정의 (app-web, app-api 등)
- 각 NodePool에는 `nodepool = "<앱이름>"` 라벨이 붙으며, 앱 Deployment에서 `nodeSelector: nodepool: <앱이름>`으로 지정하면 해당 풀에만 스케줄됨

### 10.2 앱 NodePool 추가 절차

1. **Karpenter** `terraform/eks/karpenter/variables.tf`의 `app_node_groups`에 엔트리 추가:

   ```hcl
   default = {
     app-web  = {}
     app-api  = {}
     myapp    = { instance_types = ["m7g.large"], min_size = 2, max_size = 4 }
   }
   ```

2. Karpenter 적용: `terraform apply`
3. **앱 모듈** (예: `terraform/apps/myapp/main.tf`) 에서 Deployment 의 Pod spec 에 nodeSelector 추가:

   ```hcl
   node_selector = {
     nodepool = local.app_name   # "myapp"
   }
   ```

4. 앱 적용: `terraform apply`

### 10.3 확인

```bash
kubectl get nodes -l nodepool=app-web
kubectl get nodes -l nodepool=core
```

---

## 11. EFS 연동 (앱 노드 그룹용 스토리지)

앱 전용 노드 그룹(예: `example-eks-infra-eks-app-nodes`)에서 **Amazon EFS**를 쓰려면 아래 순서로 적용한다.

1. **EKS output 갱신** — `terraform/eks` 에서 `terraform apply` 1회 (node_security_group_id 출력용).
2. **IAM** — EFS CSI Driver Role 적용 (`terraform/iam`).
3. **EFS** — 파일 시스템 + Mount Target + SG (`terraform/efs`, 상세 절차는 해당 디렉터리 **README** 참고).
4. **EFS CSI Addon** — CSI 드라이버 + 정적 PV `efs-web` (`terraform/eks/addons/efs-csi`).

이후 앱에서 `volumeName: efs-web` 로 PVC를 바인딩하면 EFS 루트가 마운트된다. 자세한 단계와 PVC 예시는 **`terraform/efs/README.md`** 를 참고.

---

## 12. 다음 단계

- `apps/mi` (앱별 노드 그룹 + nodeSelector 적용됨)
  - Deployment (arm64)
  - Service
  - Ingress (ALB)
- Ingress 생성 후 ALB DNS 접근 확인

---

## 13. 정리 (삭제 순서)

> **항상 Addons → EKS → VPC 순서**

```bash
cd terraform/eks/addons/alb-controller
terraform destroy

cd ../../
terraform destroy
```

---

## 참고 사항

- EKS 접근 권한은 **Access Entry(API 모드)** 사용
- `terraform apply` 실행 주체가 자동으로 클러스터 관리자
- EKS endpoint 변경 시 `aws eks update-kubeconfig` 재실행 필수
