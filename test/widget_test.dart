import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_magaz/core/validators.dart';
import 'package:music_magaz/models/page_result.dart';
import 'package:music_magaz/models/role.dart';
import 'package:music_magaz/widgets/load_state_view.dart';

void main() {
  testWidgets('показывает индикатор загрузки', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadStateView(
            status: LoadStatus.loading,
            isEmpty: false,
            error: null,
            onRetry: _noop,
            child: Text('data'),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('data'), findsNothing);
  });

  testWidgets('показывает пустой результат без индикатора', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadStateView(
            status: LoadStatus.success,
            isEmpty: true,
            error: null,
            onRetry: _noop,
            emptyMessage: 'Книг не найдено',
            child: Text('data'),
          ),
        ),
      ),
    );
    expect(find.text('Книг не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('показывает ошибку и кнопку повтора', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadStateView(
            status: LoadStatus.error,
            isEmpty: false,
            error: 'Сервер недоступен',
            onRetry: () => retried = true,
            child: const Text('data'),
          ),
        ),
      ),
    );
    expect(find.text('Сервер недоступен'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    expect(retried, isTrue);
  });

  testWidgets('валидация формы с пустым названием', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: V.combine([V.required(), V.length(min: 2)]),
                ),
                FilledButton(
                  onPressed: () => key.currentState!.validate(),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    expect(find.text('Поле обязательно'), findsOneWidget);
  });

  testWidgets('кнопка каталога скрыта для покупателя', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final role = Role.customer;
              return Column(
                children: [
                  if (Permissions.canManageCatalog(role))
                    const FilledButton(
                      onPressed: null,
                      child: Text('Добавить товар'),
                    ),
                  const Text('Каталог'),
                ],
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('Добавить товар'), findsNothing);
    expect(find.text('Каталог'), findsOneWidget);
  });
}

void _noop() {}
