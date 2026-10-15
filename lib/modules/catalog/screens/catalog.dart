import 'dart:async';

import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/command_scope.dart';
import 'package:crm_interface/core/keyboard/keybindings.dart';
import 'package:crm_interface/core/keyboard/search_shortcut_scope.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';

import '../models/catalog_item.dart';
import '../repos/catalog_repository.dart';
import '../widgets/catalog_item_form.dart';
import '../widgets/catalog_row.dart';
import '../widgets/catalog_summary.dart';
import '../widgets/catalog_toolbar.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  CatalogKind? _kind;
  String? _category;
  CatalogPage? _page;
  List<String> _categories = [];
  String? _error;
  String? _categoryError;
  bool _loading = true;
  bool _dialogOpen = false;
  bool _mutating = false;
  int _offset = 0;
  int _requestId = 0;
  int _categoryRequestId = 0;
  Timer? _debounce;

  bool get _busy => _dialogOpen || _mutating;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage());
    unawaited(_loadCategories());
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _requestId++;
    _categoryRequestId++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    _debounce?.cancel();
    if (_busy) return;
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.getItems(
        search: _search.text,
        kind: _kind,
        category: _category,
        offset: _offset,
      );
      if (!mounted || request != _requestId) return;
      // A deletion on the last page must not strand the user on an empty page.
      if (page.items.isEmpty && page.total > 0 && _offset >= page.total) {
        _offset = ((page.total - 1) ~/ page.limit) * page.limit;
        await _loadPage();
        return;
      }
      setState(() {
        _page = page;
        _offset = page.offset;
        _loading = false;
      });
    } on CatalogRequestException catch (error) {
      if (mounted && request == _requestId) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    final request = ++_categoryRequestId;
    try {
      final categories = await widget.repository.getCategories();
      if (mounted && request == _categoryRequestId) {
        setState(() {
          _categories = categories;
          _categoryError = null;
        });
      }
    } on CatalogRequestException catch (error) {
      if (mounted && request == _categoryRequestId) {
        setState(() => _categoryError = error.message);
      }
    }
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    // Invalidate immediately, not only when the debounce starts the next GET.
    _requestId++;
    setState(() {
      _offset = 0;
      _loading = true;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_loadPage()),
    );
  }

  void _applyFilters({CatalogKind? kind, String? category}) {
    setState(() {
      _kind = kind;
      _category = category;
      _offset = 0;
    });
    unawaited(_loadPage());
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openEditor([CatalogItem? item]) async {
    if (_busy || _loading) return;
    _requestId++;
    setState(() => _dialogOpen = true);
    try {
      final details = item == null
          ? null
          : await widget.repository.getItem(item.id);
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CatalogItemForm(
          details: details,
          categories: _categories,
          onSave: (input) async {
            if (details == null) {
              await widget.repository.createItem(input);
            } else {
              await widget.repository.updateItem(
                details.item.id,
                input,
                details.version,
              );
            }
          },
        ),
      );
      if (mounted && saved == true) _message('Позиция сохранена');
    } on CatalogRequestException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) {
        setState(() => _dialogOpen = false);
        // Also reconcile cancelled forms after an uncertain network outcome.
        await Future.wait([_loadPage(), _loadCategories()]);
      }
    }
  }

  Future<void> _archive(CatalogItem item) async {
    if (_busy || _loading) return;
    setState(() => _dialogOpen = true);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DialogKeyboardScope(
        child: AlertDialog(
          title: const Text('Архивировать позицию?'),
          content: Text(
            '«${item.name}» исчезнет из каталога. Это не просто скрытие: данные сохранятся, но восстановление здесь пока недоступно.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              key: const Key('catalog-confirm-archive'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.activeElement,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Архивировать'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _dialogOpen = false;
      _mutating = confirmed == true;
    });
    if (confirmed != true) return;
    _requestId++;
    try {
      await widget.repository.archiveItem(item.id);
      if (mounted) _message('Позиция архивирована');
    } on CatalogRequestException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
        await Future.wait([_loadPage(), _loadCategories()]);
      }
    }
  }

  Widget _header() => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 20,
    runSpacing: 12,
    children: [
      const Text(
        'Каталог',
        style: TextStyle(
          fontSize: 25,
          height: 1.2,
          letterSpacing: -.5,
          fontWeight: FontWeight.w700,
          color: AppColors.taskCardText,
        ),
      ),
      FilledButton.icon(
        key: const Key('catalog-add'),
        onPressed: _busy || _loading ? null : () => unawaited(_openEditor()),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Добавить позицию'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.activeElement,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _list(bool compact, bool showCategory) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          spacing: 12,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: () => unawaited(_loadPage()),
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    final page = _page;
    if (page == null) return const SizedBox();
    if (page.items.isEmpty) {
      final filtered =
          _search.text.trim().isNotEmpty || _kind != null || _category != null;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 55),
        child: Column(
          spacing: 4,
          children: [
            Text(
              filtered ? 'Ничего не найдено' : 'Каталог пока пуст',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              filtered
                  ? 'Попробуйте изменить поиск или фильтры.'
                  : 'Добавьте первую услугу или товар.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMutted),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (!compact) CatalogListHeader(showCategory: showCategory),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: page.items.length,
          itemBuilder: (context, index) {
            final item = page.items[index];
            return CatalogRow(
              key: ValueKey('catalog-row-${item.id}'),
              item: item,
              showCategory: showCategory,
              compact: compact,
              onEdit: _busy ? null : () => unawaited(_openEditor(item)),
              onArchive: _busy ? null : () => unawaited(_archive(item)),
            );
          },
        ),
      ],
    );
  }

  Widget _footer() {
    final page = _page;
    if (page == null || _error != null || _loading) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.notActiveBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              page.items.isEmpty
                  ? 'Показано 0 из ${page.total}'
                  : 'Показано ${page.offset + 1}–${page.offset + page.items.length} из ${page.total}',
              style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
            ),
          ),
          IconButton(
            key: const Key('catalog-prev'),
            tooltip: 'Предыдущая страница',
            onPressed: _busy || page.offset == 0
                ? null
                : () {
                    _offset = (page.offset - page.limit).clamp(0, page.total);
                    unawaited(_loadPage());
                  },
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          IconButton(
            key: const Key('catalog-next'),
            tooltip: 'Следующая страница',
            onPressed: _busy || page.offset + page.items.length >= page.total
                ? null
                : () {
                    _offset = page.offset + page.limit;
                    unawaited(_loadPage());
                  },
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RegisterSearchFocus(
    node: _searchFocus,
    child: CommandScope(
      commands: {
        AppCommand.focusSearch: () {
          if (!_busy) _searchFocus.requestFocus();
        },
      },
      child: ColoredBox(
        color: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 18 : 32,
                  28,
                  compact ? 18 : 32,
                  60,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    CatalogSummary(
                      counts: _loading || _error != null ? null : _page?.counts,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.notActiveBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x09101828),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CatalogToolbar(
                            searchController: _search,
                            searchFocusNode: _searchFocus,
                            kind: _kind,
                            category: _category,
                            categories: _categories,
                            onSearchChanged: _searchChanged,
                            onSearchSubmitted: () => unawaited(_loadPage()),
                            onKindChanged: (value) =>
                                _applyFilters(kind: value, category: _category),
                            onCategoryChanged: (value) =>
                                _applyFilters(kind: _kind, category: value),
                          ),
                          if (_categoryError != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Категории недоступны',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMutted,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        unawaited(_loadCategories()),
                                    child: const Text('Повторить категории'),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(
                            height: 1,
                            color: AppColors.notActiveBorder,
                          ),
                          _list(compact, constraints.maxWidth >= 1050),
                          _footer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
