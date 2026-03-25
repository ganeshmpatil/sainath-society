# Sainath Society - Backend Implementation Plan (10 Days)

## Tech Stack
- **Runtime**: Node.js with Express.js
- **Database**: PostgreSQL with Prisma ORM
- **Auth**: JWT with bcrypt
- **Validation**: Zod
- **File Storage**: Local/S3

---

## Day 1: Project Setup & Database Design

### Tasks
- [ ] Initialize Node.js project with TypeScript
- [ ] Setup Express.js with middleware (cors, helmet, morgan)
- [ ] Configure Prisma ORM with PostgreSQL
- [ ] Design complete database schema:
  - Users, Residents, Flats, Wings
  - Grievances, Notices, Decisions
  - Vehicles, Polls, Meetings
  - Inventory, HallBookings, MoveInOut
  - Tasks, Suggestions, Bylaws
- [ ] Create Prisma migrations
- [ ] Seed database with mock data

### Deliverables
- `backend/` folder structure
- `prisma/schema.prisma` with all models
- Database running with seed data

---

## Day 2: Authentication & User Management

### Tasks
- [ ] User model with roles (Admin, Chairman, Secretary, Treasurer, Member)
- [ ] Register endpoint (POST /api/auth/register)
- [ ] Login endpoint (POST /api/auth/login)
- [ ] JWT token generation & refresh
- [ ] Password hashing with bcrypt
- [ ] Auth middleware for protected routes
- [ ] Get current user (GET /api/auth/me)
- [ ] Update password (PUT /api/auth/password)

### Deliverables
- Auth routes fully functional
- JWT middleware working
- Role-based access control setup

---

## Day 3: Residents & Flats Module

### Tasks
- [ ] Residents CRUD API
  - GET /api/residents (list with filters)
  - GET /api/residents/:id
  - POST /api/residents
  - PUT /api/residents/:id
  - DELETE /api/residents/:id
- [ ] Flats CRUD API
  - GET /api/flats
  - GET /api/flats/:id
  - POST /api/flats
  - PUT /api/flats/:id
- [ ] Link residents to flats (owner/tenant)
- [ ] Document upload for flat records
- [ ] Search & filter functionality

### Deliverables
- Residents API complete
- Flats API complete
- Frontend integration ready

---

## Day 4: Grievances & Notices Module

### Tasks
- [ ] Grievances CRUD API
  - POST /api/grievances (create complaint)
  - GET /api/grievances (list with status filter)
  - PUT /api/grievances/:id (update status)
  - POST /api/grievances/:id/comments
- [ ] Status workflow (Open → In Progress → Resolved)
- [ ] Priority levels (Low, Medium, High, Critical)
- [ ] Assignment to committee members
- [ ] Notices CRUD API
  - POST /api/notices
  - GET /api/notices
  - PUT /api/notices/:id
  - DELETE /api/notices/:id
- [ ] Notice categories (Maintenance, Meeting, Event, Finance)

### Deliverables
- Grievance tracking system
- Notice board API
- Comment system for grievances

---

## Day 5: Finance Module

### Tasks
- [ ] Maintenance bills generation
  - POST /api/finance/generate-bills
  - GET /api/finance/bills
  - GET /api/finance/bills/:flatId
- [ ] Payment recording
  - POST /api/finance/payments
  - GET /api/finance/payments
- [ ] Expense tracking
  - POST /api/finance/expenses
  - GET /api/finance/expenses
- [ ] Income categories
- [ ] Pending dues calculation
- [ ] Financial summary endpoint
  - GET /api/finance/summary
- [ ] Monthly/yearly reports

### Deliverables
- Complete finance tracking
- Bills & payments API
- Dashboard summary data

---

## Day 6: Vehicles & Parking Module

### Tasks
- [ ] Vehicle registration API
  - POST /api/vehicles
  - GET /api/vehicles
  - PUT /api/vehicles/:id
  - DELETE /api/vehicles/:id
- [ ] Parking slot allocation
- [ ] Sticker number generation
- [ ] Vehicle types (Car, Two Wheeler, etc.)
- [ ] Parking slot management
  - GET /api/parking/slots
  - PUT /api/parking/slots/:id/assign

### Deliverables
- Vehicle registry API
- Parking management system

---

## Day 7: Polls & Meetings Module

### Tasks
- [ ] Polls CRUD API
  - POST /api/polls
  - GET /api/polls
  - PUT /api/polls/:id
- [ ] Voting system
  - POST /api/polls/:id/vote
  - GET /api/polls/:id/results
- [ ] One vote per flat enforcement
- [ ] Meetings API
  - POST /api/meetings
  - GET /api/meetings
  - PUT /api/meetings/:id
- [ ] Meeting attendance tracking
- [ ] Agenda management
- [ ] Decision logging with votes

### Deliverables
- Polling system with voting
- Meeting management API

---

## Day 8: Hall Booking & Move In/Out Module

### Tasks
- [ ] Hall booking API
  - POST /api/hall-bookings
  - GET /api/hall-bookings
  - PUT /api/hall-bookings/:id
- [ ] Availability check
- [ ] Booking approval workflow
- [ ] Deposit & payment tracking
- [ ] Move In/Out API
  - POST /api/move-in-out
  - GET /api/move-in-out
  - PUT /api/move-in-out/:id
- [ ] Police verification status
- [ ] Tenant agreement tracking

### Deliverables
- Hall booking system
- Move in/out tracking

---

## Day 9: Remaining Modules & Integration

### Tasks
- [ ] Inventory API
  - CRUD for society assets
  - Condition tracking
- [ ] Pending Tasks API
  - Task assignment
  - Status updates
  - Due date tracking
- [ ] Suggestions API
  - Upvote system
  - Status workflow
- [ ] Bylaws API
  - Section management
  - Version control
- [ ] Connect frontend to all APIs
- [ ] Update React components to use API calls

### Deliverables
- All remaining APIs complete
- Frontend-backend integration started

---

## Day 10: Testing, Polish & Deployment

### Tasks
- [ ] API error handling & validation
- [ ] Input sanitization
- [ ] API documentation (Swagger/OpenAPI)
- [ ] Unit tests for critical endpoints
- [ ] Integration tests
- [ ] Environment configuration (dev/prod)
- [ ] Docker setup
- [ ] Deployment scripts
- [ ] Final frontend integration
- [ ] Bug fixes & polish

### Deliverables
- Production-ready backend
- API documentation
- Deployment configuration

---

## API Summary

| Module | Endpoints |
|--------|-----------|
| Auth | 4 |
| Residents | 5 |
| Flats | 4 |
| Grievances | 5 |
| Notices | 4 |
| Finance | 8 |
| Vehicles | 4 |
| Parking | 2 |
| Polls | 5 |
| Meetings | 4 |
| Hall Booking | 4 |
| Move In/Out | 4 |
| Inventory | 4 |
| Tasks | 4 |
| Suggestions | 4 |
| Bylaws | 4 |
| **Total** | **~65 endpoints** |

---

## Folder Structure

```
backend/
├── src/
│   ├── controllers/
│   ├── routes/
│   ├── middleware/
│   ├── services/
│   ├── utils/
│   └── app.ts
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── tests/
├── .env
├── package.json
└── tsconfig.json
```

---

## Notes

- Each day assumes ~6-8 hours of development
- Days can be parallelized with 2+ developers
- Frontend integration happens progressively
- Testing should happen alongside development
