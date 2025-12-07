# WCD Platform Kubernetes Deployment

This directory contains all Kubernetes manifests and configurations for deploying the WCD Platform to a Kubernetes cluster.

## 📁 Directory Structure

```
k8s/
├── base/                    # Base Kubernetes resources
│   ├── namespace/          # Namespace and network policies
│   ├── configmaps/         # Application configuration
│   ├── secrets/            # Sensitive data (API keys, passwords)
│   ├── deployments/        # Microservice deployments
│   ├── statefulsets/       # Database StatefulSets
│   ├── ingress/            # Ingress rules for external access
│   ├── monitoring/         # Jaeger, Prometheus, Grafana
│   └── kustomization.yaml  # Kustomize configuration
├── deploy.sh               # Deployment script
└── README.md               # This file
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.25+)
- kubectl installed and configured
- Helm 3 (optional, for Helm deployments)
- Minimum cluster requirements:
  - 3 nodes (2 vCPU, 8GB RAM each)
  - 100GB storage total
  - LoadBalancer or Ingress controller support

### Local Testing with Minikube

```bash
# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=40g

# Enable necessary addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Deploy the platform
./deploy.sh local apply

# Check status
./deploy.sh local status

# Port forward for local access
./deploy.sh local port-forward
```

### Deploy to Kubernetes

```bash
# Make deployment script executable
chmod +x deploy.sh

# Deploy all resources
./deploy.sh [environment] apply

# Check deployment status
./deploy.sh [environment] status

# Run smoke tests
./deploy.sh [environment] test

# Delete all resources
./deploy.sh [environment] delete
```

## 🔧 Using Kustomize

```bash
# Preview what will be deployed
kubectl kustomize base/

# Deploy using kustomize
kubectl apply -k base/

# Deploy to different environment
kubectl apply -k overlays/production/
```

## 🌐 Accessing Services

### After deployment, services are available at:

| Service | Internal URL | External URL (with Ingress) |
|---------|--------------|------------------------------|
| Ingest API | http://wcd-ingest-service:8081 | https://api.wcd-platform.com/api/events |
| Query API | http://wcd-query-service:8083 | https://api.wcd-platform.com/api/query |
| Grafana | http://wcd-grafana:3000 | https://grafana.wcd-platform.com |
| Jaeger UI | http://wcd-jaeger-query:16686 | https://jaeger.wcd-platform.com |

### Local Port Forwarding

For local development without Ingress:

```bash
# Forward all services
./deploy.sh local port-forward

# Or manually forward specific services
kubectl port-forward -n wcd-platform svc/wcd-ingest-service 8081:8081
kubectl port-forward -n wcd-platform svc/wcd-query-service 8083:8083
kubectl port-forward -n wcd-platform svc/wcd-grafana 3000:3000
kubectl port-forward -n wcd-platform svc/wcd-jaeger-query 16686:16686
```

## 🔒 Security Considerations

### Secrets Management

**WARNING**: The secrets in `base/secrets/` are templates with placeholder values.

For production:
1. Use External Secrets Operator
2. Or Sealed Secrets
3. Or cloud provider's secret management (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault)

```bash
# Example: Create real secrets
kubectl create secret generic wcd-app-secrets \
  --from-literal=WCD_API_KEY='your-real-api-key' \
  --from-literal=JWT_SECRET='your-real-jwt-secret' \
  -n wcd-platform
```

### Network Policies

Network policies are configured to:
- Deny all ingress by default
- Allow traffic only within namespace
- Allow ingress controller access to exposed services

## 📊 Monitoring

### Prometheus Metrics

All services expose Prometheus metrics at `/actuator/prometheus`

```bash
# Check metrics
kubectl port-forward -n wcd-platform svc/wcd-prometheus 9090:9090
# Visit http://localhost:9090
```

### Grafana Dashboards

Default credentials: `admin/admin`

```bash
kubectl port-forward -n wcd-platform svc/wcd-grafana 3000:3000
# Visit http://localhost:3000
```

### Jaeger Tracing

```bash
kubectl port-forward -n wcd-platform svc/wcd-jaeger-query 16686:16686
# Visit http://localhost:16686
```

## 🔄 Scaling

### Manual Scaling

```bash
# Scale a deployment
kubectl scale deployment wcd-ingest-service -n wcd-platform --replicas=5

# Check HPA status
kubectl get hpa -n wcd-platform
```

### Auto-scaling Configuration

HPAs are configured for:
- **Ingest Service**: 3-10 replicas (CPU 70%, Memory 80%)
- **Query Service**: 3-15 replicas (CPU 70%, Memory 80%)
- **Projector Service**: 2-6 replicas (CPU 70%, Memory 80%)

## 🐛 Troubleshooting

### Check Pod Status

```bash
# Get all pods
kubectl get pods -n wcd-platform

# Describe a problematic pod
kubectl describe pod <pod-name> -n wcd-platform

# Check pod logs
kubectl logs <pod-name> -n wcd-platform

# Follow logs
kubectl logs -f <pod-name> -n wcd-platform
```

### Common Issues

1. **Pods stuck in Pending**
   - Check node resources: `kubectl top nodes`
   - Check PVC status: `kubectl get pvc -n wcd-platform`

2. **Pods CrashLoopBackOff**
   - Check logs: `kubectl logs <pod-name> -n wcd-platform --previous`
   - Check resource limits

3. **Services not accessible**
   - Check service endpoints: `kubectl get endpoints -n wcd-platform`
   - Check ingress status: `kubectl get ingress -n wcd-platform`

### Debug Commands

```bash
# Get events
kubectl get events -n wcd-platform --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n wcd-platform
kubectl top nodes

# Check service connectivity
kubectl run debug --image=busybox -it --rm --restart=Never -n wcd-platform -- /bin/sh
# Inside the pod:
wget -O- http://wcd-ingest-service:8081/actuator/health
```

## 📝 Configuration

### Environment-specific Configurations

Create overlays for different environments:

```bash
k8s/
├── base/           # Base configuration
└── overlays/
    ├── dev/        # Development overrides
    ├── staging/    # Staging overrides
    └── production/ # Production overrides
```

### Resource Limits

Current default limits per service:
- **Request**: 512Mi memory, 250m CPU
- **Limit**: 1Gi memory, 1000m CPU

Adjust in deployment files based on load testing results.

## 🚢 Production Deployment

### Checklist

- [ ] Update all secrets with real values
- [ ] Configure proper storage classes
- [ ] Set up cert-manager for TLS certificates
- [ ] Configure DNS records
- [ ] Set up monitoring alerts
- [ ] Configure backup strategy
- [ ] Test disaster recovery
- [ ] Load test the deployment
- [ ] Security scan all images

### Cloud-specific Configurations

#### AWS EKS

```bash
# Create cluster
eksctl create cluster --name wcd-platform --region eu-west-1

# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds"
```

#### GCP GKE

```bash
# Create cluster
gcloud container clusters create wcd-platform \
  --zone europe-west4-a \
  --num-nodes 3
```

#### Azure AKS

```bash
# Create cluster
az aks create \
  --resource-group wcd-platform \
  --name wcd-platform \
  --node-count 3
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)