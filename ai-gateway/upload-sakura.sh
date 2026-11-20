#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# 例: REGISTRY=<レジストリのホスト名> ./upload-sakura.sh
# TAG を省略すると latest で push する。
# REGISTRY_USER と REGISTRY_PASSWORD があれば対話なしでログインする。
: "${REGISTRY:?環境変数 REGISTRY を設定してください}"
IMAGE="konnect-ai-gateway"
TAG="${TAG:-latest}"

docker build --platform linux/amd64 -t "$IMAGE" .

if [[ -n "${REGISTRY_USER:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
  printf '%s' "$REGISTRY_PASSWORD" | docker login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin
else
  docker login "$REGISTRY"
fi

docker tag "$IMAGE" "$REGISTRY/$IMAGE:$TAG"
docker push "$REGISTRY/$IMAGE:$TAG"
