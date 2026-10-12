import 'package:flutter/material.dart';

class GenericFormLayout extends StatelessWidget {
  const GenericFormLayout({
    super.key,
    required this.formKey,
    required this.children,
    required this.onSubmit,
    required this.isDirty,
    this.saving = false,
    this.submitLabel = 'Сохранить',
    this.title,
  });

  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSubmit;
  final bool isDirty;
  final bool saving;
  final String submitLabel;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty || saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isDirty) return;
        final leave = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Несохранённые изменения'),
                content: const Text('Уйти без сохранения?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Остаться'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Уйти'),
                  ),
                ],
              ),
        );
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                    ],
                    ...children,
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: saving ? null : onSubmit,
                      child:
                          saving
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(submitLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
