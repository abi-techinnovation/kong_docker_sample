#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# 例: REGISTRY=<レジストリのホスト名> ./upload-sakura.sh
: "${REGISTRY:?環境変数 REGISTRY を設定してください}"
IMAGE="konnect-ai-gateway"

docker build --platform linux/amd64 -t "$IMAGE" .
docker login "$REGISTRY"
docker tag "$IMAGE" "$REGISTRY/$IMAGE:latest"
docker push "$REGISTRY/$IMAGE:latest"
