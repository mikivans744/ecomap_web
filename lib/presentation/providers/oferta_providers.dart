import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_oferta_repository.dart';
import '../../domain/entities/oferta_entity.dart';
import '../../domain/entities/negociacion_oferta_entity.dart';
import '../../domain/repositories/oferta_repository.dart';
import 'audit_providers.dart';
import 'firestore_provider.dart';

typedef OfertaWatchFilter = ({
  String? estado,
  String? centroId,
  String? recolectorId,
  DateTime? desde,
  DateTime? hasta,
});

final ofertaRepositoryProvider = Provider<OfertaRepository>(
  (ref) => FirestoreOfertaRepository(
    ref.watch(firestoreProvider),
    auditService: ref.watch(auditServiceProvider),
  ),
);

final ofertasProvider =
    StreamProvider.family<List<OfertaEntity>, OfertaWatchFilter>((ref, filter) {
  return ref.watch(ofertaRepositoryProvider).watchAll(
        estado: filter.estado,
        centroId: filter.centroId,
        recolectorId: filter.recolectorId,
        desde: filter.desde,
        hasta: filter.hasta,
      );
});

final ofertaByIdProvider =
    StreamProvider.family<OfertaEntity, String>((ref, id) {
  return ref.watch(ofertaRepositoryProvider).watchById(id);
});

final ofertaSearchProvider =
    FutureProvider.family<List<OfertaEntity>, String>((ref, query) {
  return ref.watch(ofertaRepositoryProvider).search(query);
});

typedef NegotiationOfferWatchFilter = ({
  String? publicacionId,
  String? ciudadanoId,
  String? recolectorId,
});

final negotiationOffersProvider = StreamProvider.family<
    List<NegociacionOfertaEntity>, NegotiationOfferWatchFilter>((ref, filter) {
  return ref.watch(ofertaRepositoryProvider).watchNegotiationOffers(
        publicacionId: filter.publicacionId,
        ciudadanoId: filter.ciudadanoId,
        recolectorId: filter.recolectorId,
      );
});
