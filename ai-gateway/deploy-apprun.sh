#!/bin/bash
# Konnect データプレーンのイメージをビルドして、さくらの AppRun 共用型へデプロイする。
#
#   1. イメージをビルドし、一意のタグでコンテナレジストリへ push する（upload-sakura.sh）
#   2. 同じ名前のアプリケーションがなければ作成し、あれば新しいバージョンに更新する
#   3. packet-filter.txt の内容でパケットフィルタを設定する
#   4. アプリケーションが Healthy になるまで待つ
#
# 設定は環境変数か ai-gateway/.env で渡す（apprun.env.example を参照）。
# DRY_RUN=1 のときは、ビルド・push・API 呼び出しをせず、送信内容（秘密情報は伏せ字）を表示する。
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

DRY_RUN="${DRY_RUN:-0}"

: "${REGISTRY:?環境変数 REGISTRY を設定してください}"
: "${REGISTRY_USER:?環境変数 REGISTRY_USER を設定してください}"
: "${REGISTRY_PASSWORD:?環境変数 REGISTRY_PASSWORD を設定してください}"
if [[ "$DRY_RUN" != 1 ]]; then
  : "${SAKURA_ACCESS_TOKEN:?環境変数 SAKURA_ACCESS_TOKEN を設定してください}"
  : "${SAKURA_ACCESS_TOKEN_SECRET:?環境変数 SAKURA_ACCESS_TOKEN_SECRET を設定してください}"
fi

APP_NAME="${APP_NAME:-konnect-ai-gateway}"
IMAGE="konnect-ai-gateway"
TAG="${TAG:-$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)}"
IMAGE_REF="$REGISTRY/$IMAGE:$TAG"
KEY_FILE="${KEY_FILE:-certs/tls.key}"
PACKET_FILTER_FILE="${PACKET_FILTER_FILE:-packet-filter.txt}"
APP_PORT=8000 # Kong のプロキシ（HTTP）
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"
MIN_SCALE="${MIN_SCALE:-1}" # 0 だと停止中に Konnect との接続が切れる
MAX_SCALE="${MAX_SCALE:-1}"
MAX_CPU="${MAX_CPU:-1}"
MAX_MEMORY="${MAX_MEMORY:-2Gi}"
WAIT_SECONDS="${WAIT_SECONDS:-600}"

API="https://secure.sakura.ad.jp/cloud/api/apprun/1.0/apprun/api"

if (( MIN_SCALE < 1 )); then
  echo "Error: MIN_SCALE は 1 以上にしてください（0 だと Konnect との接続が切れます）" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
chmod 700 "$WORK"

# --- パケットフィルタの読み込み ---
if [[ ! -f "$PACKET_FILTER_FILE" ]]; then
  echo "Error: $PACKET_FILTER_FILE がありません（packet-filter.example.txt を参考に作成してください）" >&2
  exit 1
fi

settings="[]"
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="$(tr -d '[:space:]' <<<"$line")"
  [[ -z "$line" ]] && continue
  if [[ ! "$line" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})/([0-9]{1,2})$ ]]; then
    echo "Error: $PACKET_FILTER_FILE の '$line' は IPv4 の CIDR 形式ではありません" >&2
    exit 1
  fi
  for i in 1 2 3 4; do
    if (( BASH_REMATCH[i] > 255 )); then
      echo "Error: $PACKET_FILTER_FILE の '$line' は IPv4 アドレスとして不正です" >&2
      exit 1
    fi
  done
  if (( BASH_REMATCH[5] > 32 )); then
    echo "Error: $PACKET_FILTER_FILE の '$line' の prefix 長が不正です" >&2
    exit 1
  fi
  settings="$(jq -c --arg ip "${line%/*}" --argjson len "${line#*/}" \
    '. + [{from_ip: $ip, from_ip_prefix_length: $len}]' <<<"$settings")"
done <"$PACKET_FILTER_FILE"

count="$(jq length <<<"$settings")"
if (( count == 0 || count > 10 )); then
  echo "Error: パケットフィルタは 1〜10 件にしてください（現在 $count 件）" >&2
  exit 1
fi
jq -n --argjson settings "$settings" '{is_enabled: true, settings: $settings}' >"$WORK/packet_filter.json"

# --- 秘密鍵（KONG_CLUSTER_CERT_KEY として渡す） ---
bash ./parse-tls.sh "$KEY_FILE" >"$WORK/key.b64" 2>/dev/null || {
  echo "Error: $KEY_FILE を秘密鍵として読み込めません" >&2
  exit 1
}

# --- リクエストボディの組み立て ---
# 秘密情報はコマンドライン引数に載せないよう、ファイルと環境変数から jq に渡す。
export REGISTRY REGISTRY_USER REGISTRY_PASSWORD
jq -n \
  --arg image "$IMAGE_REF" \
  --arg cpu "$MAX_CPU" \
  --arg memory "$MAX_MEMORY" \
  --rawfile key "$WORK/key.b64" \
  '[{
    name: "kong",
    max_cpu: $cpu,
    max_memory: $memory,
    deploy_source: {
      container_registry: {
        image: $image,
        server: $ENV.REGISTRY,
        username: $ENV.REGISTRY_USER,
        password: $ENV.REGISTRY_PASSWORD
      }
    },
    secret: [{key: "KONG_CLUSTER_CERT_KEY", value: $key}]
  }]' >"$WORK/components.json"

