# Deploy

Push/merge till `main` deployar automatiskt till App Engine (`tyco-1286`)
via GitHub Actions (`.github/workflows/deploy.yml`). Inga nycklar används:
GitHub loggar in mot Google Cloud med Workload Identity Federation.

Engångssetup i Google Cloud: `bash scripts/setup-github-deploy.sh`.

Manuell deploy av en testversion (utan att ta trafik):

    gcloud app deploy --no-promote --project tyco-1286
