# terraform/env

**환경 공통 값**만 정의하고 state에 출력으로 저장하는 레이어입니다.
리소스는 전혀 만들지 않습니다.

`vpc`, `eks`, `iam` 등 다른 모듈이 `terraform_remote_state`로 이 state를 읽어
`default_tags`, `cluster_name`, `aws_region`, `project` 등을 사용합니다.

---

## 적용 순서 (중요)

**env는 다른 모든 Terraform 모듈보다 먼저 적용해야 합니다.**

```text
1. env   (먼저) → terraform.tfstate 생성
2. vpc   → env state 참조
3. iam   → env state 참조
4. eks   → env, vpc, iam state 참조
5. ...   (apps, addons 등)
```

env state가 없으면 `vpc` / `eks` / `iam`에서 `terraform plan` 시
`Failed to read state` 같은 오류가 납니다.

---

## 사용 방법

### 1. env 디렉터리로 이동

```bash
cd terraform/env
```

### 2. 초기화 및 적용

```bash
terraform init
terraform plan   # 변경 사항 확인 (리소스 없음 → 출력만)
terraform apply  # -auto-approve 또는 확인 후 yes
```

- **리소스는 생성되지 않고**, 변수 값이 `output`으로 `terraform.tfstate`에만 저장됩니다.
- 최초 1회 적용 후, 값(region, project, cluster_name, default_tags)을 바꿀 때만 다시 `apply`하면 됩니다.

### 3. EKS 클러스터 Admin 추가 (선택)

apps/mi 등 다른 디렉터리에서 `terraform apply` 하는 IAM 사용자/역할에 EKS Admin 권한을 주려면  
`additional_admin_principal_arns`에 해당 ARN을 넣습니다. **env**에서 관리하며, EKS가 remote state로 읽어 Access Entry에 반영합니다.

`variables.tf`의 `additional_admin_principal_arns` default 값을 수정한 뒤 env만 다시 apply:

```bash
cd terraform/env
terraform apply
```

이후 EKS를 한 번 더 apply 하면 해당 principal이 클러스터 Admin으로 등록됩니다.

### 4. 다른 모듈 사용

env 적용이 끝났으면, 이제 `terraform/vpc`, `terraform/eks` 등에서 평소처럼 사용하면 됩니다.

```bash
cd ../vpc
terraform init
terraform plan
terraform apply
```

---

## vpc 먼저 적용했는데 에러가 안 났을 때

예전에 `terraform/env`를 한 번이라도 apply 해두었다면 `env/terraform.tfstate`가 **로컬**에 이미 있습니다.  
vpc는 이 파일을 읽어서 `default_tags`, `cluster_name` 등을 쓰기 때문에, env를 다시 안 해도 에러가 나지 않는 겁니다.

`*.tfstate`는 `.gitignore`에 있어서 Git에는 올라가지 않습니다.  
그래서 **새로 클론한 저장소**나 **다른 PC**에서는 env state가 없으므로, 그런 환경에서는 반드시 env를 먼저 apply 해야 합니다.

---
