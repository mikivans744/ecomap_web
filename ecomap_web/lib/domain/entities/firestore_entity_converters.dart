import 'package:cloud_firestore/cloud_firestore.dart';

DateTime readFirestoreDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

double readFirestoreDouble(dynamic value) {
  return value is num ? value.toDouble() : 0;
}

int readFirestoreInt(dynamic value) {
  return value is num ? value.toInt() : 0;
}

Map<String, dynamic> readFirestoreMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}
