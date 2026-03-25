# Sainath Society - Technology Specifications

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENTS                                         │
│                    (Web Browser / Mobile App)                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KONG API GATEWAY                                   │
│         (Rate Limiting, Auth, Load Balancing, Logging, SSL)                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
            │  Auth API   │ │  Core API   │ │ Finance API │
            │   (Go)      │ │   (Go)      │ │   (Go)      │
            └─────────────┘ └─────────────┘ └─────────────┘
                    │               │               │
                    └───────────────┼───────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TEMPORAL WORKFLOW ENGINE                             │
│              (Long-running processes, Scheduling, Retries)                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            POSTGRESQL DATABASE                               │
│                    (Primary Data Store + Temporal DB)                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Frontend - React

### Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| React | 18.x | UI Framework |
| TypeScript | 5.x | Type Safety |
| Vite | 5.x | Build Tool |
| React Router | 6.x | Client-side Routing |
| TanStack Query | 5.x | Server State Management |
| Zustand | 4.x | Client State Management |
| TailwindCSS | 3.x | Styling |
| Axios | 1.x | HTTP Client |
| React Hook Form | 7.x | Form Management |
| Zod | 3.x | Schema Validation |

### UI Libraries

| Library | Purpose |
|---------|---------|
| Lucide React | Icons |
| Recharts | Charts & Graphs |
| React Table | Data Tables |
| React DatePicker | Date Selection |
| React Toastify | Notifications |
| Headless UI | Accessible Components |

### Project Structure

```
frontend/
├── src/
│   ├── api/                    # API client & endpoints
│   │   ├── client.ts           # Axios instance with interceptors
│   │   ├── auth.api.ts
│   │   ├── residents.api.ts
│   │   └── ...
│   ├── components/
│   │   ├── ui/                 # Reusable UI components
│   │   ├── forms/              # Form components
│   │   └── layout/             # Layout components
│   ├── hooks/                  # Custom React hooks
│   ├── pages/                  # Page components
│   ├── store/                  # Zustand stores
│   ├── types/                  # TypeScript types
│   ├── utils/                  # Utility functions
│   ├── App.tsx
│   └── main.tsx
├── public/
├── package.json
├── tsconfig.json
├── vite.config.ts
└── tailwind.config.js
```

### Key Features
- JWT token management with auto-refresh
- Role-based UI rendering
- Optimistic updates with TanStack Query
- Offline support with service workers
- PWA capabilities

---

## 2. Backend - Golang

### Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| Go | 1.22+ | Programming Language |
| Gin | 1.9.x | HTTP Web Framework |
| GORM | 1.25.x | ORM |
| golang-jwt | 5.x | JWT Authentication |
| Viper | 1.18.x | Configuration |
| Zap | 1.27.x | Structured Logging |
| Validator | 10.x | Request Validation |
| Swagger | 1.16.x | API Documentation |

