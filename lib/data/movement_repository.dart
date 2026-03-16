import 'package:finport/data/supabase_client.dart';
import 'package:finport/models/movement.dart';

class MovementRepository {
  static const table = 'movements';

  Future<List<Movement>> listAll({int? month, int? year}) async {
    final query = Supa.client.from(table).select('*');
    if (month != null) {
      query.eq('month', month);
    }
    if (year != null) {
      query.eq('year', year);
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

  Future<void> delete(String id) async {
    await Supa.client.from(table).delete().eq('id', id);
  }
}
