import 'package:supabase_flutter/supabase_flutter.dart';

class Supa {
  static SupabaseClient get client => Supabase.instance.client;
}