### Project Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go             # Application entry point
├── internal/
│   ├── config/                 # Configuration management
│   │   └── config.go
│   ├── models/                 # Database models
│   │   ├── user.go
│   │   ├── resident.go
│   │   ├── flat.go
│   │   └── ...
│   ├── handlers/               # HTTP handlers
│   │   ├── auth_handler.go
│   │   ├── resident_handler.go
│   │   └── ...
│   ├── services/               # Business logic
│   │   ├── auth_service.go
│   │   ├── resident_service.go
│   │   └── ...
│   ├── repository/             # Data access layer
│   │   ├── user_repo.go
│   │   ├── resident_repo.go
│   │   └── ...
│   ├── middleware/             # HTTP middleware
│   │   ├── auth.go
│   │   ├── cors.go
│   │   ├── logger.go
│   │   └── ratelimit.go
│   ├── dto/                    # Data transfer objects
│   │   ├── requests/
│   │   └── responses/
│   └── utils/                  # Utility functions
├── pkg/                        # Shared packages
│   ├── database/
│   ├── jwt/
│   └── validator/
├── migrations/                 # Database migrations
├── docs/                       # Swagger docs
├── go.mod
├── go.sum
├── Makefile
└── Dockerfile
```

### Microservices (Optional Split)

| Service | Responsibility |
|---------|----------------|
| auth-service | Authentication, Authorization, User Management |
| core-service | Residents, Flats, Vehicles, Inventory |
| finance-service | Bills, Payments, Expenses, Reports |
| communication-service | Notices, Grievances, Suggestions |
| booking-service | Hall Bookings, Meeting Rooms |
| workflow-service | Temporal Workers, Background Jobs |

### API Design Principles
- RESTful endpoints
- Consistent error responses
- Request/Response DTOs
- Pagination for list endpoints
- Filtering and sorting support

---

## 3. Temporal Workflow Engine

### Purpose
Handle long-running, reliable background processes with automatic retries and state management.

### Components

| Component | Purpose |
|-----------|---------|
| Temporal Server | Workflow orchestration engine |
| Temporal Workers | Execute workflow activities |
| Temporal CLI | Administration and debugging |
| Temporal Web UI | Monitoring dashboard |

### Workflow Use Cases

#### 1. Monthly Billing Workflow
```go
// Workflow: GenerateMonthlyBills
// Triggers: 1st of every month
// Steps:
//   1. Fetch all active flats
//   2. Calculate maintenance for each flat
//   3. Generate bill records
//   4. Send notifications (email/SMS)
//   5. Update dashboard
```

#### 2. Grievance Resolution Workflow
```go
// Workflow: GrievanceResolution
// Triggers: On new grievance creation
// Steps:
//   1. Assign to appropriate committee member
//   2. Send notification to assignee
//   3. Wait for response (with timeout)
//   4. Escalate if not resolved in 48 hours
//   5. Close and notify resident
```

#### 3. Meeting Reminder Workflow
```go
// Workflow: MeetingReminder
// Triggers: Meeting scheduled
// Steps:
//   1. Send reminder 7 days before
//   2. Send reminder 1 day before
//   3. Send reminder 2 hours before
//   4. Collect attendance post-meeting
```

#### 4. Move-In/Out Workflow
```go
// Workflow: TenantOnboarding
// Triggers: New move-in request
// Steps:
//   1. Create tenant record
//   2. Initiate police verification
//   3. Wait for verification (up to 7 days)
//   4. Generate access cards
//   5. Update parking allocation
//   6. Send welcome kit
```

#### 5. Dues Reminder Workflow
```go
// Workflow: DuesReminder
// Triggers: Payment due date passed
// Steps:
//   1. Send gentle reminder (Day 1)
//   2. Send second reminder (Day 7)
//   3. Send warning notice (Day 15)
//   4. Escalate to committee (Day 30)
//   5. Restrict amenities access (Day 45)
```

### Worker Structure

```
temporal/
├── workflows/
│   ├── billing_workflow.go
│   ├── grievance_workflow.go
│   ├── meeting_workflow.go
│   ├── move_inout_workflow.go
│   └── reminder_workflow.go
├── activities/
│   ├── notification_activity.go
│   ├── billing_activity.go
│   ├── verification_activity.go
│   └── report_activity.go
├── workers/
│   └── main.go
└── schedules/
    └── cron_schedules.go
```

### Configuration

```yaml
# temporal-config.yaml
temporal:
  host: localhost:7233
  namespace: sainath-society
  task_queue: society-tasks
  worker_count: 4

workflows:
  billing:
    schedule: "0 0 1 * *"  # 1st of every month
    timeout: 30m

  grievance:
    escalation_timeout: 48h
    max_retries: 3

  reminder:
    retry_interval: 1h
```

---

## 4. PostgreSQL Database

### Version & Extensions

| Component | Version |
|-----------|---------|
| PostgreSQL | 16.x |
| pgcrypto | Built-in (encryption) |
| pg_trgm | Built-in (text search) |
| uuid-ossp | Built-in (UUID generation) |

### Database Schema

```sql
-- Core Tables
├── users                 # Authentication & authorization
├── residents             # Resident information
├── flats                 # Flat/unit details
├── wings                 # Building wings
├── documents             # Uploaded documents

