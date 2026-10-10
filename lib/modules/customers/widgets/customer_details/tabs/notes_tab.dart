import 'package:flutter/material.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';

import '../../../models/customer_note.dart';
import '../../../repos/customers_repository.dart';
import '../note_dialogs.dart';

enum _NoteAction { edit, archive }

class CustomerNotesPanel extends StatefulWidget {
  const CustomerNotesPanel({
    super.key,
    required this.customerId,
    required this.initialNotes,
    required this.repository,
    required this.onChanged,
    this.onReloaded,
    this.refreshController,
  });
  final int customerId;
  final List<CustomerNote> initialNotes;
  final CustomersRepository repository;
  final ValueChanged<List<CustomerNote>> onChanged;
  final ValueChanged<List<CustomerNote>>? onReloaded;
  final SectionRefreshController? refreshController;

  @override
  State<CustomerNotesPanel> createState() => _CustomerNotesPanelState();
}

class _CustomerNotesPanelState extends State<CustomerNotesPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool get _busy => _loading || _dialogOpen || _creating;

  void _bindRefresh() => widget.refreshController?.attach(
    this,
    refresh: _reload,
    busy: () => _busy,
  );

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.refreshController?.changed();
  }

  @override
  void dispose() {
    widget.refreshController?.detach(this);
    super.dispose();
  }

  late List<CustomerNote> _notes;
  bool _loading = false;
  bool _dialogOpen = false;
  bool _refreshRequired = false;
  String? _error;
  int _requestId = 0;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _notes = List.of(widget.initialNotes);
    _bindRefresh();
  }

  @override
  void didUpdateWidget(covariant CustomerNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detach(this);
      _bindRefresh();
    }
    if (oldWidget.customerId != widget.customerId) {
      _requestId++;
      _loading = false;
      _creating = false;
      _error = null;
      _refreshRequired = false;
      _notes = List.of(widget.initialNotes);
    } else if (oldWidget.initialNotes != widget.initialNotes) {
      _notes = List.of(widget.initialNotes);
    }
  }

  void _publish(List<CustomerNote> notes, {bool reloaded = false}) {
    notes.sort((a, b) {
      final date = b.createdAt.compareTo(a.createdAt);
      return date == 0 ? b.id.compareTo(a.id) : date;
    });
    setState(() {
      _notes = notes;
      _error = null;
      _refreshRequired = false;
    });
    (reloaded ? widget.onReloaded ?? widget.onChanged : widget.onChanged)(
      List.unmodifiable(notes),
    );
  }

  Future<void> _reload() async {
    if (_loading || _dialogOpen || _creating) return;
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = await widget.repository.getCustomerNotes(widget.customerId);
      if (mounted && request == _requestId) {
        _publish(List.of(notes), reloaded: true);
      }
    } on CustomerRequestException catch (error) {
      if (mounted && request == _requestId) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _edit(CustomerNote note) async {
    if (_loading || _dialogOpen || _creating || _refreshRequired) return;
    final customerId = widget.customerId;
    setState(() => _dialogOpen = true);
    final repository = widget.repository;
    final saved = await showDialog<CustomerNote>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerNoteEditor(
        note: note,
        onSave: (text) async {
          try {
            return await repository.updateNote(
              customerId,
              note.id,
              UpdateCustomerNoteRequest(text: text, version: note.version),
            );
          } on CustomerRequestException catch (error) {
            _requireRefresh(error, customerId);
            rethrow;
          }
        },
      ),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (saved != null && widget.customerId == customerId) {
      _publish([saved, ..._notes.where((item) => item.id != saved.id)]);
    }
  }

  Future<void> _archive(CustomerNote note) async {
    if (_loading || _dialogOpen || _creating || _refreshRequired) return;
    final customerId = widget.customerId;
    final repository = widget.repository;
    setState(() => _dialogOpen = true);
    final archived = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArchiveCustomerNoteDialog(
        onArchive: () async {
          try {
            await repository.archiveNote(customerId, note.id);
          } on CustomerRequestException catch (error) {
            _requireRefresh(error, customerId);
            rethrow;
          }
        },
      ),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (archived == true && widget.customerId == customerId) {
      _publish(_notes.where((item) => item.id != note.id).toList());
    }
  }

  String _date(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  void _requireRefresh(CustomerRequestException error, int customerId) {
    if (error.refreshRequired && mounted && widget.customerId == customerId) {
      setState(() {
        _refreshRequired = true;
        _error =
            'Обновите заметки перед следующими изменениями: ${error.message}';
      });
    }
  }

  Widget _card(CustomerNote note) => Container(
    key: ValueKey('customer-note-${note.id}'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.notActiveBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                note.authorName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            PopupMenuButton<_NoteAction>(
              tooltip: 'Действия с заметкой',
              enabled:
                  !_loading && !_dialogOpen && !_creating && !_refreshRequired,
              onSelected: (action) {
                if (action == _NoteAction.edit) {
                  _edit(note);
                } else {
                  _archive(note);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _NoteAction.edit,
                  child: Text('Редактировать'),
                ),
                PopupMenuItem(
                  value: _NoteAction.archive,
                  child: Text('Архивировать'),
                ),
              ],
            ),
          ],
        ),
        SelectableText(note.text),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              _date(note.createdAt),
              style: const TextStyle(color: AppColors.textMutted, fontSize: 12),
            ),
            if (note.editedAt != null)
              Text(
                'Изменено ${_date(note.editedAt!)}',
                style: const TextStyle(
                  color: AppColors.textMutted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.notActiveBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Visibility(
            visible: !_dialogOpen,
            maintainState: true,
            child: CustomerNoteEditor(
              key: ValueKey('note-composer-${widget.customerId}'),
              inline: true,
              enabled: !_loading,
              refreshRequired: _refreshRequired,
              onSavingChanged: (saving) {
                if (mounted) setState(() => _creating = saving);
              },
              onSave: (text) async {
                final customerId = widget.customerId;
                try {
                  return await widget.repository.createNote(
                    customerId,
                    CreateCustomerNoteRequest(text: text),
                  );
                } on CustomerRequestException catch (error) {
                  _requireRefresh(error, customerId);
                  rethrow;
                }
              },
              onSaved: (note) => _publish([
                note,
                ..._notes.where((item) => item.id != note.id),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading || _dialogOpen || _creating
                        ? null
                        : _reload,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _notes.isEmpty
                ? const Center(child: Text('Пока нет заметок'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _card(_notes[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
