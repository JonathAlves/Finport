import 'package:finport/data/supabase_client.dart';
import 'package:finport/models/installment_purchase.dart';

class InstallmentPurchaseRepository {
  static const table = 'installment_purchases';

  Future<List<InstallmentPurchase>> listActive() async {
    final data = await Supa.client
        .from(table)
        .select('*')
        .eq('isActive', true)
        .order('createdAt', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(InstallmentPurchase.fromMap)
        .toList();
  }

  Future<InstallmentPurchase> insert(InstallmentPurchase p) async {
    final data = await Supa.client
        .from(table)
        .insert(p.toInsertMap())
        .select('*')
        .single();
    return InstallmentPurchase.fromMap((data as Map).cast<String, dynamic>());
  }

  Future<InstallmentPurchase> incrementInstallment(String id) async {
    final current = await Supa.client
        .from(table)
        .select('*')
        .eq('id', id)
        .single();
    final p = InstallmentPurchase.fromMap(
      (current as Map).cast<String, dynamic>(),
    );

    final next = p.currentInstallment + 1;
    final isActive = next < p.installmentQuantity;

    final updated = await Supa.client
        .from(table)
        .update({'currentInstallment': next, 'isActive': isActive})
        .eq('id', id)
        .select('*')
        .single();

    return InstallmentPurchase.fromMap(
      (updated as Map).cast<String, dynamic>(),
    );
  }

  Future<InstallmentPurchase> setCurrentInstallment({
    required String id,
    required int currentInstallment,
  }) async {
    final current = await Supa.client
        .from(table)
        .select('*')
        .eq('id', id)
        .single();
    final p = InstallmentPurchase.fromMap(
      (current as Map).cast<String, dynamic>(),
    );

    final isActive = currentInstallment < p.installmentQuantity;
    final updated = await Supa.client
        .from(table)
        .update({
          'currentInstallment': currentInstallment,
          'isActive': isActive,
        })
        .eq('id', id)
        .select('*')
        .single();

    return InstallmentPurchase.fromMap(
      (updated as Map).cast<String, dynamic>(),
    );
  }

  Future<InstallmentPurchase> update(String id, Map<String, dynamic> patch) async {
    final data = await Supa.client
        .from(table)
        .update(patch)
        .eq('id', id)
        .select('*')
        .single();
    return InstallmentPurchase.fromMap((data as Map).cast<String, dynamic>());
  }
}
