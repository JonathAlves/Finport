enum Fortnight { first, second }

enum MovementCategory { food, house, debits, entertainment, other }

extension FortnightPtBr on Fortnight {
  String get label => switch (this) {
        Fortnight.first => '1ª Quinzena',
        Fortnight.second => '2ª Quinzena',
      };

  String get dbValue => switch (this) {
        Fortnight.first => 'first',
        Fortnight.second => 'second',
      };

  static Fortnight fromDb(String value) => switch (value) {
        'first' => Fortnight.first,
        'second' => Fortnight.second,
        _ => Fortnight.first,
      };
}

extension MovementCategoryPtBr on MovementCategory {
  String get label => switch (this) {
        MovementCategory.food => 'Alimentação',
        MovementCategory.house => 'Moradia',
        MovementCategory.debits => 'Dívidas',
        MovementCategory.entertainment => 'Lazer',
        MovementCategory.other => 'Outros',
      };

  String get dbValue => switch (this) {
        MovementCategory.food => 'food',
        MovementCategory.house => 'house',
        MovementCategory.debits => 'debits',
        MovementCategory.entertainment => 'entertainment',
        MovementCategory.other => 'other',
      };

  static MovementCategory fromDb(String value) => switch (value) {
        'food' => MovementCategory.food,
        'house' => MovementCategory.house,
        'debits' => MovementCategory.debits,
        'entertainment' => MovementCategory.entertainment,
        'other' => MovementCategory.other,
        _ => MovementCategory.other,
      };
}

class Movement {
  const Movement({
    required this.id,
    required this.description,
    required this.value,
    required this.fortnight,
    required this.isPaid,
    required this.category,
    required this.isInstallmentPurchase,
    this.currentInstallment,
    this.installmentValue,
    this.installmentQuantity,
    this.installmentPurchaseId,
    required this.createdAt,
  });

  final String id;
  final String description;
  final double value;
  final Fortnight fortnight;
  final bool isPaid;
  final MovementCategory category;
  final bool isInstallmentPurchase;
  final int? currentInstallment;
  final double? installmentValue;
  final int? installmentQuantity;
  final String? installmentPurchaseId;
  final DateTime createdAt;

  static Movement fromMap(Map<String, dynamic> map) {
    return Movement(
      id: (map['id'] as String).toString(),
      description: (map['description'] as String? ?? '').toString(),
      value: (map['value'] as num? ?? 0).toDouble(),
      fortnight: FortnightPtBr.fromDb((map['fortnight'] as String? ?? 'first')),
      isPaid: (map['isPaid'] as bool? ?? false),
      category:
          MovementCategoryPtBr.fromDb((map['category'] as String? ?? 'other')),
      isInstallmentPurchase: (map['isInstallmentPurchase'] as bool? ?? false),
      currentInstallment: (map['currentInstallment'] as num?)?.toInt(),
      installmentValue: (map['installmentValue'] as num?)?.toDouble(),
      installmentQuantity: (map['installmentQuantity'] as num?)?.toInt(),
      installmentPurchaseId: map['installmentPurchaseId'] as String?,
      createdAt: DateTime.tryParse((map['createdAt'] as String? ?? '')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toInsertMap() {
    final map = <String, dynamic>{
      'description': description,
      'value': value,
      'fortnight': fortnight.dbValue,
      'isPaid': isPaid,
      'category': category.dbValue,
      'isInstallmentPurchase': isInstallmentPurchase,
      'installmentPurchaseId': installmentPurchaseId,
    };

    if (isInstallmentPurchase) {
      map
        ..['currentInstallment'] = currentInstallment
        ..['installmentValue'] = installmentValue
        ..['installmentQuantity'] = installmentQuantity;
    }

    return map;
  }

  Map<String, dynamic> toUpdateMap() => toInsertMap();
}

