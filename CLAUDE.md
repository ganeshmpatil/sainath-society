# Sainath Society / सोसायटी मित्र

Society management app for New Sainath Apartment, Bhandup (W), Mumbai — 87 residents, 7 wings.

## Stack
- **Server:** Go + Gin + GORM → `server/` (deployed on Render, auto-deploys on push to main)
- **Mobile:** Flutter + BLoC + GoRouter + Dio → `mobile/` (APK via GitHub Releases)
- **DB:** Neon PostgreSQL, tables prefixed `soc_mitra_*`, auth tables unprefixed

## Key Rules
- **Bilingual:** Every UI string needs EN + Marathi (strings_en.dart / strings_mr.dart). Data models use `*Mr` suffix fields.
- **Git scope:** Only commit inside this repo. Never operate at parent `poc/` level.
- **No self-registration:** Only admin-created accounts can log in.
- **Theme:** `AppColors` has mutable static fields — never use `const` before constructors referencing them.
- **Auth:** JWT with access/refresh tokens. Two roles: ADMIN, MEMBER. Row-level ACL via ActorContext.

## Common Workflows
```bash
# Build APK
cd mobile && flutter build apk --release

# Publish APK (Release ID: 338755778)
# Delete old asset then upload via GitHub API with token from ~/.git-credentials

# Direct DB access
PGPASSWORD='npg_DN5WbV9UjkMZ' psql "postgresql://neondb_owner:npg_DN5WbV9UjkMZ@ep-soft-hill-ao2o82xl.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"
```

## Login
- Pattern: `firstname.lastname@sainath.com` / `Welcome1`
- Admin login: `ganesh.patil.31@gmail.com`
- 4 admins: Ganesh, Kattika, Kanade, Supugade
