import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_config_repository.dart';
import '../features/feature_key.dart';
import '../lifecycle/silent_push_simulator.dart';
import '../providers/config_providers.dart';

/// In-app debug screen surfacing the engine's explainability:
///
/// - every flag's [EvaluationResult] (value, reason, debug message)
/// - the current user's deterministic buckets
/// - session vs latest-fetched config versions and refresh errors
/// - environment switching (Config A/B) and the silent-push simulator
class DeveloperMenuScreen extends ConsumerStatefulWidget {
  /// Creates the developer menu.
  const DeveloperMenuScreen({super.key});

  @override
  ConsumerState<DeveloperMenuScreen> createState() =>
      _DeveloperMenuScreenState();
}

class _DeveloperMenuScreenState extends ConsumerState<DeveloperMenuScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(sessionControllerProvider);
    final repo = ref.watch(mockRepositoryProvider);
    final user = ref.watch(currentUserProvider);
    ref.watch(configRevisionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Flags'),
          for (final key in FeatureKey.values) _FlagTile(featureKey: key),
          const Divider(height: 32),
          _section('User'),
          ListTile(
            dense: true,
            title: Text(
              '${user.userId} '
              '(country: ${user.country ?? '-'}, '
              'appVersion: ${user.appVersion ?? '-'})',
            ),
            subtitle: Text(
              [
                for (final key in FeatureKey.values)
                  '${key.key}: bucket '
                      '${getRolloutBucket(user.userId, key.key)}',
              ].join('\n'),
            ),
          ),
          const Divider(height: 32),
          _section('Session'),
          ListTile(
            dense: true,
            title: const Text('Session config (frozen)'),
            trailing: Text(controller.sessionConfigVersion),
          ),
          ListTile(
            dense: true,
            title: const Text('Latest fetched (next launch)'),
            trailing: Text(controller.latestFetchedVersion ?? 'none yet'),
          ),
          ListTile(
            dense: true,
            title: const Text('Live kill-switches'),
            trailing: Text(
              controller.activeKillSwitches.isEmpty
                  ? 'none'
                  : controller.activeKillSwitches.join(', '),
            ),
          ),
          ListTile(
            dense: true,
            title: const Text('Last refresh error'),
            trailing: Text('${controller.lastRefreshError ?? 'none'}'),
          ),
          ListTile(
            dense: true,
            title: const Text('Mock fetches served'),
            trailing: Text('${repo.fetchCount}'),
          ),
          const Divider(height: 32),
          _section('Backend environment'),
          SegmentedButton<MockEnvironment>(
            segments: const [
              ButtonSegment(
                value: MockEnvironment.configA,
                label: Text('Config A (50%)'),
              ),
              ButtonSegment(
                value: MockEnvironment.configB,
                label: Text('Config B (killed)'),
              ),
            ],
            selected: {repo.environment},
            onSelectionChanged: (selection) {
              setState(() => repo.environment = selection.single);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.notifications_active),
            label: const Text('Simulate silent push'),
            onPressed: () async {
              await SilentPushSimulator(controller).simulatePush();
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh now (manual pull)'),
            onPressed: () async {
              await controller.refresh();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _FlagTile extends ConsumerWidget {
  const _FlagTile({required this.featureKey});

  final FeatureKey featureKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(evaluationResultProvider(featureKey));
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      title: Text(featureKey.key),
      subtitle: Text('${result.reason.name}\n${result.debugMessage}'),
      isThreeLine: true,
      trailing: Chip(
        label: Text(result.isEnabled ? 'ON' : 'OFF'),
        backgroundColor: result.isEnabled
            ? scheme.primaryContainer
            : scheme.errorContainer,
      ),
    );
  }
}
