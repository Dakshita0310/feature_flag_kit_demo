# feature_flag_kit_demo

[![CI](https://github.com/Dakshita0310/feature_flag_kit_demo/actions/workflows/ci.yaml/badge.svg)](https://github.com/Dakshita0310/feature_flag_kit_demo/actions/workflows/ci.yaml)

Flutter demo client for
[`feature_flag_kit`](https://pub.dev/packages/feature_flag_kit): staged
rollouts, deterministic bucketing, and instant kill-switches in a real app.

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

## Architecture

See [docs/flutter_app_architecture_spec.md](docs/flutter_app_architecture_spec.md)
for the app design, [docs/prd.md](docs/prd.md) for the product requirements,
and [docs/implementation_plan.md](docs/implementation_plan.md) for the build
plan.

## Roadmap

- [x] Scaffold: strict lints, CI, docs, feature_flag_kit ^0.1.0
- [x] Feature registry and baked-in defaults
- [x] Mock config repository (Config A/B)
- [x] SharedPreferences LKG store
- [x] Riverpod integration
- [x] Refresh triggers and user switching
- [ ] Demo UI with gated feature
- [ ] Developer menu
- [ ] End-to-end scenarios
- [ ] Final docs

## License

MIT
