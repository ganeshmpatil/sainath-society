# Enterprise Module / Feature Framework — Design

> Status: **design proposal** (no implementation yet).
> Scope: a structured base framework for the Aangan backend where every
> business operation is modelled as a **Feature** with a uniform
> **Validate → Save → Read** lifecycle, grouped under **Modules**.

---

## 1. Core model

```
Module           ── a bounded domain area (Vehicle Mgmt, Tenant Mgmt, Document Mgmt)
  └── Feature    ── one business operation/use-case (Register New Vehicle)
        ├── featureId        (stable unique key, e.g. VEH.REGISTER_VEHICLE)
        ├── description      (bilingual: EN + Marathi)
        └── Payload          ── the Business Object the feature acts on
              └── lifecycle  ── Validate → Save → Read (events on that BO)
```

Every feature in the system flows through the **identical lifecycle**, so dispatch,
transactions, auditing, authorization, and i18n are written **once** in the base
and inherited by all modules.

---

## 2. Framework object fields

### 2.1 `BusinessObject` (base of every Payload)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | identity |
| `ownerMemberId` | UUID | row-level ownership (feeds existing ACL) |
| `flatId` | UUID? | nullable; flat-scoped resources |
| `createdAt` | timestamp | audit stamp |
| `createdBy` | UUID | audit stamp |
| `updatedAt` | timestamp | audit stamp |
| `updatedBy` | UUID | audit stamp |
| `version` | int | optimistic locking |

### 2.2 `Feature` (command metadata + lifecycle contract)

| Field / Method | Type | Notes |
|---|---|---|
| `featureId` | FeatureId | `<MODULE>.<ACTION>`, stable, unique |
| `description` | string | English |
| `descriptionMr` | string | Marathi |
| `moduleId` | ModuleId | owning module |
| `archetype` | enum | CREATE / UPDATE / RETIRE / QUERY |
| `payload` | `P extends BusinessObject` | the business object |
| `Validate(ctx, P)` | → ValidationResult | lifecycle 1 |
| `Save(ctx, P)` | → P | lifecycle 2 |
| `Read(ctx, criteria)` | → P / []P | lifecycle 3 |

### 2.3 `Module`

| Field | Type | Notes |
|---|---|---|
| `moduleId` | ModuleId | e.g. `VEH` |
| `name` | string | English |
| `nameMr` | string | Marathi |
| `features` | []Feature | registered features |

### 2.4 `ExecutionContext`

| Field | Type | Notes |
|---|---|---|
| `actor` | ActorContext | UserID, MemberID, Role, FlatID (existing) |
| `locale` | enum | `en` / `mr` |
| `correlationId` | UUID | request tracing |
| `tx` | DB handle | transaction boundary |

### 2.5 `ValidationResult` / `FeatureException`

| Field | Type | Notes |
|---|---|---|
| `valid` | bool | |
| `errors` | []FieldError | |
| `FieldError.field` | string | |
| `FieldError.code` | string | machine code |
| `FieldError.messageEn` | string | |
| `FieldError.messageMr` | string | bilingual error |

---

## 3. Lifecycle orchestration (owned by the base)

```
Execute(featureId, payload):
    feature = registry.resolve(featureId)
    ctx     = buildExecutionContext(actor, locale, correlationId)
    begin transaction:
        authorize(ctx, payload)        # framework hook (row-level ACL)
        feature.Validate(ctx, payload)      ← LIFECYCLE 1
        result = feature.Save(ctx, payload) ← LIFECYCLE 2
        audit.record(ctx, featureId, result) # framework hook
    commit
    notify(ctx, events)                # framework hook (post-commit)
    return feature.Read(ctx, result)        ← LIFECYCLE 3
```

`Validate / Save / Read` are the explicit contract. `authorize`, `audit`, `notify`
are framework hooks wrapped around them — guaranteed, never duplicated per module.

---

## 4. Feature archetypes

| Archetype | Validate | Save | Read | Examples |
|---|---|---|---|---|
| **CreateFeature** | full field + business-rule check | INSERT new BO | return created BO | Register Vehicle, Register Tenant, Upload Document |
| **UpdateFeature** | exists + authz + rule check | UPDATE mutable fields | return updated BO | Update Tenant, Allocate Parking, Deallocate Parking |
| **RetireFeature** | exists + legal state transition | soft-delete / status transition | return final state | UnRegister Vehicle, UnRegister Tenant |
| **QueryFeature** | authz only | **audit-only** (no mutation) | fetch + return BO(s) | View Document, Download Document |

