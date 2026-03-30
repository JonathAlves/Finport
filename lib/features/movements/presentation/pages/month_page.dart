import 'package:finport/features/movements/data/repositories/movement_repository.dart';
import 'package:finport/features/movements/domain/entities/movement.dart';
import 'package:finport/features/movements/presentation/extensions/iterable_extensions.dart';
import 'package:finport/features/movements/presentation/widgets/movement_form.dart';
import 'package:finport/features/movements/presentation/widgets/movement_tile.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
                    onCancelEdit: _resetForm,
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
                      return MovementTile(
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
