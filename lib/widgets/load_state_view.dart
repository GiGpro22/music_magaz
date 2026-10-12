import 'package:flutter/material.dart';

import '../models/page_result.dart';

class LoadStateView extends StatelessWidget {
  const LoadStateView({
    super.key,
    required this.status,
    required this.isEmpty,
    required this.error,
    required this.onRetry,
    required this.child,
    this.emptyMessage = 'Ничего не найдено',
    this.emptyAction,
  });

  final LoadStatus status;
  final bool isEmpty;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;
  final String emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      LoadStatus.idle ||
      LoadStatus.loading => const Center(child: CircularProgressIndicator()),
      LoadStatus.error => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error ?? 'Ошибка', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
      LoadStatus.success when isEmpty => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emptyMessage),
            if (emptyAction != null) ...[
              const SizedBox(height: 12),
              emptyAction!,
            ],
          ],
        ),
      ),
      LoadStatus.success => child,
    };
  }
}