> A read still passes through `Save` — for QueryFeatures, `Save` writes an **audit row**,
> not a domain mutation. That is why "View Document" fits the same lifecycle as
> "Register Vehicle".

---

## 5. Business Object catalog + lifecycle

### 5.1 Module: Vehicle Management — `VEH`

**Business Objects:** `Vehicle` (primary), `ParkingSlot`, `ParkingAllocation` (value object).

**`Vehicle` fields**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `ownerMemberId` | UUID | owner |
| `flatId` | UUID? | |
| `type` | enum | CAR, TWO_WHEELER, OTHER |
| `registrationNumber` | string | unique |
| `make` / `model` / `color` | string | |
| `stickerNo` | string | generated on register |
| `status` | enum | ACTIVE, UNREGISTERED |
| `parkingSlotId` | UUID? | linked slot |

**`ParkingSlot` fields**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `slotNumber` | string | |
| `location` | string | |
| `status` | enum | FREE, ALLOCATED |
| `allocatedVehicleId` | UUID? | |
| `allocatedMemberId` | UUID? | |

**Features**

| Feature ID | Archetype | Payload | Validate | Save | Read |
|---|---|---|---|---|---|
| `VEH.REGISTER_VEHICLE` | Create | `Vehicle` | required fields; `registrationNumber` unique; type valid; owner forced to actor | INSERT (status=ACTIVE); generate `stickerNo` | created Vehicle |
| `VEH.UNREGISTER_VEHICLE` | Retire | `VehicleRef{id}` | exists; owned-by-actor-or-admin; not already unregistered | status→UNREGISTERED; free allocated slot | final Vehicle |
| `VEH.ALLOCATE_PARKING` | Update | `ParkingAllocation{slotId, vehicleId}` | slot FREE; vehicle ACTIVE; one-slot-per-vehicle; admin authz | slot→ALLOCATED; link vehicle↔slot | ParkingSlot (+vehicle) |
| `VEH.DEALLOCATE_PARKING` | Update | `ParkingAllocation{slotId}` | slot ALLOCATED; admin authz | slot→FREE; unlink | ParkingSlot |

### 5.2 Module: Tenant Management — `TEN`

**Business Objects:** `Tenant` (primary), `TenantMovement`.

**`Tenant` fields**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `flatId` | UUID | tenanted flat |
| `landlordMemberId` | UUID | owner/landlord |
| `name` / `nameMr` | string | bilingual |
| `mobile` | string | |
| `agreementStart` / `agreementEnd` | date | |
| `status` | enum | PENDING, APPROVED, MOVED_IN, MOVED_OUT |
| `policeVerificationStatus` | enum | PENDING, DONE |

**`TenantMovement` fields**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `tenantId` | UUID | |
| `type` | enum | MOVE_IN, MOVE_OUT |
| `date` | date | |
| `notes` | string | |

**Features**

| Feature ID | Archetype | Payload | Validate | Save | Read |
|---|---|---|---|---|---|
| `TEN.REGISTER_TENANT` | Create | `Tenant` | flat owned by landlord(actor); start<end; mobile format; required docs | INSERT (status=PENDING) | Tenant |
| `TEN.UPDATE_TENANT` | Update | `Tenant` (partial) | exists; authz; immutable fields (flatId, landlord) unchanged; date validity | UPDATE mutable fields | Tenant |
| `TEN.UNREGISTER_TENANT` | Retire | `TenantRef{id}` | exists; authz; status≠MOVED_OUT | status→MOVED_OUT; append `TenantMovement`(MOVE_OUT) | Tenant |
| `TEN.APPROVE_TENANT` *(suggested)* | Update | `TenantRef{id}` | admin authz; status=PENDING | status→APPROVED | Tenant |

### 5.3 Module: Document Management — `DOC`

**Business Objects:** `Document` (primary), `DocumentAccess` (grant), `DocumentAuditLog`.

