import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/demo_users.dart';
import '../features/feature_key.dart';
import '../providers/config_providers.dart';
import 'checkout_widgets.dart';
import 'developer_menu_screen.dart';

/// The demo home screen: a promo banner and a checkout section, both
/// flag-gated, plus the user profile switcher.
class HomeScreen extends ConsumerWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPromo = ref.watch(featureFlagProvider(FeatureKey.promoBanner));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flag Kit Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Developer menu',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DeveloperMenuScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _UserSwitcher(),
          const SizedBox(height: 16),
          if (showPromo) const _PromoBanner(),
          const SizedBox(height: 16),
          const _CheckoutSection(),
        ],
      ),
    );
  }
}

/// Swaps the entire checkout implementation on one flag check.
class _CheckoutSection extends ConsumerWidget {
  const _CheckoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNewCheckout = ref.watch(
      featureFlagProvider(FeatureKey.newCheckout),
    );
    return isNewCheckout
        ? const NewCheckoutWidget()
        : const LegacyCheckoutWidget();
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text('Summer sale: 20% off everything!'),
      leading: const Icon(Icons.local_offer),
      actions: const [SizedBox.shrink()],
    );
  }
}

/// Switches between the demo user profiles, demonstrating that different
/// users deterministically land in different rollout buckets.
class _UserSwitcher extends ConsumerWidget {
  const _UserSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return SegmentedButton<String>(
      segments: [
        for (final user in DemoUsers.all)
          ButtonSegment(
            value: user.userId,
            label: Text(user.userId == 'user_a' ? 'User A' : 'User B'),
            icon: const Icon(Icons.person),
          ),
      ],
      selected: {currentUser.userId},
      onSelectionChanged: (selection) {
        final user = DemoUsers.all.firstWhere(
          (u) => u.userId == selection.single,
        );
        ref.read(sessionControllerProvider).updateUserContext(user);
      },
    );
  }
}