-- Communication Tables
├── grievances            # Complaints & issues
├── grievance_comments    # Grievance discussions
├── notices               # Announcements
├── suggestions           # Resident suggestions
├── suggestion_votes      # Upvotes for suggestions

-- Finance Tables
├── bills                 # Maintenance bills
├── payments              # Payment records
├── expenses              # Society expenses
├── income_categories     # Income tracking
├── financial_years       # Year-wise accounting

-- Operations Tables
├── vehicles              # Vehicle registry
├── parking_slots         # Parking management
├── hall_bookings         # Hall reservations
├── inventory             # Society assets
├── inventory_logs        # Asset movement logs

-- Governance Tables
├── meetings              # AGM/SGM records
├── meeting_attendance    # Who attended
├── decisions             # Meeting decisions
├── polls                 # Voting polls
├── poll_votes            # Individual votes
├── tasks                 # Pending tasks
├── bylaws                # Society rules

-- Move In/Out Tables
├── move_records          # Move in/out tracking
├── tenant_agreements     # Rental agreements

-- Temporal Tables (Separate DB)
├── temporal_*            # Temporal server tables
```

### Key Design Decisions

1. **UUID Primary Keys** - Better for distributed systems
2. **Soft Deletes** - `deleted_at` timestamp instead of hard delete
3. **Audit Columns** - `created_at`, `updated_at`, `created_by`, `updated_by`
4. **JSON Columns** - For flexible metadata storage
5. **Indexes** - On foreign keys, search fields, and frequently filtered columns

### Sample Schema

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'member',
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Flats table
CREATE TABLE flats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flat_number VARCHAR(20) UNIQUE NOT NULL,
    wing_id UUID REFERENCES wings(id),
    floor INTEGER NOT NULL,
    area_sqft DECIMAL(10,2),
    owner_id UUID REFERENCES users(id),
    share_cert_no VARCHAR(50),
    purchase_date DATE,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grievances table
CREATE TABLE grievances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flat_id UUID REFERENCES flats(id),
    raised_by UUID REFERENCES users(id),
    subject VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'open',
    priority VARCHAR(20) DEFAULT 'medium',
    assigned_to UUID REFERENCES users(id),
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for common queries
CREATE INDEX idx_grievances_status ON grievances(status);
CREATE INDEX idx_grievances_flat ON grievances(flat_id);
CREATE INDEX idx_grievances_assigned ON grievances(assigned_to);
```

### Connection Pooling
- Use **PgBouncer** for connection pooling in production
- Configure pool size based on expected concurrent connections

---

## 5. Kong API Gateway

### Purpose
Single entry point for all API requests with cross-cutting concerns.

### Features Used

| Feature | Purpose |
|---------|---------|
| Rate Limiting | Prevent API abuse |
| JWT Auth | Token validation |
| ACL | Access control lists |
| CORS | Cross-origin requests |
| Request Logging | Audit trail |
| Load Balancing | Distribute traffic |
| SSL Termination | HTTPS handling |
| Request Transform | Header manipulation |

### Kong Configuration

