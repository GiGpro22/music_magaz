import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/validators.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repository.dart';
import '../widgets/generic_form_layout.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.id});
  final String? id;
  bool get isEditing => id != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _year = TextEditingController();
  final _description = TextEditingController();

  String? _brandId;
  String? _supplierId;
  List<String> _categoryIds = [];
  List<Brand> _brands = [];
  List<Supplier> _suppliers = [];
  List<Category> _categories = [];
  Map<String, String> _serverErrors = {};
  bool _dirty = false;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final brandRepo = context.read<BrandRepository>();
    final supplierRepo = context.read<SupplierRepository>();
    final categoryRepo = context.read<CategoryRepository>();
    final productRepo = context.read<ProductRepository>();
    final brands = await brandRepo.findAllActive();
    final suppliers = await supplierRepo.findAllActive();
    final categories = await categoryRepo.findAllActive();
    if (widget.isEditing) {
      final product = await productRepo.findById(widget.id!);
      if (product != null) {
        _name.text = product.name;
        _sku.text = product.sku;
        _price.text = product.price.toStringAsFixed(0);
        _stock.text = '${product.stock}';
        _year.text = product.year == 0 ? '' : '${product.year}';
        _description.text = product.description;
        _brandId = product.brandId;
        _supplierId = product.supplierId;
        _categoryIds = [...product.categoryIds];
      }
    }
    if (!mounted) return;
    setState(() {
      _brands = brands;
      _suppliers = suppliers;
      _categories = categories;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _stock.dispose();
    _year.dispose();
    _description.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final product = Product(
      id: widget.id ?? '',
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      price: double.parse(_price.text.replaceAll(',', '.')),
      stock: int.parse(_stock.text),
      year: int.tryParse(_year.text) ?? 0,
      brandId: _brandId!,
      supplierId: _supplierId!,
      categoryIds: _categoryIds,
      description: _description.text.trim(),
    );
    try {
      final repo = context.read<ProductRepository>();
      if (widget.isEditing) {
        await repo.update(product);
      } else {
        await repo.create(product);
      }
      if (mounted) context.go('/products');
    } on ValidationException catch (e) {
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: GenericFormLayout(
        formKey: _formKey,
        isDirty: _dirty,
        saving: _saving,
        title: widget.isEditing ? 'Редактирование товара' : 'Новый товар',
        onSubmit: _submit,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _markDirty(),
            validator:
                (v) =>
                    V.combine([V.required(), V.length(min: 2)])(v) ??
                    _serverErrors['name'],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sku,
            decoration: const InputDecoration(
              labelText: 'SKU',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              _markDirty();
              if (_serverErrors.containsKey('sku')) {
                setState(() => _serverErrors.remove('sku'));
              }
            },
            validator:
                (v) =>
                    V.combine([V.required(), V.length(min: 3)])(v) ??
                    _serverErrors['sku'],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _price,
            decoration: const InputDecoration(
              labelText: 'Цена',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _markDirty(),
            validator: V.number(min: 1),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stock,
            decoration: const InputDecoration(
              labelText: 'Остаток',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _markDirty(),
            validator: V.integer(min: 0),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _year,
            decoration: const InputDecoration(
              labelText: 'Год',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _markDirty(),
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              return V.integer(min: 1950, max: 2100)(v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _brandId,
            decoration: const InputDecoration(
              labelText: 'Бренд',
              border: OutlineInputBorder(),
            ),
            items:
                _brands
                    .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    )
                    .toList(),
            onChanged: (v) {
              setState(() => _brandId = v);
              _markDirty();
            },
            validator: (v) => v == null ? 'Выберите бренд' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _supplierId,
            decoration: const InputDecoration(
              labelText: 'Поставщик',
              border: OutlineInputBorder(),
            ),
            items:
                _suppliers
                    .map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    )
                    .toList(),
            onChanged: (v) {
              setState(() => _supplierId = v);
              _markDirty();
            },
            validator: (v) => v == null ? 'Выберите поставщика' : null,
          ),
          const SizedBox(height: 16),
          FormField<List<String>>(
            initialValue: _categoryIds,
            validator:
                (value) =>
                    (value == null || value.isEmpty)
                        ? 'Выберите хотя бы одну категорию'
                        : null,
            builder: (field) {
              return InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Категории',
                  border: const OutlineInputBorder(),
                  errorText: field.errorText,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _categories.map((c) {
                        final selected = field.value!.contains(c.id);
                        return FilterChip(
                          label: Text(c.name),
                          selected: selected,
                          onSelected: (_) {
                            final next = [...field.value!];
                            selected ? next.remove(c.id) : next.add(c.id);
                            field.didChange(next);
                            setState(() => _categoryIds = next);
                            _markDirty();
                          },
                        );
                      }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Описание',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _markDirty(),
          ),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await context.read<ProductRepository>().findById(widget.id);
      setState(() {
        _product = p;
        _error = p == null ? 'Товар не найден' : null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final p = _product;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${p.price.toStringAsFixed(0)} ₽'),
            Text('SKU: ${p.sku}'),
            Text('Бренд: ${p.brandName}'),
            Text('Поставщик: ${p.supplierName}'),
            Text('Категории: ${p.categoryNames.join(', ')}'),
            Text('Остаток: ${p.stock}'),
            if (p.year > 0) Text('Год: ${p.year}'),
            const SizedBox(height: 12),
            Text(p.description),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/products'),
                  child: const Text('К списку'),
                ),
                FilledButton(
                  onPressed: () => context.go('/products/${p.id}/edit'),
                  child: const Text('Изменить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
