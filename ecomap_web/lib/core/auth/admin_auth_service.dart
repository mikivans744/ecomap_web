import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_auth_state.dart';

abstract interface class AdminAuthService {
  User? get currentUser;

  Stream<AdminAuthState> get authStateChanges;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<bool> isAdminUser(User user);
}

class AdminAuthServiceImpl implements AdminAuthService {
  AdminAuthServiceImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  static const String _adminsCollection = 'admins';
  static const String _roleField = 'role';
  static const String _activeField = 'estadoActivo';

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Stream<AdminAuthState> get authStateChanges =>
      _firebaseAuth.authStateChanges().asyncMap(_stateForUser);

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (!await isAdminUser(credential.user!)) {
      await _firebaseAuth.signOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'Este usuario no tiene permisos de administrador.',
      );
    }

    return credential;
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Future<bool> isAdminUser(User user) async {
    final adminDoc =
        await _firestore.collection(_adminsCollection).doc(user.uid).get();
    final profile = adminDoc.data();

    return adminDoc.exists &&
        profile?[_roleField] == 'admin' &&
        profile?[_activeField] == true;
  }

  Future<AdminAuthState> _stateForUser(User? user) async {
    if (user == null) {
      return const AdminAuthState.anonymous();
    }

    final profile =
        await _firestore.collection(_adminsCollection).doc(user.uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    final isAdmin = profile.exists &&
        data[_roleField] == 'admin' &&
        data[_activeField] == true;

    final permissions = profile.exists
        ? AdminPermissions.fromFirestore(Map<String, dynamic>.from(data))
        : const AdminPermissions();

    return AdminAuthState(
      userId: user.uid,
      email: user.email ?? '',
      isAdmin: isAdmin,
      permissions: permissions,
    );
  }
}
