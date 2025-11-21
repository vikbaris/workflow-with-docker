#!/usr/bin/env sh
set -euo pipefail                      # Hata ve unset değişkende çık, pipe hatasında fail et

WORKDIR=${1:-.}                        # Parametre 1: Terraform dizini (varsayılan .)
VAR_FILE=${2:-}                        # Parametre 2: Opsiyonel tfvars dosyası

if [ ! -d "$WORKDIR" ]; then           # Çalışma dizini yoksa hatayla çık
  echo "::error::Path not found: $WORKDIR"
  exit 1
fi

echo "Using working directory: $WORKDIR"  # Bilgi amaçlı log

terraform -chdir="$WORKDIR" fmt -check -recursive        # Kod formatını doğrula (değişiklik yapmadan)
# Backend disabled to avoid touching real state in CI.    # Init backend'i kapalı: uzak state'e dokunma
terraform -chdir="$WORKDIR" init -input=false -backend=false

if [ -n "$VAR_FILE" ]; then                               # tfvars verilmişse validate sırasında kullan
  terraform -chdir="$WORKDIR" validate -var-file="$VAR_FILE"
else                                                      # Aksi halde varsayılan validate
  terraform -chdir="$WORKDIR" validate
fi
