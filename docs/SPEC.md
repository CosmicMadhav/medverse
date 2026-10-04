# MedVerse — Build Spec

> Patient-centric app that collects scattered medical records, explains them in plain English/Hindi,
> compares conflicting doctor opinions side by side, and prepares questions for the next visit.
> **Never diagnoses, never prescribes, never says which doctor is right.**

Team: Preeti Maheshwari (Research & Product), Madhav Laddha (Backend & App)
Stack: Flutter (Android) · Supabase (Postgres, Auth, Storage, Edge Functions) · Google ML Kit / Cloud Vision OCR · LLM via Edge Function · GitHub Pages (website)

---

## 1. Status

| Part | State |
|---|---|
| Flutter UI — all screens, navigation, static data | ✅ done (`lib/`) |
| Supabase schema + RLS | ✅ drafted (`supabase/schema.sql`) |
| Website (GitHub Pages) | ✅ `site/index.html` |
| Auth, storage, OCR, AI, real data | ⏳ next phase |

## 2. Screens (built)

| # | Screen | File | What it does |
|---|---|---|---|
| 1 | Splash + Onboarding + Language | `onboarding_screen.dart` | 3 intro pages, English/Hindi choice |
| 2 | Home | `home_screen.dart` | Family switcher, *Needs attention* alerts (critical value, duplicate test, falling trend), quick actions, today's doses, upcoming visits |
| 3 | Records | `records_screen.dart` | Search, filter (reports/prescriptions/scans), **Private vault** with PIN (demo 1234) |
| 4 | Record detail | `record_detail_screen.dart` | *In simple words* tab: summary (EN/HI), listen button, each value with range bar + status + plain explanation, OCR confidence warning, **“See in original” highlights the exact source line**. Red-flag banner for critical values (no simplification, call doctor/108) |
| 5 | Add record | `upload_flow.dart` | Camera / gallery / PDF / ABHA → 4-step processing (OCR → extract → simplify → history check) → new record |
| 6 | Compare | `compare_screen.dart` | Cases list, pick 2 consultations, **Side-by-side diff** tagged Agree / Differ / Only A / Only B, filter, tap for plain meaning, *Why might doctors differ?* |
| 7 | Questions for visit | `compare_screen.dart` | Auto-generated questions, tick/untick, add own, copy for WhatsApp, print/PDF preview |
| 8 | Journey (timeline) | `timeline_screen.dart` | Month-grouped events, tap → record |
| 9 | Lab trends | `tools_screens.dart` | Line chart with normal band, points coloured by lab, tap point, insight |
| 10 | Medicines | `tools_screens.dart` | By time slot, mark taken, **cross-doctor drug-class overlap** (Etoricoxib + Diclofenac = 2 NSAIDs), duplicate supplement merge |
| 11 | Health card (QR) | `tools_screens.dart` | QR + blood group, allergies, conditions, meds, emergency contact; 24 h share link |
| 12 | Ask MedVerse | `tools_screens.dart` | Chat + mic (Hindi), suggested questions, listen to answer |
| 13 | Women's health | `tools_screens.dart` | Anaemia/thyroid/PCOS/Vit-D watch list, pregnancy week + ANC checklist (PMSMA note), cycle log |
| 14 | ASHA mode | `tools_screens.dart` | Community health worker manages people without phones |
| 15 | Profile | `profile_screen.dart` | ABHA link, family, language, ASHA toggle, vault PIN, privacy & responsible-AI explainers |

Design: warm paper background `#F7F3EC`, teal ink `#1F5C57`, terracotta `#C8553D`, mustard `#D9A441`; Fraunces (serif headings) + DM Sans (body); flat hairline-border cards, no gradients, light only. Tokens in `lib/theme.dart`.

## 3. Integration plan (next)

### Phase A — Auth & data (week 1)
- `supabase_flutter` package; phone OTP login (Supabase Auth, MSG91/Twilio).
- Run `supabase/schema.sql`; private bucket `records`.
- Replace `MockData` reads with a `Repository` class (same model classes in `lib/data/models.dart`) — screens already read from `AppState`, so only `AppState` changes.

### Phase B — Document pipeline (week 2)
1. App uploads images to `records/{uid}/{record_id}/`.
2. Edge function `process-record`:
   - OCR → `ocr_lines[]` (Google Cloud Vision; ML Kit on-device as offline fallback).
   - LLM call with **strict JSON schema**: type, doctor, date, hospital, lab values (name, value, unit, range, `source_line`), medicines (generic, drug_class), ordered tests.
   - Code (not LLM) decides `status` from reference ranges; **critical thresholds are a hard-coded table** (K⁺ > 6.0, Hb < 7, glucose > 400 …) → `alerts` + `has_critical`.
   - LLM writes `simple_en`/`simple_hi` only for non-critical values.
   - Duplicate check: `ordered_tests.test_code` vs `lab_values` for same member in last 90 days.
   - Drug overlap: same `drug_class` across active medicines from different prescribers.
3. Realtime subscription updates the processing screen.

### Phase C — Opinion compare (week 3)
- Edge function `compare-opinions(record_a, record_b)` → `diff_points` + `why_differ` + `visit_questions`.
- Prompt rule: describe differences, list *general* reasons, **never recommend one side**.

### Phase D — Voice, sharing, reminders (week 4)
- `flutter_tts` (hi-IN / en-IN) for Listen; `speech_to_text` for mic.
- `share_links` + public edge function `card/{token}` renders 1-page HTML summary (excludes private records, expires 24 h).
- `flutter_local_notifications` for dose & appointment reminders.
- ABHA: ABDM sandbox (HIP/HIU) — stretch goal.

## 4. Safety rules (enforced in code)
1. Critical values → red banner, no AI explanation, call-doctor CTA.
2. Every explanation links to `source_line`; OCR confidence < 0.85 → “please verify”.
3. Compare never ranks doctors; disclaimer on every result screen.
4. Private-vault records never leave the device's view or appear on shared cards.
5. Data stored in Supabase India region (ap-south-1); delete-all & export in Profile.

## 5. Impact metrics (replace vanity metrics)
- Duplicate tests avoided (count & ₹ saved) — baseline 64.5 % from survey.
- Understanding score before/after reading a report (1-question quiz).
- % of users who took generated questions to a visit.
- Critical-value alerts acted on within 24 h.
- ASHA-registered users without smartphones.

## 6. Run / build
```bash
flutter pub get
flutter run                 # debug on device
flutter build apk --release # build/app/outputs/flutter-apk/app-release.apk
```
