# Custom Action Örnekleri

Bu klasörde üç gerçekçi GitHub Actions örneği var; her biri farklı action türünü gösterir.

## 1) Composite: `composite-node-ci`
Kullanım: monorepo paketinde Node CI adımlarını tekrar kullanılabilir hale getirir. Workflow örneği: `.github/workflows/composite-node-ci.yml`.
```yaml
- uses: ./custom-actions/composite-node-ci
  with:
    node-version: "20"
    working-directory: "services/api"
```
Adımlar: `setup-node` + npm cache, `npm ci`, `npm run lint`, `npm test -- --coverage`. Çıktılar: `test-status`, `coverage-file`.

## 2) JavaScript: `javascript-pr-title-guard`
Kullanım: PR başlığını Conventional Commit formatında zorunlu kılar. Workflow örneği: `.github/workflows/pr-title-guard.yml`.
```yaml
- uses: ./custom-actions/javascript-pr-title-guard
  with:
    allowed-types: "feat,fix,chore,docs,refactor,perf,test,security"
    require-scope: "true"
    allow-draft: "false"
```
PR event payload'ından başlığı okur; hatalıysa job'u fail eder, geçerse `normalized-title` output'unu yazar.

## 3) Docker: `docker-terraform-validate`
Kullanım: Terraform modülü için izolasyonlu fmt + validate. Workflow örneği: `.github/workflows/terraform-validate.yml`.
```yaml
- uses: ./custom-actions/docker-terraform-validate
  with:
    path: "infra"
    var-file: "infra/dev.tfvars"
```
`hashicorp/terraform:1.6` imajı içinde `fmt -check`, backend kapalı `init`, ardından `validate` çalıştırır.
