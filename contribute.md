# Deploy

Push/merge till `main` deployar automatiskt till App Engine (`tyco-1286`)
via GitHub Actions (`.github/workflows/deploy.yml`). Inga nycklar används:
GitHub loggar in mot Google Cloud med Workload Identity Federation.

I Google Cloud finns (uppsatt 2026-11-15): Workload Identity-poolen
`github` med providern `ty-co` (godtar bara detta repo och grenen `main`)
och servicekontot `github-deploy`.

Manuell deploy av en testversion (utan att ta trafik):

    gcloud app deploy --no-promote --project tyco-1286
