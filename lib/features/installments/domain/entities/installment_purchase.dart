class InstallmentPurchase {
  const InstallmentPurchase({
    required this.id,
    required this.description,
    required this.installmentQuantity,
    required this.installmentValue,
    required this.currentInstallment,
    required this.isActive,
    required this.createdAt,
    required this.month,
    required this.year,
  });

  final String id;
  final String description;
  final int installmentQuantity;
  final double installmentValue;
  final int currentInstallment;
  final bool isActive;
  final DateTime createdAt;
  final int month;
  final int year;

  int get remaining =>
      (installmentQuantity - currentInstallment).clamp(0, 1 << 30);

  String get label {
    final total = installmentQuantity;
    final atual = currentInstallment;
    final falta = remaining;
    return '$description • $atual/$total • faltam $falta';
  }

  static InstallmentPurchase fromMap(Map<String, dynamic> map) {
    return InstallmentPurchase(
      id: (map['id'] as String).toString(),
      description: (map['description'] as String? ?? '').toString(),
      installmentQuantity: (map['installmentQuantity'] as num? ?? 0).toInt(),
      installmentValue: (map['installmentValue'] as num? ?? 0).toDouble(),
      currentInstallment: (map['currentInstallment'] as num? ?? 0).toInt(),
      isActive: (map['isActive'] as bool? ?? true),
      createdAt:
          DateTime.tryParse((map['createdAt'] as String? ?? '')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      month: (map['month'] as num? ?? DateTime.now().month).toInt(),
      year: (map['year'] as num? ?? DateTime.now().year).toInt(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'description': description,
    'installmentQuantity': installmentQuantity,
    'installmentValue': installmentValue,
    'currentInstallment': currentInstallment,
    'isActive': isActive,
    'month': month,
    'year': year,
  };
}
