# feature_flag_kit_demo

[![CI](https://github.com/Dakshita0310/feature_flag_kit_demo/actions/workflows/ci.yaml/badge.svg)](https://github.com/Dakshita0310/feature_flag_kit_demo/actions/workflows/ci.yaml)

Flutter demo client for
[`feature_flag_kit`](https://pub.dev/packages/feature_flag_kit): staged
rollouts, deterministic bucketing, and instant kill-switches in a real app.

## Platform choice

**Flutter.** The evaluation engine is published as a pure Dart package
([`feature_flag_kit`](https://pub.dev/packages/feature_flag_kit)) with zero
runtime dependencies, so the same engine can serve mobile, web, desktop, and
server-side Dart. This app consumes it from pub.dev exactly the way a
product team would, with Riverpod for reactive flag gating and
SharedPreferences for the Last-Known-Good cache.

## Install

Prerequisites: [Flutter SDK](https://docs.flutter.dev/get-started/install)
3.35+ (Dart 3.9+) on your PATH.

```bash
git clone https://github.com/Dakshita0310/feature_flag_kit_demo.git
cd feature_flag_kit_demo
flutter pub get
```

## Run

```bash
flutter run              # pick any connected device or emulator
flutter run -d chrome    # or run it in the browser, no device needed
```

Then follow the [kill-switch walkthrough](#try-the-kill-switch-flow) below.

## Test

```bash
flutter analyze          # static analysis (strict lints)
flutter test             # full suite: unit, provider, widget, and e2e tests
```

The same gates run in CI on every push.

## What it demonstrates

- **Instant boot, zero network blocking:** first frame renders from `const`
  baked-in defaults, hydrates from a SharedPreferences Last-Known-Good cache,
  then fetches in the background.
- **Deterministic rollouts:** User A and User B land in different buckets and
  see different features, stably across restarts.
- **Selective freeze:** rollout changes wait for the next launch; kill-switch
  activations tear features down mid-session, reactively.
- **Explainability:** a developer menu shows every flag's `EvaluationResult`
  (value, reason, debug message), the config versions in play, and lets you
  switch environments, switch users, and simulate a silent push.

## Try the kill-switch flow

```
flutter run
```

1. The app boots as **User A** showing the **New Checkout Experience**
   (bucket 10, inside the 50% rollout). Switch to **User B** (bucket 82) and
   the legacy checkout appears instead - deterministically, every launch.
2. Open the **developer menu** (bug icon) to see why: every flag lists its
   evaluation reason and debug message, and the User section shows the
   computed buckets.
3. Switch the backend environment to **Config B (killed)** - the simulated
   emergency rollback - and tap **Simulate silent push**.
4. Return to the home screen: the new checkout has been torn down
   mid-session and replaced by the legacy flow. The flag now reports
   `killSwitch` in the developer menu.
5. Note the Session section: the frozen session config version vs the
   latest fetched version shows selective freeze at work - non-emergency
   changes wait for the next launch.

## How a feature gets gated

Adding a flag takes three steps (a test enforces step 2):

```dart
// 1. Register the key                        (feature_key.dart)
enum FeatureKey { newCheckout('new_checkout'), ... }

// 2. Give it a baked-in default              (default_config.dart)
FeatureKey.newCheckout.key: const FeatureConfig(
  isKillSwitchActive: false, rolloutPercentage: 50),

// 3. Gate the UI with one line               (anywhere)
final enabled = ref.watch(featureFlagProvider(FeatureKey.newCheckout));
```

## Structure

| Layer | Location | Role |
| :--- | :--- | :--- |
| Engine | [`feature_flag_kit`](https://pub.dev/packages/feature_flag_kit) (pub.dev) | Evaluation hierarchy, deterministic bucketing, validation, selective-freeze session control |
| Data | `lib/src/data/` | `ConfigFetcher`/`ConfigStore` implementations: mock backend (Config A/B), SharedPreferences LKG cache |
| Triggers | `lib/src/lifecycle/`, `lib/src/bootstrap.dart` | Cold start, foregrounding observer, silent-push simulator - all funneling into one `refresh()` |
| Bindings | `lib/src/providers/` | Riverpod `Notifier` bridging the engine's change stream to provider rebuilds |
| UI | `lib/src/ui/` | Component-substitution gating, profile switcher, developer menu |

## Architecture

```mermaid
flowchart TB
    subgraph engine["feature_flag_kit - remote config engine (pub.dev, pure Dart, zero deps)"]
        direction TB
        EV["Evaluator<br/>kill-switch &gt; targeting &gt; rollout &gt; fallback<br/>returns EvaluationResult (value + reason + debug message)"]
        MH["Deterministic bucketing<br/>murmur3('userId:featureKey') % 100"]
        VAL["Strict config validation<br/>atomic, typed errors, never partially applied"]
        SC["ConfigSessionController<br/>selective freeze: kill-switches apply live,<br/>other changes wait for next launch"]
        FI["ConfigFetcher (interface)"]
        SI["ConfigStore (interface)"]
        SC --> EV --> MH
        SC --> VAL
        SC --> FI
        SC --> SI
    end

    subgraph app["feature_flag_kit_demo - Flutter client"]
        direction TB
        subgraph impls["Engine interface implementations"]
            MOCK["MockConfigRepository<br/>Config A: 50% rollout / Config B: kill-switch on"]
            PREFS["SharedPrefsConfigStore<br/>Last-Known-Good cache"]
        end
        subgraph trig["Triggers, all funnel into one refresh()"]
            T1["Cold start"]
            T2["Foregrounding observer"]
            T3["Silent-push simulator"]
        end
        subgraph riv["Riverpod bindings (Notifier API)"]
            REV["ConfigRevision<br/>bumps on engine change events"]
            FFP["featureFlagProvider(FeatureKey)<br/>one-line UI gating"]
        end
        subgraph feat["Implemented features"]
            F1["Gated checkout:<br/>New vs Legacy widget substitution"]
            F2["Promo banner (100% rollout)"]
            F3["User A / User B switcher<br/>deterministic buckets 10 vs 82"]
            F4["Developer menu:<br/>explainability, env switch, silent push"]
        end
    end

    MOCK -. implements .-> FI
    PREFS -. implements .-> SI
    trig --> SC
    SC -- "changes stream<br/>(live kill-switch, user switch)" --> REV
    REV --> FFP --> feat
    F4 -- "switch Config A/B,<br/>simulate push" --> MOCK
```

### Key decisions

1. **Deterministic bucketing, permanent by contract:** vendored MurmurHash3
   of `userId:featureKey` mod 100, the same scheme LaunchDarkly and Unleash
   use. Stable across sessions and devices, independent per feature (no
   sticky cohorts), and pinned by regression tests because changing it would
   silently reshuffle every user.
2. **Selective freeze:** kill-switch activations tear features down
   mid-session; rollout and targeting changes are persisted but only apply
   on the next launch, so the UI never shifts under the user's feet.
3. **Pull-based propagation with push-triggered pulls:** fetch on cold start
   and foregrounding; emergencies arrive as a silent push that triggers the
   same single `refresh()` path. Battery-friendly, CDN-cacheable, and
   push-latency for kill-switches.
4. **Engine as a published pure-Dart package:** evaluation, validation, and
   session semantics live in `feature_flag_kit` on pub.dev with zero
   dependencies; the app only implements `ConfigFetcher`/`ConfigStore` and
   UI. Swapping the mock backend for a real one touches one class.
5. **Fail-safe by default:** boot from `const` in-code defaults (frame-0,
   no splash), hydrate from a validated Last-Known-Good cache, reject
   corrupted payloads atomically, and exclude users when targeting
   attributes are unknown.

See [docs/flutter_app_architecture_spec.md](docs/flutter_app_architecture_spec.md)
for the app design, [docs/prd.md](docs/prd.md) for the product requirements,
and [docs/implementation_plan.md](docs/implementation_plan.md) for the build
plan.

## Tests

`flutter test` runs the full suite: registry guards, fetcher/store contract
tests, provider rebuild semantics (including freeze no-rebuild), trigger
behavior, widget tests for both user profiles and the developer menu, and
end-to-end scenarios (instant boot, mid-session kill, freeze across restart,
determinism, corrupted cache).

## License

MIT
