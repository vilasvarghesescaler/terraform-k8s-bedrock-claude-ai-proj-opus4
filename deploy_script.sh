#!/usr/bin/env bash
#
# deploy-app.sh — app delivery only. Assumes ALL infra (VPC, EKS cluster,
# node group, RDS/MQ/Redis/DynamoDB, and the k8s connection secrets) is
# already provisioned by Terraform, and that this host has an admin
# instance profile whose role is ALSO an EKS access entry on the cluster.
#
# Does: install tooling -> kubeconfig -> clone -> build -> push to ECR ->
#       deploy manifests -> (optional) Bedrock log analyzer.
#
set -euo pipefail

# ---- Config (override via env) ----
export AWS_REGION="${AWS_REGION:-us-east-1}"
export CLUSTER_NAME="${CLUSTER_NAME:-scaler-eks-cluster}"
export APP_NAMESPACE="${APP_NAMESPACE:-retail-store}"
export SERVICES="${SERVICES:-ui catalog cart checkout orders}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
export BUILD_PLATFORM="${BUILD_PLATFORM:-linux/amd64}"

export REPO_URL="${REPO_URL:-https://github.com/vilasvarghesescaler/retail-store-shop-demo.git}"
export REPO_DIR="${REPO_DIR:-/opt/app/retail-store-shop-demo}"

# ECR repo prefix — MUST match what your k8s manifests expect. The upstream
# app uses "retail-store/<svc>". Override if your manifests differ.
export ECR_PREFIX="${ECR_PREFIX:-retail-store}"

export ENABLE_LOG_ANALYZER="${ENABLE_LOG_ANALYZER:-true}"
export ANALYZER_REPO_URL="${ANALYZER_REPO_URL:-https://github.com/Raj-pro/eks_log_analyzer_through_bedrock.git}"
export ANALYZER_DIR="${ANALYZER_DIR:-/opt/app/eks_log_analyzer_through_bedrock}"
export BEDROCK_MODEL_ID="${BEDROCK_MODEL_ID:-global.anthropic.claude-sonnet-4-6}"

export AWS_DEFAULT_REGION="$AWS_REGION"

log()  { echo -e "\n\033[1;34m==>\033[0m $*"; }
warn() { echo -e "\033[1;33m[warn]\033[0m $*" >&2; }
die()  { echo -e "\033[1;31m[error]\033[0m $*" >&2; exit 1; }
sub()  { echo -e "\033[1;34m  ->\033[0m $*"; }

SUDO=""; [[ "$(id -u)" -ne 0 ]] && SUDO="sudo"

# =====================================================================
# 1. Tooling (Ubuntu/Debian). git, jq, envsubst, aws cli v2, docker, kubectl.
# =====================================================================
install_prereqs() {
  log "Installing tooling"
  export DEBIAN_FRONTEND=noninteractive
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y git jq curl unzip gettext-base ca-certificates \
      python3 python3-pip ec2-instance-connect
  else
    warn "no apt-get; ensure git/jq/curl/unzip/envsubst/python3 are present"
  fi

  if ! command -v aws >/dev/null 2>&1; then
    sub "installing AWS CLI v2"
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    (cd /tmp && unzip -oq awscliv2.zip && $SUDO ./aws/install --update)
    rm -rf /tmp/aws /tmp/awscliv2.zip
  fi

  if ! command -v docker >/dev/null 2>&1; then
    sub "installing Docker"
    curl -fsSL https://get.docker.com | $SUDO sh
    $SUDO systemctl enable --now docker || true
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    sub "installing kubectl"
    local kver; kver="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
    curl -sLO "https://dl.k8s.io/release/${kver}/bin/linux/amd64/kubectl"
    $SUDO install -m 0755 kubectl /usr/local/bin/kubectl && rm -f kubectl
  fi

  aws sts get-caller-identity >/dev/null 2>&1 \
    || die "no AWS credentials (instance profile not attached / not reachable)"
}

# =====================================================================
# 2. Kubeconfig + verify EKS access (IAM admin != EKS admin).
# =====================================================================
setup_context() {
  log "Configuring kubectl for $CLUSTER_NAME"
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

  if ! kubectl get nodes >/dev/null 2>&1; then
    die "kubectl is Unauthorized against the cluster.
  This host's instance-profile role is not an EKS access entry.
  Add it in Terraform, e.g.:
    aws_eks_access_entry            { principal_arn = <this role ARN> }
    aws_eks_access_policy_association { policy_arn = .../AmazonEKSClusterAdminPolicy }
  (or add the role to the aws-auth ConfigMap), then re-run."
  fi
  sub "cluster reachable:"
  kubectl get nodes
}

