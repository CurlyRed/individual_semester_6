# World Cup Drinking (WCD) Platform

A high-performance, event-driven microservices platform for tracking real-time drinking game events during World Cup matches. **Production-deployed to Google Kubernetes Engine (GKE)** with comprehensive security scanning.

[![CI/CD](https://github.com/CurlyRed/individual_semester_6/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/CurlyRed/individual_semester_6/actions/workflows/ci-cd.yml)
[![Security Scanning](https://github.com/CurlyRed/individual_semester_6/actions/workflows/security-scanning.yml/badge.svg)](https://github.com/CurlyRed/individual_semester_6/actions/workflows/security-scanning.yml)

## Architecture

**Event-Driven Microservices + CQRS Pattern**

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Frontend  │────▶│   Ingest    │────▶│   Kafka     │────▶│  Projector  │
│   (React)   │     │   Service   │     │ (Redpanda)  │     │   Service   │
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
       │                                                           │
       │            ┌─────────────┐     ┌─────────────┐            │
       └───────────▶│    Query    │◀────│    Redis    │◀───────────┘
                    │   Service   │     │  (Cache)    │
                    └─────────────┘     └─────────────┘
```

### Backend Services (3 microservices)
- **ingest-service** (8081): HTTP API for event ingestion (drinks, heartbeats) with rate limiting
- **projector-service** (8082): Kafka consumer that processes events and updates Redis
- **query-service** (8083): Read-only API for leaderboards and online presence

### Technology Stack

| Layer | Technology |
|-------|------------|
| **Backend** | Java 21, Spring Boot 3.2.x, Gradle (Kotlin DSL) |
| **Frontend** | React 18, TypeScript, Vite, TailwindCSS |
| **Messaging** | Redpanda (Kafka-compatible) |
| **Database** | Redis (caching + read projections) |
| **Observability** | Prometheus, Grafana |
| **Container** | Docker, nginx (frontend proxy) |
| **Orchestration** | Kubernetes (GKE) |
| **CI/CD** | GitHub Actions |
| **Security** | 6 scanning tools (see below) |

## Cloud Deployment (GKE)

### Live Environment

The platform is deployed to **Google Kubernetes Engine** with staging and production namespaces.

| Environment | Frontend URL | Status |
|-------------|--------------|--------|
| **Staging** | `http://<EXTERNAL-IP>:5173` | Auto-deploy on push to `main` |
| **Production** | `http://<EXTERNAL-IP>:5173` | Manual approval required |

To get the external IP:
```bash
kubectl get svc wcd-frontend -n wcd-staging
```

### GCP Console Links

| Resource | URL |
|----------|-----|
| **GKE Clusters** | https://console.cloud.google.com/kubernetes/list?project=wcd-platform-sem6 |
| **Workloads** | https://console.cloud.google.com/kubernetes/workload?project=wcd-platform-sem6 |
| **Services** | https://console.cloud.google.com/kubernetes/discovery?project=wcd-platform-sem6 |
| **Logs** | https://console.cloud.google.com/logs?project=wcd-platform-sem6 |
| **Billing** | https://console.cloud.google.com/billing?project=wcd-platform-sem6 |

### Start/Stop Cluster (Cost Management)

The GKE cluster costs approximately **$35-45/month** when running. To save costs:

#### Stop the Cluster (Pause Billing)
```bash
# Scale down all node pools to 0
gcloud container clusters resize wcd-platform-cluster --zone us-central1-a --num-nodes 0 --quiet
```

#### Start the Cluster (Resume)
```bash
# Scale back up to 2 nodes
gcloud container clusters resize wcd-platform-cluster --zone us-central1-a --num-nodes 2 --quiet

# Wait for nodes to be ready
kubectl get nodes -w

# Restart deployments
kubectl rollout restart deployment -n wcd-staging
```

#### Delete Cluster Entirely (Stop All Billing)
```bash
gcloud container clusters delete wcd-platform-cluster --zone us-central1-a --quiet
```

#### Recreate Cluster
```bash
gcloud container clusters create wcd-platform-cluster \
  --zone us-central1-a \
  --num-nodes 2 \
  --machine-type e2-small \
  --enable-autoscaling --min-nodes 1 --max-nodes 3
```

### Monitor Deployment Status

```bash
# Check all pods
kubectl get pods -n wcd-staging

# Check services and external IPs
kubectl get svc -n wcd-staging

# View logs for a service
kubectl logs -f deployment/wcd-ingest-service -n wcd-staging

# Check deployment rollout status
kubectl rollout status deployment/wcd-frontend -n wcd-staging
```

## CI/CD Pipeline

### Automated Workflow

On every push to `main`:

1. **Test** - Backend unit tests, frontend build validation
2. **Build** - Docker images for all 4 services
3. **Security Scan** - 6 security tools analyze code and containers
4. **Deploy Staging** - Automatic deployment to GKE staging namespace
5. **Deploy Production** - Manual approval required

### Security Scanning Tools

| Tool | Type | Purpose |
|------|------|---------|
| **SonarCloud** | SAST | Code quality, bugs, code smells |
| **CodeQL** | SAST | Security vulnerabilities in code |
| **OWASP Dependency-Check** | SCA | Vulnerable dependencies (CVEs) |
| **Trivy** | Container | Container image vulnerabilities |
| **Checkov** | IaC | Kubernetes manifest security |
| **GitLeaks** | Secrets | Hardcoded secrets detection |

Results are uploaded to **GitHub Security tab** in SARIF format.

### Docker Images

Images are published to GitHub Container Registry:

```bash
docker pull ghcr.io/curlyred/individual_semester_6/ingest-service:latest
docker pull ghcr.io/curlyred/individual_semester_6/projector-service:latest
docker pull ghcr.io/curlyred/individual_semester_6/query-service:latest
docker pull ghcr.io/curlyred/individual_semester_6/frontend:latest
```

## Local Development

### Prerequisites

- **Docker Desktop** (Windows/Mac)
- **Java 21** (optional, for IDE development)
- **Node.js 20+** (optional, for frontend development)
- **k6** (optional, for load testing)

### Quick Start with Docker

```powershell
cd infra
docker-compose up -d
```

This starts all services:
- **Infrastructure**: Redis (6379), Redpanda/Kafka (9092)
- **Backend**: Ingest (8081), Projector (8082), Query (8083)
- **Frontend**: React Dashboard (5173)
- **Observability**: Prometheus (9090), Grafana (3000)

### Access Services (Local)

| Service | URL |
|---------|-----|
| Frontend Dashboard | http://localhost:5173 |
| Grafana | http://localhost:3000 (admin/admin) |
| Prometheus | http://localhost:9090 |
| Ingest API | http://localhost:8081 |
| Query API | http://localhost:8083 |

### Running Without Docker

```powershell
# Start infrastructure only
cd infra
docker-compose up redpanda redis prometheus grafana -d

# Start backend services (separate terminals)
cd backend
./gradlew :ingest-service:bootRun
./gradlew :projector-service:bootRun
./gradlew :query-service:bootRun

# Start frontend
cd frontend
npm install
npm run dev
```

## API Reference

### Ingest Service (Port 8081)

**POST** `/api/events/heartbeat` - Record user presence
```json
{
  "userId": "user-123",
  "region": "EU",
  "matchId": "match-1",
  "amount": 0
}
```

**POST** `/api/events/drink` - Record drink event
```json
{
  "userId": "user-123",
  "region": "EU",
  "matchId": "match-1",
  "amount": 2
}
```

**Headers Required:** `X-API-KEY: dev-secret-key`

### Query Service (Port 8083)

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Service health status |
| `GET /api/presence/onlineCount` | Count of online users (active in last 30s) |
| `GET /api/leaderboard?matchId=match-1&limit=10` | Top players for a match |

## Load Testing

```powershell
cd k6

# Baseline test (1500 RPS)
k6 run baseline.js

# Spike test (2000 RPS)
k6 run spike.js
```

## Observability

### Grafana Dashboard

1. Open http://localhost:3000 (or GKE external IP)
2. Login: `admin` / `admin`
3. Navigate to "WCD Platform Overview"

**Key Metrics:**
- Event ingestion rate (heartbeats, drinks)
- Projector processing rate
- p95 latency
- Rejected events rate

### Prometheus Metrics

Custom metrics exposed:
- `wcd_events_heartbeat_total`
- `wcd_events_drink_total`
- `wcd_events_rejected_total`
- `wcd_projector_heartbeat_total`
- `wcd_projector_drink_total`

## Project Structure

```
/backend/                    # Java microservices (Gradle multi-module)
  /common/                   # Shared DTOs and utilities
  /ingest-service/           # Event ingestion API
  /projector-service/        # Kafka consumer, Redis writer
  /query-service/            # Read-only API
/frontend/                   # React dashboard + nginx proxy
/infra/                      # Docker Compose, Prometheus, Grafana
/k6/                         # Load testing scripts
/k8s/                        # Kubernetes manifests
  /base/                     # Base manifests (Kustomize)
  /overlays/staging/         # Staging environment config
  /overlays/production/      # Production environment config
/.github/workflows/          # CI/CD pipelines
  ci-cd.yml                  # Build, test, deploy pipeline
  security-scanning.yml      # Security scanning pipeline
```

## Configuration

Environment variables (see `infra/.env`):

| Variable | Description |
|----------|-------------|
| `WCD_API_KEY` | API key for ingest authentication |
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka connection string |
| `REDIS_HOST` | Redis hostname |
| `REDIS_PORT` | Redis port |

## Troubleshooting

### Docker Issues

```powershell
# Full reset
docker-compose down -v
docker-compose up --build

# Check Redis
docker exec -it wcd-redis redis-cli PING

# Check Kafka
docker exec -it wcd-redpanda rpk cluster health
```

### GKE Issues

```bash
# Pod not starting
kubectl describe pod <pod-name> -n wcd-staging

# View pod logs
kubectl logs <pod-name> -n wcd-staging

# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n wcd-staging

# Check events
kubectl get events -n wcd-staging --sort-by='.lastTimestamp'
```

### Auth Plugin Issues

If `kubectl` commands fail with auth errors:
```bash
gcloud components install gke-gcloud-auth-plugin
gcloud container clusters get-credentials wcd-platform-cluster --zone us-central1-a
```

## Engineering Principles

- **KISS** - Keep It Simple, Stupid
- **YAGNI** - You Aren't Gonna Need It
- **12-Factor** - Environment-based config, stateless services
- **Security by Design** - API key validation, rate limiting, 6 security scanners
- **Event Sourcing** - Kafka as source of truth, Redis as read projection

---

**Sprint 3** | Production-deployed to GKE | 6-layer security scanning
