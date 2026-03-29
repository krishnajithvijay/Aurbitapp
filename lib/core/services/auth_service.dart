import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import 'supabase_service.dart';
import 'encryption_service.dart';
import '../../models/user_model.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  final _db = SupabaseService.instance;

  User? get currentUser => _db.currentUser;
  String? get currentUserId => _db.currentUserId;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _db.auth.onAuthStateChange;

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    final response = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': displayName ?? username},
    );

    if (response.user == null) return null;

    // Generate E2E keypair for this user
    final keyPair = await EncryptionService.instance.generateKeyPair();
    final publicKeyBase64 = await EncryptionService.instance.exportPublicKey(keyPair.publicKey);

    await _db.client.from(AppConstants.profilesTable).insert({
      'id': response.user!.id,
      'email': email,
      'username': username,
      'display_name': displayName ?? username,
      'public_key': publicKeyBase64,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Store private key securely on device
    await EncryptionService.instance.storePrivateKey(keyPair.privateKey);

    return getCurrentUserProfile();
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    await _db.auth.signInWithPassword(email: email, password: password);
    return getCurrentUserProfile();
  }

  Future<void> signOut() async {
    await _db.auth.signOut();
  }

  Future<UserModel?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getUserById(userId);
  }

  Future<UserModel?> getUserById(String userId) async {
    final data = await _db.selectSingle(
      AppConstants.profilesTable,
      column: 'id',
      value: userId,
    );
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final data = await _db.selectSingle(
      AppConstants.profilesTable,
      column: 'username',
      value: username,
    );
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  Future<List<UserModel>> searchUsers(String query) async {
    final results = await _db.client
        .from(AppConstants.profilesTable)
        .select()
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .neq('id', currentUserId ?? '')
        .limit(20);
    return results.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? username,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (username != null) updates['username'] = username;

    await _db.update(AppConstants.profilesTable, updates, column: 'id', value: userId);
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _db.update(
      AppConstants.profilesTable,
      {
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      },
      column: 'id',
      value: userId,
    );
  }

  Future<void> resetPassword(String email) async {
    await _db.auth.resetPasswordForEmail(email);
  }
}
