# Terraform – example-eks-infra

이 디렉토리는 **workload 인프라를 Terraform으로 관리**하기 위한 저장소입니다.
현재 범위는 **공용 VPC 생성 및 삭제**입니다.

---

## 📁 디렉토리 구조

```text
terraform/
  README.md
  vpc/
    main.tf
    outputs.tf
    providers.tf
    remote_state.tf
    versions.tf
```

> ⚠️ Terraform 명령은 **반드시 대상 리소스 디렉토리(`terraform/vpc`)에서 실행**해야 합니다.

---

## 🔐 사전 조건 (Prerequisites)

### 필수 도구
- Terraform `>= 1.14.0`
- AWS CLI 설치 및 인증 완료 (`aws configure`)

### 확인 명령
```bash
terraform version
aws sts get-caller-identity
```

---

## 🏷 태그 정책 (중요)

**모든 Terraform 리소스에는 아래 태그가 반드시 포함됩니다.**

```text
createdBy         = example-eks-infra
createdByProject  = example-eks-infra
ManagedBy         = terraform
```

- 위 태그는 `locals.tf`에서 중앙 관리됩니다.
- 태그가 누락된 리소스 생성은 허용하지 않습니다.

---

## 🌐 VPC 생성 (Create)

### 1️⃣ VPC 디렉토리로 이동
```bash
cd terraform/vpc
```

---

### 2️⃣ Terraform 초기화
```bash
terraform init
```

- Provider 및 모듈 다운로드
- AWS 리소스 생성 ❌ (안전)

---

### 3️⃣ 드라이 테스트 (권장)
```bash
terraform plan
```

- 실제 생성/변경될 리소스를 미리 확인
- **이 단계에서는 AWS 리소스가 생성되지 않습니다**

출력 예시:
```text
Plan: 23 to add, 0 to change, 0 to destroy.
```

> ⚠️ `change` 또는 `destroy`가 포함되어 있으면 실행하지 말고 반드시 검토하세요.

---

### 4️⃣ VPC 생성
```bash
terraform apply
```

- `yes` 입력 시 실제 AWS 리소스 생성
- 생성되는 주요 리소스:
  - VPC
  - Public / Private Subnets
  - Internet Gateway
  - NAT Gateway
  - Route Tables

---

## 🧪 실행 계획 저장 (선택)

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

- plan/apply 사이 구성 변경 방지
- 운영 환경에서는 이 방식 사용 권장

---

## 네트워크 구성 확인
```bash
% aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values={VPC_ID} \
  --query "RouteTables[].{RouteTableId:RouteTableId,Routes:Routes[?DestinationCidrBlock=='0.0.0.0/0']}" \
  --output table
```

## 🧹 VPC 삭제 (Destroy)

> ⚠️ **아래 명령은 VPC 및 관련 리소스를 전부 삭제합니다.**
> 실행 전 반드시 영향 범위를 확인하세요.

### 1️⃣ VPC 디렉토리로 이동
```bash
cd terraform/vpc
```

---

### 2️⃣ 삭제 드라이 테스트
```bash
terraform plan -destroy
```

출력 예시:
```text
Plan: 0 to add, 0 to change, 23 to destroy.
```

---

### 3️⃣ VPC 삭제
```bash
terraform destroy
```

- `yes` 입력 시 모든 관련 리소스 삭제

---

## 📤 Outputs

VPC 생성 후 아래 값들이 출력됩니다:

```text
vpc_id
public_subnet_ids
private_subnet_ids
availability_zones
```

이 값들은 **EKS, RDS 등 다른 Terraform 구성에서 재사용**됩니다.

---

## ❗ 주의 사항

- `terraform apply` 전 반드시 `terraform plan` 확인
- 기존 리소스 수정/삭제가 포함되어 있는지 반드시 검토
- `terraform.tfstate` 파일은 **절대 Git에 커밋하지 말 것**

---

