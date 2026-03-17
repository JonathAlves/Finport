import 'dart:math';

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
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: DateTime.now().month - 1);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Finport',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemBuilder: (context, index) {
          final now = DateTime.now();
          final month = index + 1;
          return MonthPage(key: ValueKey(month), month: month, year: now.year);
        },
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
    required this.onEdit,
    required this.onDelete,
  });

  final Movement movement;
  final String currency;
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
            child: Icon(_iconForCategory(movement.category), color: const Color(0xFF2F6FB8)),
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
                  overflow: TextOverflow.ellipsis, // Adiciona "..." se for muito longo
                ),
                const SizedBox(height: 2),
                // FittedBox garante que o texto do valor diminua levemente se não couber
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$currency$installmentText',
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _chipColor(paid),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  paid ? 'PAGO' : 'PENDENTE',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                ),
              ),
              // Agrupando os botões para economizar espaço horizontal
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact, // Reduz o padding interno
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 20, color: Color(0xFF2F6FB8)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFD14B4B)),
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
  const MonthPage({super.key, required this.month, required this.year});

  final int month;
  final int year;

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  final _movementRepo = MovementRepository();
  final _installmentRepo = InstallmentPurchaseRepository();

  bool _loading = false;
  List<Movement> _movements = const [];
  List<InstallmentPurchase> _installments = const [];

  Movement? _editing;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _movementRepo.listAll(month: widget.month, year: widget.year),
        _installmentRepo.listActive(),
      ]);
      _movements = results[0] as List<Movement>;
      _installments = results[1] as List<InstallmentPurchase>;

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
      await _movementRepo.delete(m.id);
      if (_editing?.id == m.id) _resetForm();
      await _refresh();
      _snack('Movimento removido.');
    } catch (e) {
      _snack('Erro ao remover: $e');
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

    final isCurrentMonth =
        widget.month == DateTime.now().month &&
        widget.year == DateTime.now().year;

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
                if (isCurrentMonth)
                  MovementForm(
                    key: ValueKey(_editing),
                    installments: _installments,
                    movements: _movements,
                    editing: _editing,
                    onSave: _refresh,
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
        padding: const EdgeInsets.all(16),
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
              Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        SizedBox(
                          height: 200,
                          width: 200,
                          child: PieChart(
                            PieChartData(
                              sections: sections,
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: MovementCategory.values.map((c) {
                              final v = totals[c] ?? 0;
                              final pct = totalValue <= 0
                                  ? 0
                                  : (v / totalValue) * 100;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: colors[c],
                                        shape: BoxShape.rectangle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${c.label}  ${pct.toStringAsFixed(1)}%',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
    required this.installments,
    required this.movements,
    this.editing,
    required this.onSave,
  });

  final List<InstallmentPurchase> installments;
  final List<Movement> movements;
  final Movement? editing;
  final VoidCallback onSave;

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
  final _installmentSelectCtrl = TextEditingController();

  Fortnight _fortnight = Fortnight.first;
  late int _selectedMonth;
  bool _isPaid = false;
  MovementCategory _category = MovementCategory.food;
  bool _isInstallment = false;

  bool _creatingNewInstallment = false;
  InstallmentPurchase? _selectedInstallment;
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
  void dispose() {
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _installmentQtyCtrl.dispose();
    _installmentValueCtrl.dispose();
    _installmentSelectCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _descCtrl.clear();
    _valueCtrl.clear();
    _installmentQtyCtrl.clear();
    _installmentValueCtrl.clear();
    _installmentSelectCtrl.clear();
    _fortnight = Fortnight.first;
    _selectedMonth = DateTime.now().month;
    _isPaid = false;
    _category = MovementCategory.food;
    _isInstallment = false;
    _creatingNewInstallment = false;
    _selectedInstallment = null;

    setState(() {});
  }

  void _startEditing(Movement m) {
    _descCtrl.text = m.description;
    _valueCtrl.text = _formatValueForField(m.value);
    _fortnight = m.fortnight;
    _isPaid = m.isPaid;
    _category = m.category;
    _isInstallment = m.isInstallmentPurchase;
    _selectedMonth = m.month;

    _creatingNewInstallment = false;
    _selectedInstallment = null;
    _installmentSelectCtrl.clear();

    if (m.isInstallmentPurchase && m.installmentPurchaseId != null) {
      _selectedInstallment = widget.installments
          .where((p) => p.id == m.installmentPurchaseId)
          .cast<InstallmentPurchase?>()
          .firstOrNull;
      _installmentSelectCtrl.text = _selectedInstallment?.label ?? '';
    }

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
    if (!_isInstallment || !_creatingNewInstallment) return;
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
      String? installmentPurchaseId;
      int? currentInstallment;
      double? installmentValue;
      int? installmentQuantity;

      if (_isInstallment) {
        if (_creatingNewInstallment) {
          final qty = int.tryParse(_installmentQtyCtrl.text.trim());
          final unit = _parsePtBrNumber(_installmentValueCtrl.text);
          if (qty == null || qty <= 0 || unit == null || unit <= 0) {
            _snack('Preencha quantidade e valor da parcela.');
            return;
          }

          final now = DateTime.now();
          final created = await _installmentRepo.insert(
            InstallmentPurchase(
              id: 'tmp',
              description: _descCtrl.text.trim(),
              installmentQuantity: qty,
              installmentValue: unit,
              currentInstallment: 1,
              isActive: qty > 1,
              createdAt: now,
              month: _selectedMonth,
              year: now.year,
            ),
          );
          installmentPurchaseId = created.id;
          currentInstallment = 1;
          installmentValue = unit;
          installmentQuantity = qty;
        } else {
          final selected = _selectedInstallment;
          if (selected == null) {
            _snack('Selecione uma compra parcelada.');
            return;
          }

          final nextInstallment = min(
            selected.currentInstallment + 1,
            selected.installmentQuantity,
          );

          installmentPurchaseId = selected.id;
          currentInstallment = nextInstallment;
          installmentValue = selected.installmentValue;
          installmentQuantity = selected.installmentQuantity;
        }
      }

      if (widget.editing == null) {
        final now = DateTime.now();
        final inserted = await _movementRepo.insert(
          Movement(
            id: 'tmp',
            description: _descCtrl.text.trim(),
            value: value,
            fortnight: _fortnight,
            isPaid: _isPaid,
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

        if (_isInstallment &&
            !_creatingNewInstallment &&
            inserted.currentInstallment != null &&
            installmentPurchaseId != null) {
          await _installmentRepo.setCurrentInstallment(
            id: installmentPurchaseId,
            currentInstallment: inserted.currentInstallment!,
          );
        }
      } else {
        final patch = {
          'description': _descCtrl.text.trim(),
          'value': value,
          'fortnight': _fortnight.dbValue,
          'isPaid': _isPaid,
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

        if (_isInstallment &&
            installmentPurchaseId != null &&
            currentInstallment != null) {
          await _installmentRepo.setCurrentInstallment(
            id: installmentPurchaseId,
            currentInstallment: currentInstallment,
          );
        }
      }

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
    final currentMonth = DateTime.now().month;
    final installmentIdsWithMovementThisMonth = widget.movements
        .where(
          (m) =>
              m.isInstallmentPurchase &&
              m.month == currentMonth &&
              m.installmentPurchaseId != null,
        )
        .map((m) => m.installmentPurchaseId)
        .toSet();

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
              Row(
                children: [
                  Expanded(
                    child: _SwitchRow(
                      label: 'Já foi pago?',
                      value: _isPaid,
                      onChanged: (v) => setState(() => _isPaid = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SwitchRow(
                      label: 'É uma compra parcelada?',
                      value: _isInstallment,
                      onChanged: (v) {
                        setState(() {
                          _isInstallment = v;
                          if (!v) {
                            _creatingNewInstallment = false;
                            _selectedInstallment = null;
                            _installmentQtyCtrl.clear();
                            _installmentValueCtrl.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_isInstallment) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<InstallmentPurchase>(
                        controller: _installmentSelectCtrl,
                        enabled: !_creatingNewInstallment,
                        initialSelection: _creatingNewInstallment
                            ? null
                            : _selectedInstallment,
                        dropdownMenuEntries: widget.installments.map((p) {
                          final alreadyExists =
                              installmentIdsWithMovementThisMonth.contains(
                                p.id,
                              );
                          return DropdownMenuEntry<InstallmentPurchase>(
                            value: p,
                            label: alreadyExists
                                ? '${p.label} (já incluído)'
                                : p.label,
                            enabled: !alreadyExists,
                          );
                        }).toList(),
                        label: const Text('Compra parcelada (existente)'),
                        onSelected: (v) {
                          setState(() {
                            _selectedInstallment = v;
                            if (v != null) {
                              _descCtrl.text = v.description;
                              _category = MovementCategory.debits;
                              final total =
                                  v.installmentQuantity * v.installmentValue;
                              _valueCtrl.text = _formatValueForField(total);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _creatingNewInstallment = !_creatingNewInstallment;
                          if (_creatingNewInstallment) {
                            _selectedInstallment = null;
                            _installmentSelectCtrl.clear();
                          } else {
                            _installmentQtyCtrl.clear();
                            _installmentValueCtrl.clear();
                          }
                        });
                      },
                      icon: Icon(
                        _creatingNewInstallment ? Icons.close : Icons.add,
                      ),
                      label: Text(
                        _creatingNewInstallment ? 'Cancelar' : 'Nova',
                      ),
                    ),
                  ],
                ),
                if (!_creatingNewInstallment)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Builder(
                      builder: (context) {
                        if (_selectedInstallment != null) {
                          return const SizedBox.shrink();
                        }
                        return const Text(
                          'Selecione uma compra parcelada.',
                          style: TextStyle(color: Color(0xFFB42318)),
                        );
                      },
                    ),
                  ),
                if (_creatingNewInstallment) ...[
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
                            if (!_isInstallment || !_creatingNewInstallment) {
                              return null;
                            }
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
                            if (!_isInstallment || !_creatingNewInstallment) {
                              return null;
                            }
                            final unit = _parsePtBrNumber(v ?? '');
                            if (unit == null || unit <= 0) return 'Obrigatório';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
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
