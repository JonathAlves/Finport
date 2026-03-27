import 'package:finport/data/supabase_client.dart';
import 'package:finport/models/movement.dart';

class MovementRepository {
  static const table = 'movements';

  Future<List<Movement>> listAll({int? month, int? year}) async {
    var query = Supa.client.from(table).select('*');
    if (month != null) {
      query = query.eq('month', month);
    }
    if (year != null) {
      query = query.eq('year', year);
    }
    final data = await query.order('createdAt', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Movement.fromMap)
        .toList();
  }

  Future<Movement> insert(Movement movement) async {
    final data = await Supa.client
        .from(table)
        .insert(movement.toInsertMap())
        .select('*')
        .single();
    return Movement.fromMap((data as Map).cast<String, dynamic>());
  }

  Future<Movement> update(String id, Map<String, dynamic> patch) async {
    final data = await Supa.client
        .from(table)
        .update(patch)
        .eq('id', id)
        .select('*')
        .single();
    return Movement.fromMap((data as Map).cast<String, dynamic>());
  }

  Future<void> updateInstallmentSeries(
    String installmentPurchaseId,
    Map<String, dynamic> patch,
  ) async {
    await Supa.client
        .from(table)
        .update(patch)
        .eq('installmentPurchaseId', installmentPurchaseId);
  }

  Future<void> delete(String id) async {
    await Supa.client.from(table).delete().eq('id', id);
  }

  Future<void> deleteInstallmentsFrom({
    required String installmentPurchaseId,
    required int fromInstallment,
  }) async {
    await Supa.client
        .from(table)
        .delete()
        .eq('installmentPurchaseId', installmentPurchaseId)
        .gte('currentInstallment', fromInstallment);
  }
}
