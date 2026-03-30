import 'package:finport/features/installments/data/repositories/installment_purchase_repository.dart';
import 'package:finport/features/installments/domain/entities/installment_purchase.dart';
import 'package:finport/features/movements/data/repositories/movement_repository.dart';
import 'package:finport/features/movements/domain/entities/movement.dart';
import 'package:finport/features/movements/presentation/formatters/currency_input_formatter.dart';
import 'package:finport/features/movements/presentation/widgets/switch_row.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MovementForm extends StatefulWidget {
  const MovementForm({
    super.key,
    this.editing,
    required this.onSave,
    required this.onPersisted,
    required this.onCancelEdit,
  });

  final Movement? editing;
  final VoidCallback onSave;
  final VoidCallback onPersisted;
  final VoidCallback onCancelEdit;

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
    return double.parse(digits) / 100;
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
                      inputFormatters: [CurrencyInputFormatter()],
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
              SwitchRow(
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
                        inputFormatters: [CurrencyInputFormatter()],
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
                          widget.onCancelEdit();
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