```yaml
# kong.yml (Declarative Config)
_format_version: "3.0"

services:
  # Auth Service
  - name: auth-service
    url: http://auth-api:8080
    routes:
      - name: auth-routes
        paths:
          - /api/v1/auth
        strip_path: false

  # Core Service
  - name: core-service
    url: http://core-api:8080
    routes:
      - name: core-routes
        paths:
          - /api/v1/residents
          - /api/v1/flats
          - /api/v1/vehicles
          - /api/v1/inventory
        strip_path: false

  # Finance Service
  - name: finance-service
    url: http://finance-api:8080
    routes:
      - name: finance-routes
        paths:
          - /api/v1/finance
          - /api/v1/bills
          - /api/v1/payments
        strip_path: false

  # Communication Service
  - name: communication-service
    url: http://comm-api:8080
    routes:
      - name: comm-routes
        paths:
          - /api/v1/notices
          - /api/v1/grievances
          - /api/v1/suggestions
        strip_path: false

plugins:
  # Global Rate Limiting
  - name: rate-limiting
    config:
      minute: 100
      policy: local

  # JWT Authentication
  - name: jwt
    config:
      uri_param_names:
        - token
      claims_to_verify:
        - exp

  # CORS
  - name: cors
    config:
      origins:
        - http://localhost:5173
        - https://sainath-society.com
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
      headers:
        - Authorization
        - Content-Type
      credentials: true

  # Request Logging
  - name: file-log
    config:
      path: /var/log/kong/requests.log

  # Request Size Limit
  - name: request-size-limiting
    config:
      allowed_payload_size: 10
      size_unit: megabytes
```

### Rate Limiting by Endpoint

