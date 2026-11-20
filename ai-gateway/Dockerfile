FROM kong/kong-ai-gateway:2.3.0-distroless

# --- Konnect データプレーンの設定 ---
ENV KONG_ROLE=data_plane \
    KONG_DATABASE=off \
    KONG_VITALS=off \
    KONG_CLUSTER_MTLS=pki \
    KONG_CLUSTER_CONTROL_PLANE=38608da58f.us.cp.konghq.com:443 \
    KONG_CLUSTER_SERVER_NAME=38608da58f.us.cp.konghq.com \
    KONG_CLUSTER_TELEMETRY_ENDPOINT=38608da58f.us.tp.konghq.com:443 \
    KONG_CLUSTER_TELEMETRY_SERVER_NAME=38608da58f.us.tp.konghq.com \
    KONG_LUA_SSL_TRUSTED_CERTIFICATE=system \
    KONG_KONNECT_MODE=on

# --- 証明書 ---
# PEM は複数行のため ENV に直接書けない。ファイルとしてコピーし、パスを指定する
COPY certs/tls.crt /etc/kong/cluster/tls.crt
ENV KONG_CLUSTER_CERT=/etc/kong/cluster/tls.crt

EXPOSE 8000 8443
