import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Firebase Auth no devolvió un usuario después del login.',
      );
    }

    try {
      if (!await isAdminUser(user)) {
        throw FirebaseAuthException(
          code: 'not-admin',
          message: 'Este usuario no tiene permisos de administrador.',
        );
      }
      return credential;
    } catch (error, stackTrace) {
      try {
        await _firebaseAuth.signOut();
      } catch (signOutError, signOutStackTrace) {
        _log(
          'No se pudo cerrar la sesión rechazada: '
          '$signOutError\n$signOutStackTrace',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Future<bool> isAdminUser(User user) async {
    final data = await _readAdminProfile(user);
    if (data == null) return false;

    return isAdminProfile(data);
  }

  Future<Map<String, dynamic>?> _readAdminProfile(User user) async {
    final documentPath = '$_adminsCollection/${user.uid}';
    _log('Firebase Auth UID: ${user.uid}');
    _log('Consultando perfil administrativo en $documentPath');

    final document =
        await _firestore.collection(_adminsCollection).doc(user.uid).get();

    if (!document.exists) {
      _log(
          'No existe el documento administrativo para el usuario autenticado.');
      return null;
    }

    final data = document.data();
    if (data == null) {
      _log('El documento administrativo no contiene datos.');
      return null;
    }

    final role = _readRole(data['role']);
    final active = _readActive(data);
    _log(
      'Perfil administrativo encontrado: '
      'role="$role", estadoActivo=$active, '
      'campos=${data.keys.toList()}, '
      'roleType=${data['role'].runtimeType}, '
      'estadoActivoType=${data['estadoActivo'].runtimeType}, '
      'is_activeType=${data['is_active'].runtimeType}',
    );
    return data;
  }

  Future<AdminAuthState> _stateForUser(User? user) async {
    if (user == null) {
      _log('Firebase Auth no tiene una sesión activa.');
      return const AdminAuthState.unauthenticated(reason: 'No hay sesión');
    }

    try {
      final data = await _readAdminProfile(user);
      if (data == null) {
        return AdminAuthState.unauthenticated(
          reason: 'No existe documento en $_adminsCollection/${user.uid}',
        );
      }

      if (!isAdminProfile(data)) {
        final role = _readRole(data['role']);
        final active = _readActive(data);
        _log(
          'Acceso rechazado: role="$role" (esperado "admin"), '
          'estadoActivo=$active (esperado true).',
        );
        return AdminAuthState.unauthenticated(
          reason:
              'role="$role" (esperado "admin"), estadoActivo=$active (esperado true)',
        );
      }

      _log('ADMIN VÁLIDO → authenticated');
      return AdminAuthState.authenticated(
        uid: user.uid,
        email: user.email ?? '',
        permissions: _permissionsFrom(data['permissions'], data),
      );
    } catch (error, stackTrace) {
      _log('Error verificando el perfil administrativo: $error\n$stackTrace');
      return AdminAuthState.error(message: error.toString());
    }
  }

  static String _readRole(Object? value) =>
      value is String ? value.trim().toLowerCase() : '';

  @visibleForTesting
  static bool isAdminProfile(Map<String, dynamic> data) =>
      _readRole(data['role']) == 'admin' && _readActive(data);

  static bool _readActive(Map<String, dynamic> data) {
    final estadoActivo = data['estadoActivo'];
    if (estadoActivo is bool) return estadoActivo;

    final isActive = data['is_active'];
    return isActive is bool && isActive;
  }

  static AdminPermissions _permissionsFrom(
    Object? rawPermissions,
    Map<String, dynamic> profile,
  ) {
    if (rawPermissions is! Map) {
      return AdminPermissions.fromFirestore(profile);
    }

    final normalizedPermissions = <String, dynamic>{
      for (final entry in rawPermissions.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    return AdminPermissions.fromFirestore({
      ...profile,
      'permissions': normalizedPermissions,
    });
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Auth] $message');
  }
}