# =====================================================================
# 3. Clone, build each service, push to ECR.
# =====================================================================
clone_and_build() {
  log "Cloning app + building images"
  $SUDO mkdir -p "$(dirname "$REPO_DIR")"; $SUDO chown "$(id -u):$(id -g)" "$(dirname "$REPO_DIR")" || true
  if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" pull --ff-only || true
  else
    git clone "$REPO_URL" "$REPO_DIR"
  fi
  [[ -d "$REPO_DIR/src" ]] || die "repo has no src/ ($REPO_DIR)"

  local ACCOUNT_ID REGISTRY
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  sub "registry: $REGISTRY"

  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY"

  local svc src repo
  for svc in $SERVICES; do
    src="$REPO_DIR/src/$svc"
    [[ -f "$src/Dockerfile" ]] || { warn "no Dockerfile for $svc; skipping"; continue; }
    repo="${ECR_PREFIX}/${svc}"

    aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1 \
      || aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" >/dev/null

    sub "building $svc"
    docker build --platform "$BUILD_PLATFORM" -t "$REGISTRY/$repo:$IMAGE_TAG" "$src"
    docker push "$REGISTRY/$repo:$IMAGE_TAG"
    sub "pushed $REGISTRY/$repo:$IMAGE_TAG"
  done
}

# =====================================================================
# 4. Deploy manifests. Secrets already exist (Terraform), so only apply
#    deployments and force the correct image.
# =====================================================================
deploy_app() {
  log "Deploying manifests"
  local ACCOUNT_ID REGISTRY
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

  # export under common names so envsubst fills whatever the YAML uses
  export ACCOUNT_ID ACC_ID="$ACCOUNT_ID" AWS_ACCOUNT_ID="$ACCOUNT_ID" ACCOUNT="$ACCOUNT_ID"
  export REGISTRY REGISTRY_URL="$REGISTRY" ECR_REGISTRY="$REGISTRY"
  export REGION="$AWS_REGION" AWS_REGION IMAGE_TAG

  kubectl get ns "$APP_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$APP_NAMESPACE"

  local mdir="$REPO_DIR/k8s-manifests" svc f applied=0
  [[ -d "$mdir" ]] || { warn "no $mdir; skipping"; return 0; }

  for svc in $SERVICES; do
    f="$mdir/${svc}-deployment.yaml"
    if [[ -f "$f" ]]; then
      sub "applying $svc"
      envsubst < "$f" | kubectl apply -n "$APP_NAMESPACE" -f -
      applied=$((applied+1))
    else
      warn "no manifest for $svc"
    fi
  done
  [[ "$applied" -gt 0 ]] || { warn "no manifests applied"; return 0; }

  # Force the correct image in case a manifest used a variable we didn't fill.
  for svc in $SERVICES; do
    local cname
    cname=$(kubectl get deploy "$svc" -n "$APP_NAMESPACE" \
            -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null || true)
    [[ -z "$cname" ]] && continue
    kubectl set image "deployment/$svc" -n "$APP_NAMESPACE" \
      "${cname}=${REGISTRY}/${ECR_PREFIX}/${svc}:${IMAGE_TAG}" >/dev/null 2>&1 \
      && sub "set $svc -> ${REGISTRY}/${ECR_PREFIX}/${svc}:${IMAGE_TAG}" \
      || warn "could not set image for $svc"
  done

  log "Deployed. Watch: kubectl get pods -n $APP_NAMESPACE -w"
}

# =====================================================================
# 5. Bedrock EKS log analyzer (optional). Admin instance profile already
#    covers bedrock:InvokeModel + logs, so no IAM changes here.
# =====================================================================
# =====================================================================
# 5. Bedrock EKS log analyzer (optional). Generated locally — not cloned.
#    Admin instance profile already covers bedrock:InvokeModel + logs.
# =====================================================================
setup_log_analyzer() {
  [[ "$ENABLE_LOG_ANALYZER" == "true" ]] || return 0
  log "Setting up Bedrock log analyzer (generated locally)"

  mkdir -p "$ANALYZER_DIR"

  # ---- resolve an active Anthropic model; prefer Sonnet ----
  local detected
  detected=$(aws bedrock list-foundation-models --by-provider anthropic --region "$AWS_REGION" \
    --query "modelSummaries[?modelLifecycle.status=='ACTIVE'].modelId" --output text 2>/dev/null \
    | tr '\t' '\n' | grep -i sonnet | tail -1 || true)
  [[ -n "$detected" ]] && BEDROCK_MODEL_ID="$detected"
  case "$BEDROCK_MODEL_ID" in
    us.*|eu.*|apac.*|global.*) : ;;
    anthropic.*) BEDROCK_MODEL_ID="us.${BEDROCK_MODEL_ID}" ;;
  esac
  sub "model: $BEDROCK_MODEL_ID"

  # ---- python dep (awscli v2 bundles its own boto3; system python has none) ----
  pip3 install -q boto3 --break-system-packages 2>/dev/null \
    || pip3 install -q boto3 2>/dev/null \
    || warn "boto3 install failed; run: pip3 install boto3"

  # ---- .env (UNQUOTED heredoc so these values expand) ----
  cat > "$ANALYZER_DIR/.env" <<ENVEOF