common_args=(
  --argjson timeout "$TIMEOUT_SECONDS"
  --argjson port "$APP_PORT"
  --argjson min "$MIN_SCALE"
  --argjson max "$MAX_SCALE"
  --slurpfile components "$WORK/components.json"
)
jq -n "${common_args[@]}" --arg name "$APP_NAME" \
  '{name: $name, timeout_seconds: $timeout, port: $port, min_scale: $min, max_scale: $max, components: $components[0]}' \
  >"$WORK/create.json"
jq -n "${common_args[@]}" \
  '{timeout_seconds: $timeout, port: $port, min_scale: $min, max_scale: $max, components: $components[0], all_traffic_available: true}' \
  >"$WORK/patch.json"

if [[ "$DRY_RUN" == 1 ]]; then
  mask='walk(if type == "object" then (if has("password") then .password = "****" else . end) | (if has("value") and .key == "KONG_CLUSTER_CERT_KEY" then .value = "****" else . end) else . end)'
  echo "--- DRY_RUN: イメージ $IMAGE_REF"
  echo "--- DRY_RUN: POST $API/applications"
  jq "$mask" "$WORK/create.json"
  echo "--- DRY_RUN: PATCH $API/applications/{id}"
  jq "$mask" "$WORK/patch.json"
  echo "--- DRY_RUN: PATCH $API/applications/{id}/packet_filter"
  jq . "$WORK/packet_filter.json"
  exit 0
fi

# --- API 呼び出し ---
# 認証情報はプロセス一覧に出ないよう netrc ファイルで渡す。
printf 'machine secure.sakura.ad.jp login %s password %s\n' \
  "$SAKURA_ACCESS_TOKEN" "$SAKURA_ACCESS_TOKEN_SECRET" >"$WORK/netrc"

api() {
  local method="$1" path="$2" body="${3:-}" code
  local args=(-sS -o "$WORK/response.json" -w '%{http_code}' -X "$method"
    --netrc-file "$WORK/netrc" -H 'Content-Type: application/json')
  [[ -n "$body" ]] && args+=(--data-binary "@$body")
  code="$(curl "${args[@]}" "$API$path")"
  if [[ "$code" != 2* ]]; then
    echo "Error: $method $path が失敗しました（HTTP $code）" >&2
    jq . "$WORK/response.json" >&2 2>/dev/null || cat "$WORK/response.json" >&2
    return 1
  fi
  cat "$WORK/response.json"
}

# 認証を先に確かめてから、時間のかかるビルドに進む
apps="$(api GET '/applications?page_size=100')"
ids="$(jq -c --arg name "$APP_NAME" '[.data[] | select(.name == $name) | .id]' <<<"$apps")"
if (( $(jq length <<<"$ids") > 1 )); then
  echo "Error: 名前が $APP_NAME のアプリケーションが複数あります" >&2
  exit 1
fi
app_id="$(jq -r '.[0] // empty' <<<"$ids")"

echo "==> イメージをビルドして push します: $IMAGE_REF"
TAG="$TAG" ./upload-sakura.sh

if [[ -z "$app_id" ]]; then
  echo "==> アプリケーション $APP_NAME を作成します"
  app_id="$(api POST /applications "$WORK/create.json" | jq -r '.id // empty')"
  if [[ -z "$app_id" ]]; then
    echo "Error: 作成したアプリケーションの ID を取得できませんでした" >&2
    exit 1
  fi
else
  echo "==> アプリケーション $APP_NAME（$app_id）を更新します"
  api PATCH "/applications/$app_id" "$WORK/patch.json" >/dev/null
fi

echo "==> パケットフィルタを設定します（$count 件）"
api PATCH "/applications/$app_id/packet_filter" "$WORK/packet_filter.json" >/dev/null
api GET "/applications/$app_id/packet_filter" |
  jq -r '"    有効: \(.is_enabled)", (.settings[] | "    許可: \(.from_ip)/\(.from_ip_prefix_length)")'

echo "==> アプリケーションが Healthy になるまで待ちます（最大 ${WAIT_SECONDS} 秒）"
deadline=$((SECONDS + WAIT_SECONDS))
while :; do
  status_json="$(api GET "/applications/$app_id/status")"
  status="$(jq -r .status <<<"$status_json")"
  case "$status" in
    Healthy) break ;;
    UnHealthy)
      echo "Error: アプリケーションが UnHealthy です: $(jq -r .message <<<"$status_json")" >&2
      exit 1
      ;;
  esac
  if (( SECONDS >= deadline )); then
    echo "Error: ${WAIT_SECONDS} 秒待っても Healthy になりませんでした（現在: $status）" >&2
    exit 1
  fi
  sleep 10
done

public_url="$(api GET "/applications/$app_id" | jq -r .public_url)"
echo "==> デプロイが完了しました"
echo "    アプリケーション ID: $app_id"
echo "    イメージ: $IMAGE_REF"
echo "    公開 URL: $public_url"
