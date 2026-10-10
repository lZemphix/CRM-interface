// import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';

import 'customer_action_button.dart';

import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/models/customer_note.dart';
import 'package:crm_interface/modules/customers/models/create_customer.dart';
import 'package:intl/intl.dart';

import '../customer_identity.dart';
import 'tabs/activity_preview.dart';

import 'tabs/notes_tab.dart';
import 'tabs/activity_tab.dart';

import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/tabs/overview_tab.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/widgets/create_task.dart';
import 'package:crm_interface/modules/tasks/widgets/customer_tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/customer_next_task.dart';

class DetailPanel extends StatefulWidget {
  const DetailPanel({
    super.key,
    required this.customer,
    required this.apiClient,
  });

  final Customer customer;
  final ApiClient apiClient;

  @override
  State<StatefulWidget> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<DetailPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _tabRefresh = List.generate(4, (_) => SectionRefreshController());
  bool _refreshingCustomer = false;
  bool get _busy =>
      _openingTask ||
      _refreshingCustomer ||
      _tabRefresh.any((controller) => controller.isBusy);
  late Future<CustomerDetails> customerDetailsFuture;
  late final CustomersRepository repository;
  late final TasksRepository _tasksRepository;
  late Future<List<CustomerFormOption>> _branchesFuture;
  bool _openingTask = false;
  int _taskReloadToken = 0;
  int _overviewReloadToken = 0;
  int _activityReloadToken = 0;
  List<CustomerNote>? _notes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabRefresh[0].attach(
      this,
      refresh: _reloadCustomerData,
      busy: () => _openingTask,
    );

    repository = CustomersRepository(widget.apiClient);
    _tasksRepository = TasksRepository(widget.apiClient);
    _branchesFuture = repository.getBranches();
    _branchesFuture.ignore();

    customerDetailsFuture = repository.getCustomerDetails(
      id: widget.customer.id,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _tabRefresh) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _reloadCustomerData() async {
    final customerId = widget.customer.id;
    final details = repository.getCustomerDetails(id: widget.customer.id);
    final branches = repository.getBranches();
    branches.ignore();
    final fresh = await details;
    if (!mounted || widget.customer.id != customerId) return;
    setState(() {
      customerDetailsFuture = Future.value(fresh);
      _branchesFuture = branches;
      _notes = fresh.notes;
    });
    // Branch failures remain a local ID fallback, not a failed customer refresh.
    try {
      await branches;
    } on CustomerRequestException {
      return;
    }
  }

