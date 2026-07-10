# Flutter App Architecture: feature_flag_kit_demo

## Overview

This document specifies the architecture of the demo client app consuming the
[`feature_flag_kit`](https://pub.dev/packages/feature_flag_kit) engine from
pub.dev. The goal is that gating a feature feels like a simple configuration
check, with zero network blocking during rendering and a clean cleanup story
when experiments conclude.

The engine package owns evaluation, validation, and selective-freeze session
semantics (`ConfigSessionController`). The app owns everything
platform-specific:

- `MockConfigRepository` implementing `ConfigFetcher` (Config A/B, artificial
  latency)
- A SharedPreferences-backed `ConfigStore` (Last-Known-Good cache)
- Refresh triggers: cold start, app foregrounding, simulated silent push
- Riverpod bindings and the gated demo UI
- The developer menu (explainability, environment switching)

---

## 1. Feature Registry & Baked-In Defaults

Feature keys are an enum to prevent string typos. Defaults are a `const`
structure available synchronously at frame 0 (no async asset loading).

```dart
enum FeatureKey {
  newCheckout('new_checkout'),
  promoBanner('promo_banner');

  const FeatureKey(this.key);
  final String key;
}
```

Adding a gated feature takes three steps: add the enum value, add its entry
to the default config map, and gate the UI with one `ref.watch` line.

---

## 2. State Management Integration (Riverpod, Notifier API)

The app uses the modern Riverpod `Notifier` API (not the legacy
`StateNotifierProvider`). A notifier owns the `ConfigSessionController`,
subscribes to its `changes` stream (live kill-switches, user switches), and
bumps its state to trigger re-evaluation of dependent providers.

```dart
// The provider product developers actually use:
final featureFlagProvider = Provider.family<bool, FeatureKey>((ref, key) {
  ref.watch(configRevisionProvider); // rebumped on live config changes
  return ref.watch(sessionControllerProvider).isEnabled(key.key);
});
```

**Usage in UI:**

```dart
final isNewCheckoutEnabled =
    ref.watch(featureFlagProvider(FeatureKey.newCheckout));
return isNewCheckoutEnabled
    ? const NewCheckoutWidget()
    : const LegacyCheckoutWidget();
```

Because the engine freezes non-emergency changes, these providers only
re-emit for kill-switch teardowns and user-context switches - never for
mid-session rollout drift.

---

## 3. Refresh Triggers

All triggers funnel into the controller's single `refresh()` path, mirroring
the production propagation model (pull on cold start/foregrounding, silent
push for emergencies):

- **Cold start:** `refresh()` fires after boot hydration.
- **Foregrounding:** a `WidgetsBindingObserver` calls `refresh()` on
  `AppLifecycleState.resumed`.
- **Silent push (simulated):** the developer menu's "Simulate silent push"
  button invokes the same trigger a real FCM/APNs background handler would.

---

## 4. The "Clean Up" Strategy (Technical Debt Mitigation)

Flags are checked at the highest possible component boundary, swapping whole
widgets or implementations rather than tweaking parameters inside monoliths.

- **UI:** component substitution (`NewCheckoutWidget` vs
  `LegacyCheckoutWidget`) behind a single `featureFlagProvider` watch.
- **Business logic:** abstract interface + two implementations selected in a
  provider; deleting the losing implementation and the provider condition
  removes the flag with zero spaghetti.
- **Routing:** sealed classes + exhaustive `switch` so removing a variant
  forces compile-time cleanup.

---

## 5. Two-Config Mock Setup

`MockConfigRepository` simulates two backend environments with ~800ms
latency, switchable from the developer menu:

- **Config A:** `new_checkout` at 50% rollout, kill-switch OFF. With the
  engine's pinned buckets, `user_a` (bucket 10) gets the feature and
  `user_b` (bucket 82) does not.
- **Config B:** `new_checkout` kill-switch ON (simulated emergency rollback).

**Demo flow:** boot on Config A as `user_a` (feature visible), switch the
environment to Config B, tap "Simulate silent push", and watch the feature
tear down mid-session with the developer menu explaining
`EvaluationReason.killSwitch`.

---

## 6. Developer Menu

The developer menu surfaces the engine's explainability:

- Every `FeatureKey` with its live `EvaluationResult` (value, reason, debug
  message)
- Current user profile (User A / User B) and their computed buckets
- Environment switch (Config A / Config B) and "Simulate silent push"
- Session vs latest-fetched config versions and the last refresh error
