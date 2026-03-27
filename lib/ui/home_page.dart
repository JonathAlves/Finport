import 'dart:async';

import 'package:finport/data/installment_purchase_repository.dart';
import 'package:finport/data/movement_repository.dart';
import 'package:finport/models/installment_purchase.dart';
import 'package:finport/models/movement.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _movementRepo = MovementRepository();
  late final PageController _pageCtrl;
  Timer? _monthWatcher;
  DateTime _lastObservedNow = DateTime.now();
  List<DateTime> _visibleMonths = const [];
  bool _loadingMonths = true;
  int _currentPageIndex = 0;

  bool get _isOnCurrentMonth {
    if (_visibleMonths.isEmpty) return true;
    if (_currentPageIndex < 0 || _currentPageIndex >= _visibleMonths.length) {
      return true;
    }

    final now = DateTime.now();
    final visible = _visibleMonths[_currentPageIndex];
    return visible.month == now.month && visible.year == now.year;
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    final currentIndex = _visibleMonths.indexWhere(
      (d) => d.month == now.month && d.year == now.year,
    );

    if (currentIndex < 0 || !_pageCtrl.hasClients) {
      _loadVisibleMonths(jumpToCurrentMonth: true);
      return;
    }

    _pageCtrl.animateToPage(
      currentIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    _loadVisibleMonths(jumpToCurrentMonth: true);
    _monthWatcher = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final changedMonth =
          now.month != _lastObservedNow.month ||
          now.year != _lastObservedNow.year;
      if (changedMonth) {
        _lastObservedNow = now;
        _loadVisibleMonths(jumpToCurrentMonth: true);
      }
    });
  }

  @override
  void dispose() {
    _monthWatcher?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVisibleMonths({bool jumpToCurrentMonth = false}) async {
    final previouslyVisibleMonth =
        _visibleMonths.isNotEmpty &&
            _currentPageIndex >= 0 &&
            _currentPageIndex < _visibleMonths.length
        ? _visibleMonths[_currentPageIndex]
        : null;

    setState(() => _loadingMonths = true);
    try {
      final now = DateTime.now();
      final all = await _movementRepo.listAll();
      final installments = all.where((m) => m.isInstallmentPurchase);

      final hasFutureYearInstallment = installments.any(
        (m) => m.year > now.year,
      );
      final latestInstallment = installments.fold<Movement?>(null, (latest, m) {
        if (latest == null) return m;
        final latestKey = latest.year * 100 + latest.month;
        final currentKey = m.year * 100 + m.month;
        return currentKey > latestKey ? m : latest;
      });

      final endYear = hasFutureYearInstallment
          ? (latestInstallment?.year ?? now.year)
          : now.year;
      final endMonth = hasFutureYearInstallment
          ? (latestInstallment?.month ?? 12)
          : 12;

      final generated = <DateTime>[];
      var cursor = DateTime(now.year, 1);
      final endDate = DateTime(endYear, endMonth);
      while (!cursor.isAfter(endDate)) {
        generated.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1);
      }

      if (!mounted) return;
      setState(() {
        _visibleMonths = generated;
      });

      if (_visibleMonths.isNotEmpty) {
        int safeIndex;
        if (jumpToCurrentMonth) {
          final currentIndex = _visibleMonths.indexWhere(
            (d) => d.month == now.month && d.year == now.year,
          );
          safeIndex = currentIndex >= 0 ? currentIndex : 0;
        } else if (previouslyVisibleMonth != null) {
          final previousIndex = _visibleMonths.indexWhere(
            (d) =>
                d.month == previouslyVisibleMonth.month &&
                d.year == previouslyVisibleMonth.year,
          );
          safeIndex = previousIndex >= 0
              ? previousIndex
              : _currentPageIndex.clamp(0, _visibleMonths.length - 1);
        } else {
          safeIndex = _currentPageIndex.clamp(0, _visibleMonths.length - 1);
        }

        if (mounted) {
          setState(() => _currentPageIndex = safeIndex);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageCtrl.hasClients) return;
          _pageCtrl.jumpToPage(safeIndex);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMonths = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Finport',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingMonths
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (index) {
                setState(() => _currentPageIndex = index);
              },
              itemCount: _visibleMonths.length,
              itemBuilder: (context, index) {
                final date = _visibleMonths[index];
                return MonthPage(
                  key: ValueKey('${date.year}-${date.month}'),
                  month: date.month,
                  year: date.year,
                  forceShowForm:
                      date.month == now.month && date.year == now.year,
                  onCreated: () => _loadVisibleMonths(jumpToCurrentMonth: true),
                  onDataChanged: () => _loadVisibleMonths(),
                );
              },
            ),
      bottomNavigationBar: _isOnCurrentMonth
          ? null
          : BottomAppBar(
              child: SizedBox(
                height: 60,
                child: InkWell(
                  onTap: _goToCurrentMonth,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home),
                      SizedBox(height: 2),
                      Text('Home'),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.movement,
    required this.currency,
    required this.onTogglePaid,
    required this.onEdit,
    required this.onDelete,
  });

  final Movement movement;
  final String currency;
  final ValueChanged<bool> onTogglePaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData _iconForCategory(MovementCategory c) => switch (c) {
    MovementCategory.food => Icons.restaurant,
    MovementCategory.house => Icons.home,
    MovementCategory.debits => Icons.credit_card,
    MovementCategory.entertainment => Icons.movie,
    MovementCategory.health => Icons.health_and_safety,
    MovementCategory.study => Icons.school,
    MovementCategory.bills => Icons.credit_card,
    MovementCategory.other => Icons.category,
  };

  Color _chipColor(bool paid) =>
      paid ? const Color(0xFF34B27B) : const Color(0xFF9AA3AF);

  @override
  Widget build(BuildContext context) {
    final paid = movement.isPaid;
    final hasInstallment = movement.isInstallmentPurchase;
    final qty = movement.installmentQuantity ?? 0;
    final cur = movement.currentInstallment ?? 0;
    final installmentText = hasInstallment && qty > 0 && cur > 0
        ? ' • $cur/$qty'
        : '';

    return Material(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE9F1FF),
              child: Icon(
                _iconForCategory(movement.category),
                color: const Color(0xFF2F6FB8),
              ),
            ),
            const SizedBox(width: 10),
            // Usamos Expanded para que a coluna ocupe o espaço restante
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.description,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1, // Evita quebra de linha na descrição
                    overflow: TextOverflow
                        .ellipsis, // Adiciona "..." se for muito longo
                  ),
                  const SizedBox(height: 2),
                  // FittedBox garante que o texto do valor diminua levemente se não couber
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$currency$installmentText',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Envolvemos o Status para ele não "esticar"
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _chipColor(paid),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        paid ? 'PAGO' : 'PENDENTE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: paid,
                        onChanged: onTogglePaid,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                // Agrupando os botões para economizar espaço horizontal
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity:
                          VisualDensity.compact, // Reduz o padding interno
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Color(0xFF2F6FB8),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Color(0xFFD14B4B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final value = double.parse(digits) / 100;
    final text = value.toStringAsFixed(2).replaceAll('.', ',');

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class MonthPage extends StatefulWidget {
  const MonthPage({
    super.key,
    required this.month,
    required this.year,
    required this.forceShowForm,
    required this.onCreated,
    required this.onDataChanged,
  });

  final int month;
  final int year;
  final bool forceShowForm;
  final VoidCallback onCreated;
  final VoidCallback onDataChanged;

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  final _movementRepo = MovementRepository();

  bool _loading = false;
  List<Movement> _movements = const [];

  Movement? _editing;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _movements = await _movementRepo.listAll(
        month: widget.month,
        year: widget.year,
      );

      if (_editing != null) {
        _editing = _movements
            .where((m) => m.id == _editing!.id)
            .cast<Movement?>()
            .firstOrNull;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _editing = null;
    });
  }

  void _startEditing(Movement m) {
    setState(() {
      _editing = m;
    });
  }

  String _formatCurrency(double value) {
    final f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return f.format(value);
  }

  double _valueForTotals(Movement m) {
    if (m.isInstallmentPurchase) {
      return m.installmentValue ?? 0;
    }
    return m.value;
  }

  Future<void> _deleteMovement(Movement m) async {
    setState(() => _loading = true);
    try {
      if (m.isInstallmentPurchase &&
          m.installmentPurchaseId != null &&
          m.currentInstallment != null) {
        await _movementRepo.deleteInstallmentsFrom(
          installmentPurchaseId: m.installmentPurchaseId!,
          fromInstallment: m.currentInstallment!,
        );
      } else {
        await _movementRepo.delete(m.id);
      }

      if (_editing?.id == m.id) _resetForm();
      await _refresh();
      widget.onDataChanged();
      _snack('Movimento removido.');
    } catch (e) {
      _snack('Erro ao remover: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePaid(Movement m, bool paid) async {
    setState(() => _loading = true);
    try {
      await _movementRepo.update(m.id, {'isPaid': paid});
      await _refresh();
      _snack('Status atualizado.');
    } catch (e) {
      _snack('Erro ao atualizar pagamento: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final first = _movements
        .where((m) => m.fortnight == Fortnight.first)
        .toList();
    final second = _movements
        .where((m) => m.fortnight == Fortnight.second)
        .toList();

    final monthTotal = _movements.fold<double>(
      0,
      (sum, m) => sum + _valueForTotals(m),
    );
    final monthDate = DateTime(widget.year, widget.month);
    final monthLabel = DateFormat.MMMM('pt_BR').format(monthDate);

    final showForm = widget.forceShowForm || _editing != null;

    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  monthLabel[0].toUpperCase() + monthLabel.substring(1),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (showForm)
                  MovementForm(
                    key: ValueKey(_editing),
                    editing: _editing,
                    onSave: _refresh,
                    onPersisted: widget.onCreated,
                  ),
                const SizedBox(height: 12),
                _buildFortnightCard(
                  title: '1ª Quinzena',
                  headerColor: const Color(0xFFBFD7F3),
                  movements: first,
                ),
                const SizedBox(height: 12),
                _buildFortnightCard(
                  title: '2ª Quinzena',
                  headerColor: const Color(0xFFBFE6D2),
                  movements: second,
                ),
                const SizedBox(height: 16),
                _buildPieCard(),
                const SizedBox(height: 12),
                _buildMonthTotalCard(monthTotal),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withAlpha(15),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFortnightCard({
    required String title,
    required Color headerColor,
    required List<Movement> movements,
  }) {
    final total = movements.fold<double>(
      0,
      (sum, m) => sum + _valueForTotals(m),
    );
    return Card(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (movements.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhum movimento nesta quinzena.'),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: ${_formatCurrency(total)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movements.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final m = movements[i];
                      return _MovementTile(
                        movement: m,
                        currency: _formatCurrency(
                          m.isInstallmentPurchase
                              ? m.installmentValue ?? m.value
                              : m.value,
                        ),
                        onTogglePaid: (paid) => _togglePaid(m, paid),
                        onEdit: () => _startEditing(m),
                        onDelete: () => _deleteMovement(m),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPieCard() {
    final totals = <MovementCategory, double>{
      for (final c in MovementCategory.values) c: 0,
    };
    for (final m in _movements) {
      totals[m.category] = (totals[m.category] ?? 0) + _valueForTotals(m);
    }

    final totalValue = totals.values.fold<double>(0, (a, b) => a + b);
    final colors = <MovementCategory, Color>{
      MovementCategory.food: const Color(0xFF2F6FB8),
      MovementCategory.house: const Color(0xFF5AA8FF),
      MovementCategory.debits: const Color(0xFF47C19E),
      MovementCategory.entertainment: const Color(0xFFF2A64D),
      MovementCategory.health: const Color(0xFF9B5DE5),
      MovementCategory.study: const Color(0xFF00BBF9),
      MovementCategory.bills: const Color(0xFFF15BB5),
      MovementCategory.other: const Color(0xFFB07AD9),
    };

    final sections = MovementCategory.values
        .where((c) => (totals[c] ?? 0) > 0)
        .map(
          (c) => PieChartSectionData(
            value: totals[c],
            color: colors[c],
            title: '',
            radius: 55,
          ),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo de Gastos por Categoria',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (totalValue <= 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Sem dados para gerar o gráfico.'),
              )
            else
              SizedBox(
                height: 240,
                child: Row(
                  children: [
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 28,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: MovementCategory.values.map((c) {
                            final v = totals[c] ?? 0;
                            final pct = totalValue <= 0
                                ? 0
                                : (v / totalValue) * 100;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: colors[c],
                                      shape: BoxShape.rectangle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${c.label}  ${pct.toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthTotalCard(double monthTotal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.summarize, color: Color(0xFF2F6FB8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total do mês',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(monthTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant MonthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month || oldWidget.year != widget.year) {
      _refresh();
    }
  }
}

class MovementForm extends StatefulWidget {
  const MovementForm({
    super.key,
    this.editing,
    required this.onSave,
    required this.onPersisted,
  });

  final Movement? editing;
  final VoidCallback onSave;
  final VoidCallback onPersisted;

  @override
  State<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<MovementForm> {
  final _movementRepo = MovementRepository();
  final _installmentRepo = InstallmentPurchaseRepository();

  final _formKey = GlobalKey<FormState>();

  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _installmentQtyCtrl = TextEditingController();
  final _installmentValueCtrl = TextEditingController();

  Fortnight _fortnight = Fortnight.first;
  late int _selectedMonth;
  MovementCategory _category = MovementCategory.food;
  bool _isInstallment = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _startEditing(widget.editing!);
    } else {
      _selectedMonth = DateTime.now().month;
    }
    _installmentQtyCtrl.addListener(_maybeRecalcTotalFromInstallment);
    _installmentValueCtrl.addListener(_maybeRecalcTotalFromInstallment);
  }

  @override
  void didUpdateWidget(covariant MovementForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editing?.id != widget.editing?.id) {
      if (widget.editing != null) {
        _startEditing(widget.editing!);
      } else {
        _resetForm();
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _installmentQtyCtrl.dispose();
    _installmentValueCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _descCtrl.clear();
    _valueCtrl.clear();
    _installmentQtyCtrl.clear();
    _installmentValueCtrl.clear();
    _fortnight = Fortnight.first;
    _selectedMonth = DateTime.now().month;
    _category = MovementCategory.food;
    _isInstallment = false;

    setState(() {});
  }

  void _startEditing(Movement m) {
    _descCtrl.text = m.description;
    _valueCtrl.text = _formatValueForField(m.value);
    _fortnight = m.fortnight;
    _category = m.category;
    _isInstallment = m.isInstallmentPurchase;
    _selectedMonth = m.month;

    final qty = m.installmentQuantity ?? 0;
    final unit = m.installmentValue ?? 0;
    _installmentQtyCtrl.text = qty > 0 ? '$qty' : '';
    _installmentValueCtrl.text = unit > 0 ? _formatValueForField(unit) : '';
    setState(() {});
  }

  String _formatValueForField(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  double? _parsePtBrNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final value = double.parse(digits) / 100;
    return value;
  }

  void _maybeRecalcTotalFromInstallment() {
    if (!_isInstallment) return;
    final qty = int.tryParse(_installmentQtyCtrl.text.trim());
    final unit = _parsePtBrNumber(_installmentValueCtrl.text);
    if (qty == null || qty <= 0 || unit == null || unit <= 0) return;
    final total = qty * unit;
    _valueCtrl.text = _formatValueForField(total);
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final value = _parsePtBrNumber(_valueCtrl.text) ?? 0;
    if (value <= 0) {
      _snack('Informe um valor maior que zero.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.editing == null && _isInstallment) {
        final qty = int.tryParse(_installmentQtyCtrl.text.trim());
        final unit = _parsePtBrNumber(_installmentValueCtrl.text);
        if (qty == null || qty <= 0 || unit == null || unit <= 0) {
          _snack('Preencha quantidade e valor da parcela.');
          return;
        }

        final now = DateTime.now();
        final startDate = DateTime(now.year, _selectedMonth);
        final created = await _installmentRepo.insert(
          InstallmentPurchase(
            id: 'tmp',
            description: _descCtrl.text.trim(),
            installmentQuantity: qty,
            installmentValue: unit,
            currentInstallment: qty,
            isActive: false,
            createdAt: now,
            month: startDate.month,
            year: startDate.year,
          ),
        );

        for (var i = 0; i < qty; i++) {
          final installmentDate = DateTime(startDate.year, startDate.month + i);
          await _movementRepo.insert(
            Movement(
              id: 'tmp',
              description: _descCtrl.text.trim(),
              value: value,
              fortnight: _fortnight,
              isPaid: false,
              category: _category,
              isInstallmentPurchase: true,
              currentInstallment: i + 1,
              installmentValue: unit,
              installmentQuantity: qty,
              installmentPurchaseId: created.id,
              createdAt: now,
              month: installmentDate.month,
              year: installmentDate.year,
            ),
          );
        }

        widget.onPersisted();
        _resetForm();
        widget.onSave();
        _snack('Movimentos parcelados criados com sucesso.');
        return;
      }

      String? installmentPurchaseId;
      int? currentInstallment;
      double? installmentValue;
      int? installmentQuantity;

      if (_isInstallment) {
        final qty = int.tryParse(_installmentQtyCtrl.text.trim());
        final unit = _parsePtBrNumber(_installmentValueCtrl.text);
        if (qty == null || qty <= 0 || unit == null || unit <= 0) {
          _snack('Preencha quantidade e valor da parcela.');
          return;
        }

        installmentPurchaseId = widget.editing?.installmentPurchaseId;
        currentInstallment = widget.editing?.currentInstallment ?? 1;
        installmentValue = unit;
        installmentQuantity = qty;
      }

      if (widget.editing == null) {
        final now = DateTime.now();
        await _movementRepo.insert(
          Movement(
            id: 'tmp',
            description: _descCtrl.text.trim(),
            value: value,
            fortnight: _fortnight,
            isPaid: false,
            category: _category,
            isInstallmentPurchase: _isInstallment,
            currentInstallment: currentInstallment,
            installmentValue: installmentValue,
            installmentQuantity: installmentQuantity,
            installmentPurchaseId: installmentPurchaseId,
            createdAt: now,
            month: _selectedMonth,
            year: now.year,
          ),
        );
      } else {
        final editing = widget.editing!;

        if (editing.isInstallmentPurchase &&
            editing.installmentPurchaseId != null &&
            _isInstallment) {
          final seriesPatch = {
            'description': _descCtrl.text.trim(),
            'value': value,
            'fortnight': _fortnight.dbValue,
            'category': _category.dbValue,
            'isInstallmentPurchase': true,
            'installmentValue': installmentValue,
            'installmentQuantity': installmentQuantity,
          };

          await _movementRepo.updateInstallmentSeries(
            editing.installmentPurchaseId!,
            seriesPatch,
          );

          await _installmentRepo.update(editing.installmentPurchaseId!, {
            'description': _descCtrl.text.trim(),
            'installmentQuantity': installmentQuantity,
            'installmentValue': installmentValue,
          });
        } else {
        final patch = {
          'description': _descCtrl.text.trim(),
          'value': value,
          'fortnight': _fortnight.dbValue,
          'isPaid': widget.editing?.isPaid ?? false,
          'category': _category.dbValue,
          'isInstallmentPurchase': _isInstallment,
          'currentInstallment': currentInstallment,
          'installmentValue': installmentValue,
          'installmentQuantity': installmentQuantity,
          'installmentPurchaseId': installmentPurchaseId,
          'month': _selectedMonth,
          'year': widget.editing!.year,
        };

        await _movementRepo.update(widget.editing!.id, patch);
        }
      }

      widget.onPersisted();
      _resetForm();
      widget.onSave();
      _snack('Movimento salvo com sucesso.');
    } catch (e) {
      _snack('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.editing == null
                    ? 'Adicionar Novo Movimento'
                    : 'Editando Movimento',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Ex: Supermercado',
                      ),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return 'Obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Valor (R\$)',
                        hintText: '0,00',
                      ),
                      validator: (v) {
                        final parsed = _parsePtBrNumber(v ?? '');
                        if (parsed == null || parsed <= 0) return 'Obrigatório';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownMenu<Fortnight>(
                      initialSelection: _fortnight,
                      dropdownMenuEntries: Fortnight.values
                          .map(
                            (f) => DropdownMenuEntry<Fortnight>(
                              value: f,
                              label: f.label,
                            ),
                          )
                          .toList(),
                      label: const Text('Quinzena'),
                      onSelected: (v) => setState(() => _fortnight = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownMenu<MovementCategory>(
                      initialSelection: _category,
                      dropdownMenuEntries: MovementCategory.values
                          .map(
                            (c) => DropdownMenuEntry<MovementCategory>(
                              value: c,
                              label: c.label,
                            ),
                          )
                          .toList(),
                      label: const Text('Categoria'),
                      onSelected: (v) => setState(() => _category = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownMenu<int>(
                initialSelection: _selectedMonth,
                label: const Text('Mês'),
                dropdownMenuEntries: List.generate(12, (i) {
                  final month = i + 1;
                  final date = DateTime(DateTime.now().year, month);
                  final name = DateFormat.MMMM('pt_BR').format(date);
                  return DropdownMenuEntry(
                    value: month,
                    label: '${name[0].toUpperCase()}${name.substring(1)}',
                  );
                }),
                onSelected: (m) {
                  if (m != null) setState(() => _selectedMonth = m);
                },
              ),
              const SizedBox(height: 12),
              _SwitchRow(
                label: 'É uma compra parcelada?',
                value: _isInstallment,
                onChanged: (v) {
                  setState(() {
                    _isInstallment = v;
                    if (!v) {
                      _installmentQtyCtrl.clear();
                      _installmentValueCtrl.clear();
                    }
                  });
                },
              ),
              if (_isInstallment) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _installmentQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantidade de parcelas',
                          hintText: 'Ex: 12',
                        ),
                        validator: (v) {
                          if (!_isInstallment) return null;
                          final qty = int.tryParse((v ?? '').trim());
                          if (qty == null || qty <= 0) return 'Obrigatório';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _installmentValueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_CurrencyInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Valor da parcela',
                          hintText: 'Ex: 89,90',
                        ),
                        validator: (v) {
                          if (!_isInstallment) return null;
                          final unit = _parsePtBrNumber(v ?? '');
                          if (unit == null || unit <= 0) return 'Obrigatório';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: Icon(widget.editing == null ? Icons.add : Icons.save),
                label: Text(
                  widget.editing == null
                      ? 'Criar Movimento'
                      : 'Atualizar Movimento',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (widget.editing != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _resetForm();
                          (context as Element)
                              .findAncestorStateOfType<_MonthPageState>()
                              ?._resetForm();
                        },
                  child: const Text('Cancelar edição'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
