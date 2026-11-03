import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/entities/sync_records.dart';
import '../../domain/repositories/sync_repository.dart';
import 'firestore_provider.dart';

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepositoryImpl(firestore: ref.watch(firestoreProvider)),
);

final syncDevicesProvider = StreamProvider<List<SyncDevice>>(
  (ref) => ref.watch(syncRepositoryProvider).watchDevices(),
);

final syncRequestsProvider = StreamProvider<List<SyncRequest>>(
  (ref) => ref.watch(syncRepositoryProvider).watchRequests(),
);

final syncHistoryProvider = StreamProvider<List<SyncHistoryEntry>>(
  (ref) => ref.watch(syncRepositoryProvider).watchHistory(),
);
