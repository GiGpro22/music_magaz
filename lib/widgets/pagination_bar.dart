import 'package:flutter/material.dart';

import '../models/page_result.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.result,
    required this.onPage,
    required this.onSize,
  });

  final PageResult<dynamic> result;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Всего: ${result.total}'),
          IconButton(
            tooltip: 'Первая',
            onPressed: result.hasPrevious ? () => onPage(1) : null,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: 'Назад',
            onPressed:
                result.hasPrevious ? () => onPage(result.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${result.page} / ${result.totalPages}'),
          IconButton(
            tooltip: 'Вперёд',
            onPressed: result.hasNext ? () => onPage(result.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Последняя',
            onPressed: result.hasNext ? () => onPage(result.totalPages) : null,
            icon: const Icon(Icons.last_page),
          ),
          DropdownButton<int>(
            value: result.size,
            items:
                const [10, 25, 50]
                    .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                    .toList(),
            onChanged: (v) {
              if (v != null) onSize(v);
            },
          ),
        ],
      ),
    );
  }
}
