# Karpenter (앱별 NodePool)

EKS 클러스터 **생성 후** 이 디렉터리에서 적용합니다. 앱별 NodePool로 Pending Pod가 생기면 해당 풀에서 EC2 노드를 자동 프로비저닝합니다.

## 사전 조건

- **EKS** 적용 완료 (상위 `terraform/eks`에서 클러스터 + 코어 노드 그룹 생성)
- **VPC** private 서브넷에 태그: `karpenter.sh/discovery = <cluster_name>`
- **EKS** 노드 보안 그룹에 태그: `karpenter.sh/discovery = <cluster_name>`

(상위 EKS/VPC Terraform에서 이미 설정됨)

## 적용 순서

1. **EKS 생성** (상위 디렉터리)
   ```bash
   cd ../..
   terraform apply
   ```

2. **Karpenter 1단계** — 모듈(IAM/SQS 등) + Helm 컨트롤러 + CRD
   ```bash
   cd terraform/eks/karpenter
   terraform init
   terraform apply -target=module.karpenter -target=helm_release.karpenter
   ```

3. **Karpenter 2단계** — EC2NodeClass, NodePool 생성 (CRD 설치 후)
   ```bash
   terraform apply
   ```

처음 한 번만 2→3 순서로 나눠 적용하면 됩니다. 이후에는 `terraform apply` 한 번으로 충분합니다.

## 구성 요약

| 리소스 | 설명 |
|--------|------|
| **NodePool** | `var.app_node_groups` 기준으로 앱별 풀 (예: app-web, app-api). requirements, limits, taints, **disruption**(consolidation) |
| **EC2NodeClass** | 노드풀마다 1개. 서브넷/보안그룹(discovery 태그), AMI, IAM, **EC2 Name 태그** (`<cluster>-<nodepool>`) |
| **Helm** | Karpenter 컨트롤러 1레플리카, 코어 노드(`karpenter.sh/controller: "true"`)에만 스케줄 |

- 노드풀별 EC2NodeClass를 두어, AWS 콘솔에서 인스턴스 Name이 `example-eks-infra-eks-app-web` / `example-eks-infra-eks-app-api` 형태로 보이도록 했습니다.

## 확인

```bash
# kubeconfig (클러스터명은 env 출력 기준)
aws eks update-kubeconfig --name <cluster_name> --region ap-northeast-1

kubectl get nodepool
kubectl get ec2nodeclass
kubectl get nodeclaims
kubectl get nodes -l nodepool=app-web
```

## HPA (CPU 기반 파드 스케일)

- **app-web / app-api**: CPU 70% 넘으면 replica 늘림, 최대 3개  
  `kubectl apply -f hpa-app-web-app-api.yaml`  
  전제: default 네임스페이스에 Deployment 이름이 `app-web`, `app-api` 이어야 함. 각 Deployment의 파드에 **resources.requests.cpu** 가 있어야 HPA가 동작함.

## 테스트 파드

- **단일 노드**: `kubectl apply -f test-pod.yaml` (app-web 풀)
- **스케일업(3대)**: `kubectl apply -f test-scale-up.yaml` (app-api 풀, anti-affinity로 노드 3대)

워크로드 배포 시 Pod에 `nodeSelector: nodepool: <풀명>` + 해당 풀 taint에 대한 `tolerations`를 넣으면 해당 NodePool로 노드가 프로비저닝됩니다.

- **Consolidation**: NodePool에 `disruption.consolidationPolicy: WhenEmptyOrUnderutilized`, `consolidateAfter: 30s` 를 두어, 파드가 없거나 사용률이 낮은 노드는 약 30초 후 자동으로 정리됩니다. (이전에 이 설정이 없으면 빈 노드가 바로 줄지 않을 수 있음)

## 트러블슈팅

- **EC2NodeClass 삭제가 오래 걸릴 때**
  finalizer 제거: `kubectl patch ec2nodeclass <name> -p '{"metadata":{"finalizers":null}}' --type=merge`
- **Karpenter Pod Pending / 노드 안 생김**
  `./debug-karpenter.sh` 또는 Karpenter 로그: `kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=80`

## 참고

- `data.aws_eks_cluster`로 이미 만든 클러스터를 조회합니다.
- EC2NodeClass/NodePool은 Karpenter CRD가 있어야 하므로 Helm 설치 후에만 적용 가능합니다.