  Future<void> _refreshSelectedTab() async {
    if (_busy || _tabController.index >= _tabRefresh.length) return;
    try {
      await _tabRefresh[_tabController.index].refresh();
    } on CustomerRequestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _refreshCustomer() async {
    if (_busy) return;
    final customerId = widget.customer.id;
    setState(() => _refreshingCustomer = true);
    try {
      await _tabRefresh[0].refresh();
      if (!mounted || widget.customer.id != customerId) return;
      await Future.wait(
        _tabRefresh.skip(1).map((controller) => controller.refresh()),
      );
    } on CustomerRequestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _refreshingCustomer = false);
    }
  }

  Future<void> _createCustomerTask() async {
    if (_openingTask) return;
    setState(() => _openingTask = true);
    // Сохраняем клиентскую привязку на момент открытия формы.
    final customer = TaskCustomerOption(
      id: widget.customer.id,
      fullName: widget.customer.fullName,
    );
    try {
      final columns = await _tasksRepository.getColumns();
      if (!mounted) return;
      if (!columns.any((column) => column.canCreateTask)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет доступной колонки для создания задачи'),
          ),
        );
        return;
      }
      final employees = await _tasksRepository.getEmployees();
      if (!mounted) return;
      var created = false;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CreateTaskWindow(
          columns: columns,
          employees: employees,
          initialCustomer: customer,
          lockCustomer: true,
          onCreate: (request) async {
            await _tasksRepository.createTask(request);
            created = true;
          },
        ),
      );
      if (mounted && created && widget.customer.id == customer.id) {
        setState(() {
          _taskReloadToken++;
          _overviewReloadToken++;
          _activityReloadToken++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задача создана и связана с клиентом')),
        );
      }
    } on TaskRequestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить параметры задачи'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingTask = false);
    }
  }

  @override
  void didUpdateWidget(covariant DetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.customer.id != widget.customer.id) {
      _notes = null;
      customerDetailsFuture = repository.getCustomerDetails(
        id: widget.customer.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: customerDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data?.id != widget.customer.id) {
          return Center(child: Text("Загрузка данных..."));
        }

        final customer = snapshot.data;

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось получить карточку клиента'),
                TextButton(
                  onPressed: _refreshCustomer,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        if (customer == null) {
          return const Center(child: Text("Данные клиента не получены."));
        }

        return FutureBuilder<List<CustomerFormOption>>(
          future: _branchesFuture,
          builder: (_, branches) {
            final branchId = customer.homeBranchId;
            final branchName = branches.data
                ?.where((branch) => branch.id == branchId)
                .firstOrNull
                ?.name;
            final branchLabel = branchId == null
                ? 'Не выбран'
                : branchName ??
                      'Филиал #$branchId${branches.connectionState == ConnectionState.waiting ? '' : ' (название недоступно)'}';
            return customerDetailsCard(customer, branchLabel);
          },
        );
      },
    );
  }

  Widget tabBars() {
    return AnimatedBuilder(
      animation: Listenable.merge([_tabController, ..._tabRefresh]),
      builder: (_, _) => Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: EdgeInsets.all(10),
              unselectedLabelColor: AppColors.textMutted,
              labelColor: AppColors.activeElement,
              indicatorColor: AppColors.activeElement,
              dividerColor: AppColors.notActiveBorder,
              tabs: [
                Text('Обзор'),
                Text('Активность'),
                Text('Заметки'),
                Text('Задачи'),
                Text('История посещений'),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Обновить вкладку',
            onPressed:
                _busy ||
                    _tabController.index >= _tabRefresh.length ||
                    !_tabRefresh[_tabController.index].canRefresh
                ? null
                : _refreshSelectedTab,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
    );
  }

  Widget tabs(CustomerDetails customer, String branchLabel) {
    return Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          overviewTab(
            customer,
            branchLabel: branchLabel,
            recentActivity: CustomerActivityPreview(
              key: ValueKey('activity-preview-${customer.id}'),
              customerId: customer.id,
              repository: repository,
              reloadToken: _activityReloadToken,
              refreshController: _tabRefresh[0],
            ),
            nextTask: CustomerNextTask(
              key: ValueKey(customer.id),
              customerId: customer.id,
              repository: _tasksRepository,
              reloadToken: _overviewReloadToken,
              refreshController: _tabRefresh[0],
              onChanged: () => setState(() {
                _taskReloadToken++;
                _activityReloadToken++;
              }),
            ),
          ),
          CustomerActivityPanel(
            key: ValueKey(customer.id),
            customerId: customer.id,
            repository: repository,
            reloadToken: _activityReloadToken,
            refreshController: _tabRefresh[1],
          ),
          CustomerNotesPanel(
            key: ValueKey(customer.id),
            customerId: customer.id,
            initialNotes: _notes ?? customer.notes,
            repository: repository,
            refreshController: _tabRefresh[2],
            onReloaded: (notes) {
              if (mounted && widget.customer.id == customer.id) {
                setState(() => _notes = notes);
              }
            },
            onChanged: (notes) {
              if (mounted && widget.customer.id == customer.id) {
                setState(() {
                  _notes = notes;
                  _activityReloadToken++;
                });
              }
            },
          ),
          CustomerTasksPanel(
            key: ValueKey(customer.id),
            customerId: customer.id,
            repository: _tasksRepository,
            reloadToken: _taskReloadToken,
            refreshController: _tabRefresh[3],
            onChanged: () => setState(() {
              _overviewReloadToken++;
              _activityReloadToken++;
            }),
          ),
          const Center(
            child: Text(
              'История посещений ещё не подключена: API посещений пока нет.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget customerDetailsCard(CustomerDetails customer, String branchLabel) {
    return Container(
      decoration: BoxDecoration(color: AppColors.background),
      padding: EdgeInsets.all(30),
      child: Column(
        spacing: 20,
        children: [
          detailTopbar(customer, branchLabel),
          actionsCustomer(customer),
          tabBars(),
          tabs(customer, branchLabel),
        ],
      ),
    );
  }

  Widget actionsCustomer(CustomerDetails customer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.notActiveBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: actionBlock(
              'В системе с',
              DateFormat('dd.MM.yyyy').format(customer.createdAt.toLocal()),
              false,
              false,
            ),
          ),
          Expanded(
            child: actionBlock(
              'Карточка обновлена',
              DateFormat('dd.MM.yyyy HH:mm')
                  .format(customer.updatedAt.toLocal()),
              true,
              false,
            ),
          ),
          Expanded(
            child: actionBlock(
              "Ответственный",
              customerResponsibleLabel(customer),
              true,
              false,
            ),
          ),
        ],
      ),
    );
  }

  Widget actionBlock(
    String title,
    String description,
    bool leftBorder,
    bool rightBorder,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 13),
      decoration: BoxDecoration(
        border: Border(
          right: rightBorder == true
              ? BorderSide(color: AppColors.notActiveBorder)
              : BorderSide.none,
          left: leftBorder == true
              ? BorderSide(color: AppColors.notActiveBorder)
              : BorderSide.none,
        ),
      ),
      child: Column(
        spacing: 5,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: AppColors.textMutted, fontSize: 11),
          ),
          Text(
            description,
            style: TextStyle(fontWeight: FontWeight(500), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget detailTopbar(CustomerDetails customer, String branchLabel) {
    String phoneNumber = getPrimaryContact(customer.contacts);
    String finalLetters = customerNameIcon(customer.fullName);

    Container icon = Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 212, 215, 238),
            const Color.fromARGB(255, 238, 235, 255),
          ],
          begin: AlignmentGeometry.bottomEnd,
          end: AlignmentGeometry.topStart,
        ),
      ),
      child: Center(
        child: Text(
          finalLetters,
          style: TextStyle(
            color: AppColors.activeElement,
            fontWeight: FontWeight(700),
            fontSize: 16,
          ),
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.notActiveBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = customerSummary(
            icon,
            customer,
            phoneNumber,
            customer.homeBranchId == null ? null : branchLabel,
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 14), quickActions()],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 16),
              quickActions(),
            ],
          );
        },
      ),
    );
  }

  Widget quickActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CustomerActionButton(
          label: 'Позвонить',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Звонки пока не подключены')),
          ),
        ),
        CustomerActionButton(
          label: '+ Задача',
          primary: true,
          onPressed: _openingTask ? null : _createCustomerTask,
        ),
        AnimatedBuilder(
          animation: Listenable.merge(_tabRefresh),
          builder: (_, _) => IconButton(
            tooltip: 'Обновить карточку клиента',
            onPressed: _busy ? null : _refreshCustomer,
            icon: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  Widget customerSummary(
    Container icon,
    CustomerDetails customer,
    String contact,
    String? branch,
  ) {
    return Row(
      spacing: 15,
      children: [
        icon,
        Expanded(
          child: Column(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight(700)),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: customer.status == 'active'
                        ? const Color.fromARGB(255, 81, 213, 85)
                        : const Color.fromARGB(255, 169, 48, 48),
                  ),
                  Text(
                    customer.status == 'active'
                        ? 'Активный клиент'
                        : 'Неактивный клиент',
                    style: TextStyle(color: AppColors.textMutted),
                  ),
                  Text(contact, style: TextStyle(color: AppColors.textMutted)),
                  if (branch != null)
                    Text(branch, style: TextStyle(color: AppColors.textMutted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
