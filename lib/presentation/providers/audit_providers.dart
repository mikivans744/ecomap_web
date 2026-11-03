import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/firestore_audit_service.dart';
import '../../domain/services/audit_service.dart';
import 'firestore_provider.dart';

final auditServiceProvider = Provider<AuditService>(
  (ref) => FirestoreAuditService(
    firestore: ref.watch(firestoreProvider),
  ),
);
