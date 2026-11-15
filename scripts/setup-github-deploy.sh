#!/usr/bin/env bash
# Engångssetup: låter GitHub Actions deploya till App Engine utan någon
# nyckel/secret, via Workload Identity Federation (kortlivade OIDC-tokens).
#
# Kör från repo-roten efter `gcloud auth login`:
#   bash scripts/setup-github-deploy.sh
#
# Skriptet går att köra flera gånger; det som redan finns hoppas över.
# Kräver en någorlunda ny gcloud (`gcloud components update`); version 315
# från 2020 saknar `gcloud iam workload-identity-pools`.
#
# Redan kört 2026-11-15 (pool "github", provider "ty-co", SA "github-deploy").
set -euo pipefail

PROJECT_ID="tyco-1286"
REPO="peterlagerstrom/ty.co"
# Numeriska GitHub-ID:n (låser åtkomsten till just detta repo även om
# namnet skulle tas över av någon annan i framtiden).
REPO_ID="35733500"
OWNER_ID="1232995"

POOL="github"
PROVIDER="ty-co"
SA_NAME="github-deploy"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gc() { gcloud --project "$PROJECT_ID" --quiet "$@"; }

PROJECT_NUMBER="$(gc projects describe "$PROJECT_ID" --format='value(projectNumber)')"
APP_SA="$(gc app describe --format='value(serviceAccount)')"
APP_SA="${APP_SA:-${PROJECT_ID}@appspot.gserviceaccount.com}"

echo "==> Aktiverar API:er"
gc services enable \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  appengine.googleapis.com \
  cloudbuild.googleapis.com

echo "==> Workload Identity-pool och GitHub-provider"
gc iam workload-identity-pools describe "$POOL" --location global >/dev/null 2>&1 ||
  gc iam workload-identity-pools create "$POOL" --location global \
    --display-name "GitHub Actions"

gc iam workload-identity-pools providers describe "$PROVIDER" \
  --location global --workload-identity-pool "$POOL" >/dev/null 2>&1 ||
  gc iam workload-identity-pools providers create-oidc "$PROVIDER" \
    --location global --workload-identity-pool "$POOL" \
    --display-name "ty.co deploy" \
    --issuer-uri "https://token.actions.githubusercontent.com" \
    --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_id=assertion.repository_id,attribute.ref=assertion.ref" \
    --attribute-condition "assertion.repository_id == '${REPO_ID}' && assertion.repository_owner_id == '${OWNER_ID}' && assertion.ref == 'refs/heads/main'"

echo "==> Servicekonto för deploy"
gc iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1 ||
  gc iam service-accounts create "$SA_NAME" \
    --display-name "GitHub Actions deploy (${REPO})"

for role in \
  roles/appengine.appAdmin \
  roles/storage.admin \
  roles/cloudbuild.builds.editor \
  roles/artifactregistry.reader; do
  gc projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:${SA_EMAIL}" --role "$role" \
    --condition None >/dev/null
done

# Deploy-kontot måste få agera som App Engines runtime-konto.
gc iam service-accounts add-iam-policy-binding "$APP_SA" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role roles/iam.serviceAccountUser >/dev/null

# Endast workflows från detta repo (main-grenen, se villkoret ovan) får
# låna deploy-kontot.
gc iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository_id/${REPO_ID}" >/dev/null

echo
echo "Klart. Värden för .github/workflows/deploy.yml:"
echo "  workload_identity_provider: projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}"
echo "  service_account: ${SA_EMAIL}"
