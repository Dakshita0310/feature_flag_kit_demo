import 'package:flutter/material.dart';

/// The experimental checkout experience (rollout-gated).
///
/// Component substitution: this whole widget is swapped against
/// [LegacyCheckoutWidget] at a single flag check, so ending the experiment
/// means deleting one class and one condition - no spaghetti.
class NewCheckoutWidget extends StatelessWidget {
  /// Creates the new checkout card.
  const NewCheckoutWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rocket_launch,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'New Checkout Experience',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('One-tap payment, saved addresses, live totals.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () {}, child: const Text('Buy now')),
          ],
        ),
      ),
    );
  }
}

/// The stable checkout flow, shown when the experiment is off or killed.
class LegacyCheckoutWidget extends StatelessWidget {
  /// Creates the legacy checkout card.
  const LegacyCheckoutWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined),
                const SizedBox(width: 8),
                Text('Checkout', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Classic three-step checkout.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Proceed to checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
