import 'package:finport/features/movements/domain/entities/movement.dart';
import 'package:flutter/material.dart';

class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.description,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
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
