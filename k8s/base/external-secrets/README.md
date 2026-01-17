# External Secrets Configuration

This directory contains the External Secrets Operator configuration for securely managing secrets using GCP Secret Manager.

## Overview

Instead of storing secrets as plaintext in Kubernetes manifests, we use:
- **External Secrets Operator**: Syncs secrets from external providers
- **GCP Secret Manager**: Secure, centralized secret storage
- **Workload Identity**: Keyless authentication between GKE and GCP

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GKE Cluster                              │
│  ┌─────────────────┐     ┌─────────────────┐                    │
│  │  External       │────▶│  SecretStore    │                    │
│  │  Secrets        │     │  (GCP SM)       │                    │
│  │  Operator       │     └────────┬────────┘                    │
│  └─────────────────┘              │                             │
│           │                       │ Workload Identity           │
│           │                       ▼                             │
│  ┌────────▼────────┐     ┌─────────────────┐                    │
│  │  ExternalSecret │────▶│  K8s Secret     │                    │
│  │  (wcd-app-*)    │     │  (synced)       │                    │
│  └─────────────────┘     └────────┬────────┘                    │
│                                   │                             │
│                          ┌────────▼────────┐                    │
│                          │  Application    │                    │
│                          │  Pods           │                    │
│                          └─────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────┐
                    │    GCP Secret Manager       │
                    │  ┌─────────────────────┐   │
                    │  │ wcd-api-key          │   │
                    │  │ wcd-redis-password   │   │
                    │  │ wcd-db-username      │   │
                    │  │ wcd-db-password      │   │
                    │  │ wcd-jwt-secret       │   │
                    │  │ wcd-monitoring-htpwd │   │
                    │  └─────────────────────┘   │
                    └─────────────────────────────┘
```

## Prerequisites

### 1. Install External Secrets Operator

```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io

# Install operator
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

### 2. Create GCP Service Account

```bash
# Create service account for External Secrets
gcloud iam service-accounts create external-secrets \
  --display-name="External Secrets Operator"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding wcd-platform-sem6 \
  --member="serviceAccount:external-secrets@wcd-platform-sem6.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 3. Configure Workload Identity

```bash
# Allow KSA to impersonate GSA
gcloud iam service-accounts add-iam-policy-binding \
  external-secrets@wcd-platform-sem6.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:wcd-platform-sem6.svc.id.goog[wcd-platform/external-secrets-sa]"
```

### 4. Create Secrets in GCP Secret Manager

```bash
# Create each secret
echo -n "your-secure-api-key" | gcloud secrets create wcd-api-key --data-file=-
echo -n "your-redis-password" | gcloud secrets create wcd-redis-password --data-file=-
echo -n "wcd-admin" | gcloud secrets create wcd-db-username --data-file=-
echo -n "your-db-password" | gcloud secrets create wcd-db-password --data-file=-
echo -n "your-32-char-jwt-secret-here!!" | gcloud secrets create wcd-jwt-secret --data-file=-

# Generate htpasswd and create secret
htpasswd -nb admin yourpassword | gcloud secrets create wcd-monitoring-htpasswd --data-file=-
```

## Deployment

### Apply External Secrets Configuration

```bash
# Apply SecretStore and ExternalSecrets
kubectl apply -f k8s/base/external-secrets/

# Verify SecretStore is ready
kubectl get secretstore -n wcd-platform

# Verify ExternalSecrets are syncing
kubectl get externalsecret -n wcd-platform

# Check if Kubernetes secrets are created
kubectl get secrets -n wcd-platform -l managed-by=external-secrets
```

## Files

| File | Description |
|------|-------------|
| `secret-store.yaml` | SecretStore connecting to GCP Secret Manager via Workload Identity |
| `external-secret-app.yaml` | ExternalSecret definitions for app and monitoring secrets |
| `README.md` | This documentation |

## Secrets Managed

| K8s Secret | GCP Secret | Description |
|------------|------------|-------------|
| `WCD_API_KEY` | `wcd-api-key` | API key for frontend-backend communication |
| `REDIS_PASSWORD` | `wcd-redis-password` | Redis authentication password |
| `DB_USERNAME` | `wcd-db-username` | Database username |
| `DB_PASSWORD` | `wcd-db-password` | Database password |
| `JWT_SECRET` | `wcd-jwt-secret` | JWT signing secret (min 32 chars) |
| `auth` | `wcd-monitoring-htpasswd` | htpasswd for monitoring basic auth |

## Troubleshooting

### Check External Secrets Operator logs
```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Check ExternalSecret status
```bash
kubectl describe externalsecret wcd-app-secrets -n wcd-platform
```

### Verify Workload Identity
```bash
kubectl run -it --rm workload-identity-test \
  --image=google/cloud-sdk:slim \
  --serviceaccount=external-secrets-sa \
  --namespace=wcd-platform \
  -- gcloud auth list
```

### Common Issues

1. **SecretStore not ready**: Check Workload Identity binding
2. **ExternalSecret stuck syncing**: Verify GCP secrets exist
3. **Permission denied**: Check IAM roles on GSA

## Security Benefits

1. **No secrets in Git**: Secrets stored only in GCP Secret Manager
2. **Automatic rotation**: Change secret in GCP, it syncs to K8s
3. **Audit logging**: All secret access logged in GCP
4. **Least privilege**: Workload Identity limits access per namespace
5. **Centralized management**: One place to manage all secrets

## Migration from Static Secrets

1. Create secrets in GCP Secret Manager
2. Apply External Secrets configuration
3. Remove `secrets/app-secrets.yaml` from kustomization
4. Verify ExternalSecrets are syncing
5. Delete old static secrets (if any)

```bash
# After migration, remove old secrets
kubectl delete secret wcd-app-secrets -n wcd-platform --ignore-not-found
kubectl delete secret monitoring-basic-auth -n wcd-platform --ignore-not-found
```