**`Document` fields**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `ownerMemberId` | UUID | |
| `title` / `titleMr` | string | bilingual |
| `category` | enum | |
| `storageKey` | string | storage adapter reference |
| `mimeType` | string | |
| `size` | int | bytes |
| `visibility` | enum | PRIVATE, SHARED, PUBLIC |
| `status` | enum | ACTIVE, ARCHIVED |
| `version` | int | |

**`DocumentAccess` fields**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `documentId` | UUID | |
| `grantedToMemberId` | UUID | |
| `permission` | enum | VIEW, DOWNLOAD |

**`DocumentAuditLog` fields**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `documentId` | UUID | |
| `actorMemberId` | UUID | |
| `action` | enum | UPLOAD, VIEW, DOWNLOAD |
| `timestamp` | timestamp | |

**Features**

| Feature ID | Archetype | Payload | Validate | Save | Read |
|---|---|---|---|---|---|
| `DOC.UPLOAD_DOCUMENT` | Create | `Document` (+file) | file present; mime allowed; size ≤ limit; title required; owner=actor | StoragePort.put(file); INSERT (status=ACTIVE, v=1); AuditLog(UPLOAD) | Document metadata |
| `DOC.VIEW_DOCUMENT` | Query | `DocumentRef{id}` | exists; actor has VIEW (owner/admin/granted); not ARCHIVED | AuditLog(VIEW) only | metadata + view URL |
| `DOC.DOWNLOAD_DOCUMENT` | Query | `DocumentRef{id}` | exists; actor has DOWNLOAD permission | AuditLog(DOWNLOAD) only | signed URL / file stream |

---

## 6. Mapping onto existing aangan code

| Today (Go) | Becomes |
|---|---|
| `ActorContext` (repositories/base.go) | wrapped inside `ExecutionContext`; drives `authorize()` |
| `repositories/*` | the `Repository[P]` port — supplies Save/Read |
| Handler bind→validate→repo | binding thin; validate → `Feature.Validate`; persistence → `Feature.Save` |
| `ScopeOwnedOrAdmin` / `AssertOwnerOrAdmin` | invoked by framework `authorize()` — guaranteed per feature |
| ad-hoc `notifRepo.Enqueue` | `NotificationPort`, fired by post-commit `notify` hook |
| `DocumentAuditLog` (one-off) | generalized `AuditPort` for every feature |
| 110 routes | per-feature routes delegating to `FeatureExecutor`, or one `POST /api/v1/execute` |

---

## 7. Proposed package structure

```
server/internal/framework/          # base — zero domain knowledge
    business_object.go
    feature.go                       # Feature[P], FeatureId
    abstract_feature.go              # Execute() template + archetype bases
    module.go                        # Module, AbstractModule
    registry.go                      # FeatureRegistry
    executor.go                      # FeatureExecutor (dispatch + tx + hooks)
    context.go                       # ExecutionContext (wraps ActorContext)
    ports.go                         # Repository[P], StoragePort, NotificationPort, AuditPort
    validation.go                    # ValidationResult, FeatureException (bilingual)

server/internal/modules/
    vehicle/   module.go, vehicle.go, parking_slot.go, feature_*.go
    tenant/    module.go, tenant.go, tenant_movement.go, feature_*.go
    document/  module.go, document.go, document_access.go, feature_*.go
    # … 13 more modules, identical shape
```

---

## 8. Cross-cutting concerns the base owns

1. **Transactions** — one boundary per `Execute()`, around Validate + Save + audit.
2. **Authorization** — `authorize()` pre-hook using existing ACL; central choke point.
3. **Audit** — `AuditPort` emits `(actor, featureId, payload-ref, outcome, ts)` for every execution.
4. **Bilingual** — payloads carry `*Mr` fields; validation messages resolved by `ExecutionContext.locale`.
5. **Notifications** — post-commit only (never on a rolled-back txn).
6. **FeatureId versioning & idempotency** — stable IDs; optional idempotency key on Create.
7. **Error contract** — `FeatureException{code, messageEn, messageMr}` → uniform HTTP mapping.

---

## 9. Build order

1. `framework/` base (BusinessObject, Feature, AbstractFeature + 4 archetypes, Executor, ports).
2. **Vehicle Management** reference module end-to-end (4 features).
3. Wire `FeatureExecutor` behind existing routes (or single `/execute` endpoint).
4. Migrate Tenant + Document, then the remaining 13 modules mechanically.
