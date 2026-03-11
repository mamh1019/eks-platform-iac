#!/usr/bin/env bash

# =========================================
# Environment bootstrap for example-eks-infra
# Usage: source scripts/env.sh
# =========================================

# ---- Guard: must be sourced ----
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ This script must be sourced:"
  echo "   source scripts/env.sh"
  return 1 2>/dev/null || exit 1
fi

# ---- Resolve scripts directory (always stable) ----
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_LOCAL="${SCRIPTS_DIR}/env.local"

# ---- Load env.local ----
if [[ -f "${ENV_LOCAL}" ]]; then
  source "${ENV_LOCAL}"
else
  echo "❌ Missing env.local at scripts/"
  echo "👉 Create ${ENV_LOCAL} with AWS_PROFILE / AWS_REGION"
  return 1
fi

# ---- Validate required vars ----
if [[ -z "${AWS_PROFILE}" || -z "${AWS_REGION}" ]]; then
  echo "❌ AWS_PROFILE or AWS_REGION not set in env.local"
  return 1
fi

# ---- Sanity Check ----
if [[ -z "${QUIET}" ]]; then
  echo "🔐 AWS Identity:"
  aws sts get-caller-identity
  echo
fi

# ---- Terraform Aliases ----
alias tf='terraform'
alias tfi='terraform init'
alias tfv='terraform validate'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tff='terraform fmt'
alias tfo='terraform output'
alias tfg='terraform graph'

# ---- kubectl Aliases ----
alias k='kubectl'
alias kc='kubectl config get-contexts'
alias kcu='kubectl config use-context'
alias kca='kubectl config current-context'

echo "✅ Environment loaded (AWS_PROFILE=${AWS_PROFILE}, AWS_REGION=${AWS_REGION})"
