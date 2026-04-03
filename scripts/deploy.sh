#!/bin/sh
set -eu

IMAGE="$1"

echo "Deploying image: $IMAGE"

kubectl apply -f k8s/namespace.yaml

sed "s|__IMAGE__|$IMAGE|g" k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/service.yaml

kubectl rollout restart deployment/static-web -n static-web || true
kubectl rollout status deployment/static-web -n static-web --timeout=180s

echo "Deployment completed successfully"
kubectl get pods -n static-web
kubectl get svc -n static-web
