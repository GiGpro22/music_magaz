import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
  });

  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 48,
          ),
          child: DataTable(
            columns: [
              if (onToggleSelect != null) const DataColumn(label: Text('')),
              for (final col in columns)
                DataColumn(
                  label: InkWell(
                    onTap:
                        col.sortField == null || onSort == null
                            ? null
                            : () => onSort!(col.sortField!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(col.label),
                        if (col.sortField != null && col.sortField == sortField)
                          Icon(
                            sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                          ),
                      ],
                    ),
                  ),
                  numeric: col.numeric,
                ),
              if (actions != null) const DataColumn(label: Text('Действия')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  cells: [
                    if (onToggleSelect != null)
                      DataCell(
                        Checkbox(
                          value: selected.contains(idOf(item)),
                          onChanged: (_) => onToggleSelect!(idOf(item)),
                        ),
                      ),
                    for (final col in columns) DataCell(col.build(item)),
                    if (actions != null)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!(item),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
