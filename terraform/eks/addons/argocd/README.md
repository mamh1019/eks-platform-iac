# ArgoCD Addon

EKS 클러스터에 ArgoCD를 설치하고, **ALB Ingress**로 외부(또는 사내)에서 접속할 수 있게 구성합니다.

---

## 구조

- **Terraform 리소스**
  - `helm_release.argocd`: ArgoCD Helm 차트 설치 (namespace `argocd`, server ClusterIP, HTTP 모드)
  - `kubernetes_ingress_v1.argocd`: ALB Ingress → argocd-server Service

- **접속 흐름**
  ```
  User → ALB → Ingress → argocd-server Service → Pod
  ```

- **노드 배치**
  - ArgoCD Pod는 `nodeSelector: nodepool=core`로 코어 노드에만 스케줄됨.

---

## 사전 조건

- env, vpc, iam, **eks** apply 완료
- **ALB Controller** addon 적용 완료 (Ingress용)

---

## 설치

```bash
cd terraform/eks/addons/argocd
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 설치 후 확인

**Pod**
```bash
kubectl get pods -n argocd
```

**ALB 주소 (Ingress 생성 후 1~2분 소요 가능)**
```bash
kubectl get ingress -n argocd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
echo
```

**초기 admin 비밀번호**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
```

- **UI:** `http://<ALB hostname>/` (HTTP, server.insecure 사용)
- **로그인:** 사용자 `admin`, 비밀번호 위에서 출력된 값

---

## admin 비밀번호 변경 (터미널)

```bash
# 1) bcrypt 해시 생성 (원하는 비밀번호로 교체)
NEW_PWD=$(htpasswd -nbBC 10 "" example1234 | tr -d ':\n' | sed 's/$2y/$2a/')

# 2) argocd-secret 패치
kubectl -n argocd patch secret argocd-secret -p "{\"stringData\": {\"admin.password\": \"$NEW_PWD\", \"admin.passwordMtime\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"

# 3) argocd-server 재시작
kubectl -n argocd rollout restart deployment argocd-server
```

---

## 설정 요약

| 항목 | 값 |
|------|-----|
| Helm chart | argo-cd 7.7.10 (argoproj/argo-helm) |
| Namespace | argocd |
| Server | ClusterIP, HTTP(insecure) |
| Ingress | ALB, internet-facing, path / → argocd-server:80 |

---

## 다음 단계 (ArgoCD UI에서 진행)

앱 배포는 **ArgoCD UI에서 Application 생성**으로 한다. 이 addon은 ArgoCD 설치만 담당.

1. **Repository 등록**
   Settings → Repositories → Connect Repo
   - URL: 사용할 Git repo (예: `https://github.com/your-username/your-repo`)
   - Private이면 인증(HTTPS/SSH 키 또는 토큰) 설정.

2. **Application 생성**
   New App → 소스 Repo/Path/Revision, Destination 클러스터·네임스페이스, Sync Policy 등 설정 후 Create.

3. (선택) HTTPS
   도메인 + ACM 인증서 붙이면 ALB에서 TLS 적용 가능.

---

## 정리 (삭제)

```bash
cd terraform/eks/addons/argocd
terraform destroy
```
