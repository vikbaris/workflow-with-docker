#!/usr/bin/env sh
set -euo pipefail                      # Hata ve unset değişkende çık, pipe hatasında fail et

WORKDIR=${1:-.}                        # Parametre 1: Terraform dizini (varsayılan .)
VAR_FILE=${2:-}                        # Parametre 2: Opsiyonel tfvars dosyası
TMP_VAR_FILE=""

if [ ! -d "$WORKDIR" ]; then           # Çalışma dizini yoksa hatayla çık
  echo "::error::Path not found: $WORKDIR"
  exit 1
fi

echo "Using working directory: $WORKDIR"  # Bilgi amaçlı log

terraform -chdir="$WORKDIR" fmt -check -recursive        # Kod formatını doğrula (değişiklik yapmadan)
# Backend disabled to avoid touching real state in CI.    # Init backend'i kapalı: uzak state'e dokunma
terraform -chdir="$WORKDIR" init -input=false -backend=false

# terraform validate doğrudan -var-file desteklemez; bunun yerine dosyayı
# override.auto.tfvars adıyla kopyalıyoruz ki validate sırasında okunsun.
if [ -n "$VAR_FILE" ]; then
  if [ ! -f "$VAR_FILE" ]; then
    echo "::error::var-file not found: $VAR_FILE"
    exit 1
  fi
  TMP_VAR_FILE="$(mktemp "${RUNNER_TEMP:-/tmp}/tfvars-XXXX.auto.tfvars")"
  cp "$VAR_FILE" "$TMP_VAR_FILE"
  export TF_CLI_ARGS_validate="-var-file=$TMP_VAR_FILE"
fi

terraform -chdir="$WORKDIR" validate

if [ -n "$TMP_VAR_FILE" ] && [ -f "$TMP_VAR_FILE" ]; then
  rm -f "$TMP_VAR_FILE"                                   # Temizlik
fi
