import { readFile } from 'node:fs/promises';
import { cert, initializeApp } from 'firebase-admin/app';
import {
  FieldPath,
  FieldValue,
  getFirestore,
} from 'firebase-admin/firestore';

const SERVICE_ACCOUNT_PATH =
  process.env.FIREBASE_SERVICE_ACCOUNT ?? './service-account.json';
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID;
const APPLY_CHANGES = process.argv.includes('--apply');
const PAGE_SIZE = 400;

const serviceAccount = JSON.parse(
  await readFile(SERVICE_ACCOUNT_PATH, 'utf8'),
);

initializeApp({
  credential: cert(serviceAccount),
  projectId: PROJECT_ID ?? serviceAccount.project_id,
});

const firestore = getFirestore();

const collections = [
  'admins',
  'users',
  'recolectores',
  'centros_acopio',
  'publicaciones',
  'ofertas',
  'reports',
  'audit_logs',
  'devices',
  'sync_requests',
];

const fieldMappings = [
  ['is_active', 'estadoActivo'],
  ['estado_activo', 'estadoActivo'],
  ['created_at', 'createdAt'],
  ['updated_at', 'updatedAt'],
  ['last_login', 'lastLogin'],
  ['last_login_at', 'lastLoginAt'],
  ['display_name', 'displayName'],
  ['device_id', 'deviceId'],
  ['pending_count', 'pendingCount'],
  ['last_sync_at', 'lastSyncAt'],
  ['last_error', 'lastError'],
  ['requires_sync', 'requiresSync'],
  ['updated_by', 'updatedBy'],
  ['synced_by', 'syncedBy'],
  ['last_sync_requested_at', 'lastSyncRequestedAt'],
];

console.log(
  APPLY_CHANGES
    ? 'Modo de aplicación: los campos camelCase se escribirán y los antiguos se borrarán.'
    : 'Modo de simulación. Usa --apply para escribir los cambios.',
);

for (const collectionName of collections) {
  let cursor;
  let documentsScanned = 0;
  let documentsChanged = 0;
  let fieldConflicts = 0;

  while (true) {
    let query = firestore
      .collection(collectionName)
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);

    if (cursor) {
      query = query.startAfter(cursor);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    documentsScanned += snapshot.size;
    const batch = firestore.batch();
    let batchWriteCount = 0;

    for (const document of snapshot.docs) {
      const data = document.data();
      const updates = {};

      for (const [legacyField, canonicalField] of fieldMappings) {
        if (!Object.prototype.hasOwnProperty.call(data, legacyField)) {
          continue;
        }

        if (Object.prototype.hasOwnProperty.call(data, canonicalField)) {
          fieldConflicts += 1;
        } else {
          updates[canonicalField] = data[legacyField];
        }

        updates[legacyField] = FieldValue.delete();
      }

      if (Object.keys(updates).length === 0) {
        continue;
      }

      documentsChanged += 1;
      if (APPLY_CHANGES) {
        batch.update(document.ref, updates);
        batchWriteCount += 1;
      }
    }

    if (batchWriteCount > 0) {
      await batch.commit();
    }

    cursor = snapshot.docs[snapshot.docs.length - 1];
  }

  console.log(
    `${collectionName}: ${documentsScanned} documentos revisados, ` +
      `${documentsChanged} con campos antiguos, ${fieldConflicts} conflictos ` +
      `camelCase preservados.`,
  );
}
