# Milestone 4: Mobile Templates

## Section 1: Task Summary

**What:** Create 3 new mobile stack templates in YAML format, following the exact pattern of the existing `mobile-expo.yaml` template.

**Templates to create:**
1. `mobile-nativewind.yaml` — Expo SDK 52 + NativeWind v4 (Tailwind for RN) + Expo Router + Supabase
2. `mobile-flutter.yaml` — Flutter 3 + Dart + Supabase + Riverpod + go_router
3. `mobile-expo-revenucat.yaml` — Expo SDK 52 + RevenueCat + Expo Router + Supabase (subscription/IAP monetization)

**In scope:**
- YAML template file for each
- Each must validate against `schemas/stack-template.schema.json`
- Each includes env validation, test setup, smoke test, EAS/build config

**Out of scope:**
- Native module configuration (use managed workflow / plugins)
- App Store/Play Store submission automation
- CI/CD for mobile (beyond what EAS provides)

**Definition of done:**
- [ ] 3 new YAML files in `config/stacks/`
- [ ] All 3 validate against the JSON Schema
- [ ] Each has complete init_commands, directories, starter_files, commands, claude_md, agents_md
- [ ] NativeWind template includes Tailwind config for React Native
- [ ] Flutter template uses Dart conventions (not TypeScript)
- [ ] RevenueCat template includes paywall setup and entitlements

## Section 2: Project Background

**Canonical reference:** Read `config/stacks/mobile-app.yaml` — the existing Expo template. New mobile templates should match its structure while adding framework-specific content.

**Key differences from web templates:**
- Mobile uses `npx expo` / `flutter` commands, not `pnpm`
- Mobile needs build commands for iOS/Android
- Mobile needs EAS config (`eas.json`) or equivalent build system
- Mobile has platform-specific gotchas (permissions, native modules, app signing)

## Section 3: Current Task Context

M1 and M2 are complete. This can run in parallel with M3, M5, M6, M7.

## Section 4: Design Document Reference

See `docs/design/design-document.md`:
- Section 3.1: Stack template YAML schema
- Section 4.5: Mobile template specifications

## Section 5: Pre-Implementation Exploration

Before implementing:
1. Read `config/stacks/mobile-app.yaml` — the canonical mobile template
2. Use Context7 for NativeWind v4 setup with Expo
3. Use Context7 for Flutter project structure and Riverpod patterns
4. Use Context7 for RevenueCat React Native SDK setup
5. Check Expo SDK 52 compatibility requirements
6. Review Expo Skills documentation at docs.expo.dev/skills/

## Section 6: Implementation Instructions

### Architecture constraints
- Expo templates: use managed workflow, never bare workflow
- Flutter template: follow Dart conventions (snake_case files, PascalCase classes)
- All templates must include env validation (Zod for Expo, envied for Flutter)
- All templates must include at least a smoke test
- RevenueCat template must include sample paywall component

### Template-specific guidance

**mobile-nativewind.yaml:**
- NativeWind v4 setup (uses Tailwind CSS 3.x under the hood)
- Requires babel/metro config changes for NativeWind
- Include `tailwind.config.ts` configured for React Native
- Starter files: themed components using Tailwind classes
- Gotcha: NativeWind className prop, not style prop — note in AGENTS.md
- Gotcha: Some Tailwind utilities don't work in RN (e.g., grid) — note which ones

**mobile-flutter.yaml:**
- `flutter create` as init command
- Riverpod for state management (modern, testable)
- go_router for navigation
- Supabase Flutter SDK for backend
- Include `analysis_options.yaml` with strict linting
- Starter files: lib/main.dart, lib/app.dart, lib/features/ structure
- Commands: `flutter run`, `flutter test`, `flutter analyze`, `dart format`
- Gotcha: Widget tree depth matters for performance — note in AGENTS.md

**mobile-expo-revenucat.yaml:**
- Extends the base Expo template with RevenueCat SDK
- Include RevenueCat initialization in app startup
- Sample paywall component with offering display
- Sample entitlement check hook
- Gotcha: RevenueCat needs native configuration for sandbox testing
- Gotcha: iOS requires StoreKit configuration file for local testing

### Git workflow
- Branch: `feature/mobile-templates`
- Commit per template: `feat: add {template-name} stack template`

## Section 7: Final Reminders

- Validate each YAML against schema before committing
- Use Context7 for ALL framework APIs — especially NativeWind v4 and RevenueCat which change frequently
- Flutter template uses Dart, not TypeScript — adjust all conventions accordingly
- RevenueCat template must include both iOS and Android setup notes in AGENTS.md
- Test init_commands mentally — ensure package names and versions are correct
- Include EAS config (eas.json) in Expo templates
