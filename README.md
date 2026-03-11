# example-eks-infra

## 개요

**EKS 기반 웹 인프라 통합 관리**

> 각 인프라 구성요소의 상세한 Terraform 사용법은 하위 디렉토리(예: `terraform/`)의 README를 참고하세요.

---

## 목적

- AWS 상의 웹 인프라 표준화
- EKS 기반 컨테이너 플랫폼 구축
- R&D 단계부터 프로덕션까지 확장 가능한 구조 설계
- Terraform을 통한 IaC(Infrastructure as Code) 일관성 확보

---

## 인프라 범위

- **네트워크**
  - VPC (공용 Shared VPC)
  - Public / Private Subnet
  - NAT Gateway, VPC Endpoint

- **컨테이너 플랫폼**
  - Amazon EKS
  - Managed Node Group
  - Karpenter (확장 고려)

- **보안 및 접근 제어**
  - IAM Role / Policy
    - Node IAM Role은 클러스터 운영에 필요한 최소 권한만 사용
    - 애플리케이션 레벨 AWS 권한은 포함하지 않음
  - IRSA (OIDC 기반 ServiceAccount 권한 관리)
    - 모든 파드의 AWS 리소스 접근 권한은 IRSA로만 관리

- **스토리지 / 데이터**
  - EBS / EFS
  - S3 (데이터 및 로그 저장)

- **트래픽 & 배포**
  - AWS Load Balancer Controller (ALB/NLB)
  - Ingress

---

## 기본 원칙

### 1. Terraform 기반 관리
- 모든 인프라는 Terraform으로 관리
- 수동 콘솔 생성은 지양
- State 기준 단일 소스 유지

### 2. 보안 관련
- 최소 권한 원칙
- 노드 IAM Role에 권한 집중 ❌
- IRSA 기반 권한 분리 ⭕

### 3. 비용 관련
- NAT Gateway, 트래픽 비용 고려 (멀티 AZ + 단일 NAT로 구성)

---

## 디렉토리 구조 (요약)

```text
example-eks-infra/
  terraform/        # Terraform IaC (VPC, EKS, Add-ons 등)
  README.md         # 본 문서 (전체 인프라 개요)
```

> `terraform/` 하위에는 각 컴포넌트별 상세 README가 존재합니다.

---

## 참고

- Terraform 실행 및 삭제 방법은 `terraform/README.md` 참고