| Endpoint | Rate Limit |
|----------|------------|
| /api/v1/auth/login | 10/minute |
| /api/v1/auth/register | 5/minute |
| /api/v1/* (authenticated) | 100/minute |
| /api/v1/finance/* | 50/minute |
| File uploads | 10/minute |

### Kong Admin API Endpoints

| Endpoint | Purpose |
|----------|---------|
| :8001/services | Manage services |
| :8001/routes | Manage routes |
| :8001/plugins | Manage plugins |
| :8001/consumers | Manage API consumers |
| :8001/status | Health check |

---

## 6. Infrastructure & Deployment

### Docker Compose (Development)

```yaml
# docker-compose.yml
version: '3.8'

services:
  # Frontend
  frontend:
    build: ./frontend
    ports:
      - "5173:5173"
    volumes:
      - ./frontend:/app
    environment:
      - VITE_API_URL=http://localhost:8000

  # Backend API
  api:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=sainath_society
      - DB_USER=postgres
      - DB_PASSWORD=postgres
      - TEMPORAL_HOST=temporal:7233
    depends_on:
      - postgres
      - temporal

  # Temporal Worker
  worker:
    build: ./backend
    command: ["./worker"]
    environment:
      - TEMPORAL_HOST=temporal:7233
      - DB_HOST=postgres
    depends_on:
      - temporal
      - postgres

  # PostgreSQL
  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=sainath_society
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # Temporal Server
  temporal:
    image: temporalio/auto-setup:latest
    ports:
      - "7233:7233"
    environment:
      - DB=postgresql
      - DB_PORT=5432
      - POSTGRES_USER=postgres
      - POSTGRES_PWD=postgres
      - POSTGRES_SEEDS=postgres
    depends_on:
      - postgres

  # Temporal Web UI
  temporal-ui:
    image: temporalio/ui:latest
    ports:
      - "8088:8080"
    environment:
      - TEMPORAL_ADDRESS=temporal:7233

  # Kong Gateway
  kong:
    image: kong:3.6
    ports:
      - "8000:8000"   # Proxy
      - "8001:8001"   # Admin API
      - "8443:8443"   # Proxy SSL
    environment:
      - KONG_DATABASE=off
      - KONG_DECLARATIVE_CONFIG=/kong/kong.yml
      - KONG_PROXY_ACCESS_LOG=/dev/stdout
      - KONG_ADMIN_ACCESS_LOG=/dev/stdout
      - KONG_PROXY_ERROR_LOG=/dev/stderr
      - KONG_ADMIN_ERROR_LOG=/dev/stderr
    volumes:
      - ./kong/kong.yml:/kong/kong.yml

volumes:
  postgres_data:
```

### Production Architecture

```
                         ┌──────────────────┐
                         │   CloudFlare     │
                         │   (CDN + WAF)    │
                         └────────┬─────────┘
                                  │
                         ┌────────▼─────────┐
                         │  Load Balancer   │
                         │   (nginx/ALB)    │
                         └────────┬─────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
     ┌────────▼───────┐  ┌───────▼────────┐  ┌───────▼────────┐
     │  Kong Node 1   │  │  Kong Node 2   │  │  Kong Node 3   │
     └────────┬───────┘  └───────┬────────┘  └───────┬────────┘
              │                   │                   │
              └───────────────────┼───────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
           ┌────────▼──┐   ┌──────▼───┐   ┌─────▼─────┐
           │ API Pod 1 │   │ API Pod 2│   │ API Pod 3 │
           └───────────┘   └──────────┘   └───────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
           ┌────────▼──────┐ ┌────▼─────┐ ┌─────▼──────┐
           │ Temporal      │ │ Postgres │ │ Redis      │
           │ (3 replicas)  │ │ (Primary │ │ (Cache)    │
           │               │ │ + Replica)│ │            │
           └───────────────┘ └──────────┘ └────────────┘
```

---

## 7. Security Specifications

### Authentication Flow

```
1. User submits credentials
2. Backend validates and generates JWT (access + refresh)
3. Access token: 15 min expiry, stored in memory
4. Refresh token: 7 days expiry, stored in httpOnly cookie
5. Kong validates JWT on every request
6. Token refresh happens automatically before expiry
```

### Security Measures

| Layer | Measure |
|-------|---------|
| Transport | TLS 1.3, HSTS |
| Gateway | Rate limiting, WAF rules |
| Auth | JWT with RS256, refresh rotation |
| API | Input validation, parameterized queries |
| Database | Encrypted at rest, connection SSL |
| Secrets | HashiCorp Vault / K8s secrets |

### Role-Based Access Control

| Role | Permissions |
|------|-------------|
| Admin | Full access to all modules |
| Chairman | All except user management |
| Secretary | Residents, Notices, Grievances, Meetings |
| Treasurer | Finance, Bills, Payments |
| Member | View-only + own flat data + voting |

---

## 8. Monitoring & Observability

### Tools

| Tool | Purpose |
|------|---------|
| Prometheus | Metrics collection |
| Grafana | Dashboards |
| Jaeger | Distributed tracing |
| ELK Stack | Log aggregation |
| Sentry | Error tracking |

### Key Metrics

- API response times (p50, p95, p99)
- Request rate per endpoint
- Error rate by service
- Database query performance
- Temporal workflow execution times
- Kong rate limit hits

---

## 9. Development Workflow

### Git Branching Strategy

```
main (production)
  └── develop (staging)
        ├── feature/xyz
        ├── bugfix/xyz
        └── hotfix/xyz
```

### CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
stages:
  - lint          # golangci-lint, eslint
  - test          # go test, vitest
  - build         # docker build
  - security      # trivy scan
  - deploy-dev    # auto on develop
  - deploy-prod   # manual approval
```

---

## 10. Environment Variables

### Backend (.env)

```env
# Server
PORT=8080
ENV=development

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=sainath_society
DB_USER=postgres
DB_PASSWORD=secret
DB_SSL_MODE=disable

# JWT
JWT_SECRET=your-secret-key
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=168h

# Temporal
TEMPORAL_HOST=localhost:7233
TEMPORAL_NAMESPACE=sainath-society
TEMPORAL_TASK_QUEUE=society-tasks

# Kong
KONG_ADMIN_URL=http://localhost:8001
```

### Frontend (.env)

```env
VITE_API_URL=http://localhost:8000/api/v1
VITE_WS_URL=ws://localhost:8000
VITE_APP_NAME=Sainath Society
```

---

## Summary

| Component | Technology | Purpose |
|-----------|------------|---------|
| Frontend | React + TypeScript + TailwindCSS | User Interface |
| Backend | Go + Gin + GORM | REST API |
| Workflows | Temporal | Background Jobs |
| Database | PostgreSQL 16 | Data Storage |
| Gateway | Kong | API Management |
| Cache | Redis | Session/Cache |
| Monitoring | Prometheus + Grafana | Observability |
