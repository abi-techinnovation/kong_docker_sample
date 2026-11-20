#!bin/bash

docker build --platform linux/amd64 -t konnect-ai-gateway .
docker login <registry-host>
docker tag konnect-ai-gateway <registry-host>/konnect-ai-gateway:latest
docker push <registry-host>/konnect-ai-gateway:latest
