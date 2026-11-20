#!/bin/bash
set -euo pipefail

KEY_FILE="${1:-certs/tls.key}"

if ! openssl pkey -in "$KEY_FILE" -noout; then
  echo "Error: $KEY_FILE を秘密鍵として読み込めません" >&2
  exit 1
fi

base64 < "$KEY_FILE" | tr -d '\n'
echo >&2
