#!/usr/bin/env bash
# Deploy the AI Companion to Cloud Run from source.
# Usage: PROJECT_ID=my-project ./deploy-cloud-run.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
SERVICE="${SERVICE:-ai-companion}"
SECRET_NAME="${SECRET_NAME:-GEMINI_API_KEY}"
MODEL="${COMPANION_MODEL:-gemini-3.5-flash}"

if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "ERROR: set PROJECT_ID, e.g. PROJECT_ID=my-project $0" >&2
  exit 1
fi

# The key comes from the environment or from .env, never from a committed file.
if [[ -z "${GEMINI_API_KEY:-}" && -f .env ]]; then
  GEMINI_API_KEY="$(grep -E '^GEMINI_API_KEY=' .env | head -1 | cut -d= -f2-)"
fi
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "ERROR: set GEMINI_API_KEY (export it or put it in .env)" >&2
  exit 1
fi

echo "==> Project $PROJECT_ID / region $REGION / service $SERVICE"
gcloud config set project "$PROJECT_ID" --quiet

echo "==> Enabling required APIs"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  --project "$PROJECT_ID" --quiet

echo "==> Storing the API key in Secret Manager"
if gcloud secrets describe "$SECRET_NAME" --project "$PROJECT_ID" >/dev/null 2>&1; then
  printf '%s' "$GEMINI_API_KEY" | gcloud secrets versions add "$SECRET_NAME" \
    --project "$PROJECT_ID" --data-file=- --quiet
else
  printf '%s' "$GEMINI_API_KEY" | gcloud secrets create "$SECRET_NAME" \
    --project "$PROJECT_ID" --replication-policy=automatic --data-file=- --quiet
fi

echo "==> Deploying (first build takes a few minutes)"
gcloud run deploy "$SERVICE" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --source . \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3 \
  --set-secrets "GEMINI_API_KEY=${SECRET_NAME}:latest" \
  --set-env-vars "COMPANION_MODEL=${MODEL},GOOGLE_GENAI_USE_VERTEXAI=FALSE" \
  --quiet

URL="$(gcloud run services describe "$SERVICE" --project "$PROJECT_ID" --region "$REGION" \
  --format='value(status.url)')"
echo
echo "Deployed: $URL"
echo "Health check: curl -s $URL/healthz"
