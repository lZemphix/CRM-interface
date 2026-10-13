import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

import '../models/catalog_input.dart';
import '../models/catalog_item.dart';
import '../repos/catalog_repository.dart';

class CatalogItemForm extends StatefulWidget {
  const CatalogItemForm({
    super.key,
    this.details,
    required this.categories,
    required this.onSave,
  });

  final CatalogItemDetails? details;
  final List<String> categories;
  final Future<void> Function(CatalogItemInput) onSave;

  @override
  State<CatalogItemForm> createState() => _CatalogItemFormState();
}

class _CatalogItemFormState extends State<CatalogItemForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late final TextEditingController _sku;
  late final TextEditingController _categoryController;
  final _categoryFocus = FocusNode();
  late CatalogKind _kind;
  late bool _active;
  String _category = '';
  bool _saving = false;
  bool _blocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.details?.item;
    _kind = item?.kind ?? CatalogKind.service;
    _category = item?.category ?? '';
    _categoryController = TextEditingController(text: _category);
    _active = item?.isActive ?? true;
    _name = TextEditingController(text: item?.name);
    _description = TextEditingController(text: item?.description);
    _price = TextEditingController(text: item?.price.toApi());
    _duration = TextEditingController(text: item?.durationMinutes?.toString());
    _sku = TextEditingController(text: item?.sku);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _price,
      _duration,
      _sku,
      _categoryController,
    ]) {
      controller.dispose();
    }
    _categoryFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _blocked || !_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        CatalogItemInput(
          kind: _kind,
          category: _category.trim(),
          name: _name.text.trim(),
          price: CatalogPrice.parse(_price.text),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          durationMinutes:
              _kind == CatalogKind.service && _duration.text.trim().isNotEmpty
              ? int.parse(_duration.text.trim())
              : null,
          sku: _kind == CatalogKind.product && _sku.text.trim().isNotEmpty
              ? _sku.text.trim()
              : null,
          isActive: _active,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogRequestException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _blocked = error.uncertain || error.conflict;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Заполните поле' : null;

  Widget _categoryField() => Autocomplete<String>(
    textEditingController: _categoryController,
    focusNode: _categoryFocus,
    optionsMaxHeight: 160,
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      return widget.categories.where(
        (category) => category.toLowerCase().contains(query),
      );
    },
    onSelected: (value) => _category = value,
    fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
      key: const Key('catalog-form-category'),
      controller: controller,
      focusNode: focus,
      enabled: !_saving,
      maxLength: 60,
      decoration: const InputDecoration(
        labelText: 'Категория *',
        counterText: '',
      ),
      validator: _required,
      onSaved: (value) => _category = value!.trim(),
    ),
  );

  Widget _typeFields() => LayoutBuilder(
    builder: (context, constraints) {
      final kind = DropdownButtonFormField<CatalogKind>(
        key: const Key('catalog-form-kind'),
        initialValue: _kind,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Тип'),
        items: [
          for (final value in CatalogKind.values)
            DropdownMenuItem(value: value, child: Text(value.label)),
        ],
        onChanged: _saving || widget.details != null
            ? null
            : (value) => setState(() => _kind = value!),
      );
      return constraints.maxWidth >= 440
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 14,
              children: [
                Expanded(child: kind),
                Expanded(child: _categoryField()),
              ],
            )
          : Column(spacing: 14, children: [kind, _categoryField()]);
    },
  );

  Widget _priceFields() => LayoutBuilder(
    builder: (context, constraints) {
      final price = TextFormField(
        key: const Key('catalog-form-price'),
        controller: _price,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Цена, ₽ *',
          hintText: '0,00',
        ),
        validator: (value) {
          try {
            CatalogPrice.parse(value ?? '');
            return null;
          } on FormatException {
            return 'От 0 до 9 999 999 999,99 ₽, до двух знаков';
          }
        },
      );
      final extra = _kind == CatalogKind.service
          ? TextFormField(
              key: const Key('catalog-form-duration'),
              controller: _duration,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Длительность, мин',
                hintText: 'Необязательно',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final minutes = int.tryParse(value.trim());
                return minutes == null || minutes < 1 || minutes > 10080
                    ? 'Целое число от 1 до 10080'
                    : null;
              },
            )
          : TextFormField(
              key: const Key('catalog-form-sku'),
              controller: _sku,
              enabled: !_saving,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Артикул',
                hintText: 'Необязательно',
                counterText: '',
              ),
            );
      return constraints.maxWidth >= 440
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 14,
              children: [
                Expanded(child: price),
                Expanded(child: extra),
              ],
            )
          : Column(spacing: 14, children: [price, extra]);
    },
  );

  Widget _fields() => Form(
    key: _form,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          _typeFields(),
          TextFormField(
            key: const Key('catalog-form-name'),
            controller: _name,
            enabled: !_saving,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Название *',
              counterText: '',
            ),
            validator: _required,
          ),
          TextFormField(
            key: const Key('catalog-form-description'),
            controller: _description,
            enabled: !_saving,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Описание',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
          _priceFields(),
          CheckboxListTile(
            key: const Key('catalog-form-active'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.activeElement,
            value: _active,
            onChanged: _saving
                ? null
                : (value) => setState(() => _active = value!),
            title: const Text(
              'Позиция активна в каталоге',
              style: TextStyle(fontSize: 13),
            ),
          ),
          if (widget.details != null)
            const Text(
              'Тип существующей позиции изменить нельзя. Филиальные цены и доступность сохраняются.',
              style: TextStyle(fontSize: 12, color: AppColors.textMutted),
            ),
          if (_error != null)
            SelectableText(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.notActiveBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.activeElement),
          ),
        ),
      ),
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          widget.details == null ? 'Новая позиция' : 'Редактировать позицию',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(width: 520, child: _fields()),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('catalog-form-save'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.activeElement,
            ),
            onPressed: _saving || _blocked ? null : _submit,
            child: Text(
              _saving
                  ? 'Сохраняем…'
                  : widget.details == null
                  ? 'Добавить'
                  : 'Сохранить',
            ),
          ),
        ],
      ),
    ),
  );
}
