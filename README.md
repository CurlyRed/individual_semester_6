# World Cup Drinking (WCD) Platform

A high-performance, event-driven microservices platform for tracking real-time drinking game events during World Cup matches.

## 🏗️ Architecture

**Microservices + Asynchronous Messaging**

- **ingest-service**: HTTP API for event ingestion (heartbeats, drink events)
- **projector-service**: Kafka consumer that updates Redis projections
- **query-service**: Read-only API for leaderboards and presence data
- **common**: Shared DTOs and utilities

**Technologies**

- Backend: Java 21, Spring Boot 3.x, Gradle (Kotlin DSL)
- Messaging: Redpanda (Kafka-compatible)
- Data Store: Redis (ZSET, HLL, TTL)
- Frontend: React + Vite + TypeScript + TailwindCSS
- Observability: Micrometer → Prometheus → Grafana
- Load Testing: k6

## 📂 Project Structure

```
/backend/              # Java microservices (Gradle multi-module)
  /common/             # Shared DTOs
    /src/main/java/    # Source code
    /src/test/java/    # Unit tests
  /ingest-service/     # Event ingestion API
  /projector-service/  # Event processor
  /query-service/      # Read API
/frontend/             # React dashboard
/infra/                # Docker Compose, Prometheus, Grafana configs
/k6/                   # Load testing scripts
```

📖 **Detailed Guides:**
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - IntelliJ IDEA & VS Code setup instructions
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Complete directory tree and file explanations

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (for Windows 11)
- **Java 21** (optional, for local development)
- **Node.js 20+** (optional, for local frontend development)
- **k6** (optional, for load testing)

### Running with Docker (Recommended)

```powershell
cd infra
docker-compose up -d
```

This will build and start all services:
- **Infrastructure**: Redis (6379), Redpanda/Kafka (9092)
- **Backend Services**: Ingest (8081), Projector (8082), Query (8083)
- **Frontend**: React Dashboard (5173)
- **Observability**: Prometheus (9090), Grafana (3000)

First-time build takes ~2-3 minutes. Subsequent starts are instant.

### Running Locally (Development)

See **[quickstart_checklist.md](quickstart_checklist.md)** for detailed step-by-step local setup.

### 3. Access Services

| Service | URL |
|---------|-----|
| Frontend Dashboard | http://localhost:5173 |
| Grafana | http://localhost:3000 (admin/admin) |
| Prometheus | http://localhost:9090 |
| Ingest API | http://localhost:8081 |
| Query API | http://localhost:8083 |

## 📡 API Endpoints

### Ingest Service (Port 8081)

**POST** `/api/events/heartbeat`
```json
{
  "userId": "user-123",
  "region": "EU",
  "matchId": "match-1",
  "amount": 0
}
```

**POST** `/api/events/drink`
```json
{
  "userId": "user-123",
  "region": "EU",
  "matchId": "match-1",
  "amount": 2
}
```

**Headers Required:**
- `X-API-KEY: dev-secret-key`

### Query Service (Port 8083)

**GET** `/api/health`
- Returns service health status

**GET** `/api/presence/onlineCount`
- Returns count of online users (active in last 30s)

**GET** `/api/leaderboard?matchId=match-1&limit=10`
- Returns top players for a match

## 🧪 Load Testing

Run baseline test (1500 RPS):
```powershell
cd k6
k6 run baseline.js
```

Run spike test (2000 RPS):
```powershell
k6 run spike.js
```

## 📊 Observability

### Grafana Dashboard

1. Open http://localhost:3000
2. Login: `admin` / `admin`
3. Navigate to "WCD Platform Overview" dashboard

**Key Metrics:**
- Event ingestion rate (heartbeats, drinks)
- Projector processing rate
- p95 latency
- JVM memory usage
- Rejected events rate

### Prometheus Metrics

Direct access: http://localhost:9090

Custom metrics:
- `wcd_events_heartbeat_total`
- `wcd_events_drink_total`
- `wcd_events_rejected_total`
- `wcd_projector_heartbeat_total`
- `wcd_projector_drink_total`

## 🔄 CI/CD Pipeline

This project includes a GitHub Actions workflow that automatically:

1. **Runs Tests** on every push/PR
   - Backend: Gradle unit tests (Java 21)
   - Frontend: TypeScript build validation
   - Load Testing: k6 baseline tests (PRs only)

2. **Builds Docker Images** on push to `main`
   - All 4 services (ingest, projector, query, frontend)
   - Tagged with branch name, commit SHA, and `latest`
   - Pushed to GitHub Container Registry (ghcr.io)

3. **Ready for Deployment**
   - Images available at: `ghcr.io/curlyred/individual_semester_6/*`
   - Pull and deploy with `docker-compose`

**Workflow File:** `.github/workflows/ci-cd.yml`

### Docker Images

Pull the latest images:
```bash
docker pull ghcr.io/curlyred/individual_semester_6/ingest-service:latest
docker pull ghcr.io/curlyred/individual_semester_6/projector-service:latest
docker pull ghcr.io/curlyred/individual_semester_6/query-service:latest
docker pull ghcr.io/curlyred/individual_semester_6/frontend:latest
```

## 🔧 Development

### Running Services Locally (without Docker)

**Start Redpanda & Redis:**
```powershell
cd infra
docker-compose up redpanda redis
```

**Start Backend Services:**
```powershell
cd backend
./gradlew :ingest-service:bootRun
./gradlew :projector-service:bootRun
./gradlew :query-service:bootRun
```

**Start Frontend:**
```powershell
cd frontend
npm install
npm run dev
```

## 🎯 Acceptance Criteria

✅ Services boot and connect via Docker Compose
✅ Ingest publishes → Projector consumes → Redis updates → Query reads
✅ Frontend dashboard shows live metrics and updates
✅ Grafana dashboards render Micrometer data
✅ k6 load tests stable under 1500 RPS with low latency

## 🧩 Engineering Principles

- **KISS**: Keep It Simple, Stupid
- **YAGNI**: You Aren't Gonna Need It
- **SOLID**: Selective application (SRP, DIP)
- **DRY**: Only extract clear duplication
- **12-Factor**: Env-based config, stateless services
- **Security by Design**: API key validation, rate limiting

## 📝 Configuration

All services use environment variables (see `.env` file):
- `WCD_API_KEY`: API key for authentication
- `KAFKA_BOOTSTRAP_SERVERS`: Kafka connection string
- `REDIS_HOST`, `REDIS_PORT`: Redis connection

## 🛠️ Troubleshooting

**Services won't start:**
```powershell
docker-compose down -v
docker-compose up --build
```

**Redis connection issues:**
```powershell
docker exec -it wcd-redis redis-cli PING
```

**Kafka issues:**
```powershell
docker exec -it wcd-redpanda rpk cluster health
```

**Check service logs:**
```powershell
docker-compose logs -f ingest-service
docker-compose logs -f projector-service
docker-compose logs -f query-service
```

## 📚 Further Reading

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Redpanda Documentation](https://docs.redpanda.com/)
- [Redis Documentation](https://redis.io/documentation)
- [k6 Documentation](https://k6.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## 📄 License

MIT License - See LICENSE file for details

---

**Sprint 1, Version 1.5 Extended**
🧠 Built following KISS, YAGNI, and SOLID principles
🚀 Production-ready walking skeleton
