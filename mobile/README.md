# Sainath Society — Mobile (Flutter)

Flutter app skeleton for **Android + iOS**, built in parallel to the web UI
(`../ui`) and sharing the same Go backend (`../server`).

> **Status: skeleton only.** Navigation, theming, bilingual scaffolding, and
> auth/route-guard wiring are in place. There is **no business logic** yet — every
> module screen is a placeholder and the API client throws `UnimplementedError`.

## Run

```bash
cd mobile
flutter pub get
flutter run                 # pick an Android emulator or iOS simulator
# point at a non-localhost backend (10.0.2.2 = host from Android emulator):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Quality gates:

```bash
flutter analyze     # → No issues found!
flutter test        # → smoke test: boots to login
```

## Structure

```
lib/
  main.dart                      app entry; registers Provider controllers
  app/
    app.dart                     root MaterialApp.router (theme + locale + i18n)
    router.dart                  go_router table + auth redirect guard
    theme.dart                   Material 3 dark "glass/cyan" theme
  core/
    api/
      api_config.dart            base URL (override via --dart-define)
      api_client.dart            HTTP client STUB (no real calls yet)
    auth/
      auth_controller.dart       session state STUB (in-memory flag)
    i18n/
      app_localizations.dart     key-based EN/MR lookup + delegate
      locale_controller.dart     active locale + toggle
      strings_en.dart            English strings
      strings_mr.dart            Marathi (मराठी) strings — first-class
  features/
    modules.dart                 single registry → drives drawer, grid, router
    dashboard/                   module grid (home)
    auth/                        login + register screens
    <module>/<module>_screen.dart   one stub per society module
  shared/widgets/
    app_drawer.dart              nav drawer generated from modules.dart
    module_placeholder.dart      shared "coming soon" page used by stubs
```

## Conventions (carried over from the web app)

- **Bilingual from day one.** Every visible label resolves through
  `AppLocalizations.of(context).t('key')` with both `strings_en` and
  `strings_mr`. Add Marathi alongside English for any new key.
- **One source of truth for modules.** Add a society module by adding an entry
  to `features/modules.dart`, a screen file, and a route in `app/router.dart`.
- **Admin gating.** `ModuleDef.adminOnly` hides a module in the drawer for
  non-admins; enforce real auth in the backend (already done there).

## Next steps (when business logic begins)

1. Back `api_client.dart` with `http`/`dio`; add bearer token + 401→refresh.
2. Implement the real auth flow in `auth_controller.dart` (login + OTP register),
   mirroring `../ui/src/context/AuthContext.tsx`.
3. Replace each `ModulePlaceholder` with real list/detail UI per module.
