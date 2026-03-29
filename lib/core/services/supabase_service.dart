import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => currentUser?.id;

  GoTrueClient get auth => client.auth;
  SupabaseStorageClient get storage => client.storage;

  RealtimeChannel channel(String name) => client.channel(name);

  Future<List<Map<String, dynamic>>> select(
    String table, {
    String? columns,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
    int? offset,
  }) async {
    var query = client.from(table).select(columns ?? '*');

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }
    if (limit != null) {
      query = query.limit(limit);
    }
    if (offset != null) {
      query = query.range(offset, offset + (limit ?? 20) - 1);
    }

    return await query;
  }

  Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? columns,
    required String column,
    required dynamic value,
  }) async {
    final result = await client
        .from(table)
        .select(columns ?? '*')
        .eq(column, value)
        .maybeSingle();
    return result;
  }

  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final result = await client.from(table).insert(data).select().single();
    return result;
  }

  Future<void> update(
    String table,
    Map<String, dynamic> data, {
    required String column,
    required dynamic value,
  }) async {
    await client.from(table).update(data).eq(column, value);
  }

  Future<void> delete(
    String table, {
    required String column,
    required dynamic value,
  }) async {
    await client.from(table).delete().eq(column, value);
  }

  Future<int> count(String table, {Map<String, dynamic>? filters}) async {
    final result = await client
        .from(table)
        .select('*', const FetchOptions(count: CountOption.exact, head: true));
    return result.count ?? 0;
  }
}