AWS_REGION=${AWS_REGION}
CLUSTER_NAME=${CLUSTER_NAME}
BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID}
ENVEOF

  # ---- the analyzer (QUOTED heredoc so NOTHING expands) ----
  cat > "$ANALYZER_DIR/eks_log_analyzer.py" <<'PYEOF'
#!/usr/bin/env python3
"""
eks_log_analyzer.py — pull EKS control-plane logs from CloudWatch Logs and ask
a Bedrock (Claude) model to summarize errors, warnings, and likely root causes.

Config via .env or environment:
  AWS_REGION        AWS region                      (default us-east-1)
  CLUSTER_NAME      EKS cluster -> /aws/eks/<name>/cluster
  BEDROCK_MODEL_ID  Bedrock model / inference-profile id
Flags: --hours N  --limit N  --filter '<pattern>'  --max-tokens N
"""
import argparse
import json
import os
import sys
import time

import boto3
from botocore.exceptions import ClientError


def load_dotenv(path=".env"):
    if not os.path.exists(path):
        return
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip().strip('"').strip("'"))


def fetch_logs(region, cluster, hours, limit, pattern):
    client = boto3.client("logs", region_name=region)
    group = "/aws/eks/{}/cluster".format(cluster)
    start = int((time.time() - hours * 3600) * 1000)
    kwargs = {"logGroupName": group, "startTime": start}
    if pattern:
        kwargs["filterPattern"] = pattern

    events = []
    try:
        paginator = client.get_paginator("filter_log_events")
        for page in paginator.paginate(**kwargs):
            for e in page.get("events", []):
                events.append(e["message"].rstrip())
                if len(events) >= limit:
                    return group, events
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code == "ResourceNotFoundException":
            sys.exit(
                "log group {} not found. Enable EKS control-plane logging "
                "(Terraform: enabled_cluster_log_types on the cluster).".format(group)
            )
        sys.exit("error reading logs from {}: {}".format(group, e))
    return group, events


def analyze(region, model_id, group, events, max_tokens):
    if not events:
        return "No log events found in the requested window."

    text = "\n".join(events)
    cap = 60000
    if len(text) > cap:
        text = text[-cap:]

    prompt = (
        "You are an SRE assistant analyzing Amazon EKS control-plane logs from "
        "the CloudWatch log group {}. Identify errors, warnings, auth failures, "
        "throttling, and repeated or anomalous patterns. Then give: (1) a short "
        "summary, (2) the most likely root causes, (3) concrete next steps. Be "
        "concise and specific.\n\n"
        "=== LOGS START ===\n{}\n=== LOGS END ==="
    ).format(group, text)

    rt = boto3.client("bedrock-runtime", region_name=region)
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
    }
    try:
        resp = rt.invoke_model(modelId=model_id, body=json.dumps(body))
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code in ("AccessDeniedException", "ValidationException"):
            sys.exit(
                "Bedrock invoke failed ({}). Enable model access for {} in the "
                "Bedrock console, and use an inference-profile id if the model "
                "requires one.".format(code, model_id)
            )
        sys.exit("Bedrock error: {}".format(e))

    payload = json.loads(resp["body"].read())
    parts = [b.get("text", "") for b in payload.get("content", []) if b.get("type") == "text"]
    return "\n".join(parts).strip() or "(model returned no text)"


def main():
    load_dotenv()
    ap = argparse.ArgumentParser(description="Analyze EKS control-plane logs with Bedrock.")
    ap.add_argument("--hours", type=float, default=1.0, help="look-back window in hours")
    ap.add_argument("--limit", type=int, default=500, help="max log events to pull")
    ap.add_argument("--filter", default="", help="CloudWatch Logs filter pattern")
    ap.add_argument("--max-tokens", type=int, default=1500, help="model max output tokens")
    args = ap.parse_args()

    region = os.environ.get("AWS_REGION", "us-east-1")
    cluster = os.environ.get("CLUSTER_NAME")
    model_id = os.environ.get("BEDROCK_MODEL_ID")
    if not cluster:
        sys.exit("CLUSTER_NAME not set (put it in .env or the environment).")
    if not model_id:
        sys.exit("BEDROCK_MODEL_ID not set (put it in .env or the environment).")

    print("region={} cluster={} model={}".format(region, cluster, model_id))
    group, events = fetch_logs(region, cluster, args.hours, args.limit, args.filter)
    print("pulled {} event(s) from {}".format(len(events), group))
    print("-" * 60)
    print(analyze(region, model_id, group, events, args.max_tokens))


if __name__ == "__main__":
    main()
PYEOF

  log "Analyzer written to $ANALYZER_DIR/eks_log_analyzer.py"
  echo "  One-time manual step: enable Bedrock model access for $BEDROCK_MODEL_ID"
  echo "  in the Bedrock console (Model access), then run:"
  echo "    cd $ANALYZER_DIR && python3 eks_log_analyzer.py"
}

main() {
  install_prereqs
  setup_context
  clone_and_build
  deploy_app
  setup_log_analyzer
  log "All done."
}
main "$@"