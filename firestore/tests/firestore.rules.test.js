import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'ecomap-rules-test';
let testEnv;

const admin = (uid, permissions = {}) => ({
  role: 'admin',
  estadoActivo: true,
  permissions,
});

before(async () => {
  const rules = await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'admins', 'active-admin'), admin('active-admin'));
    await setDoc(doc(firestore, 'admins', 'inactive-admin'), {
      ...admin('inactive-admin'),
      estadoActivo: false,
    });
    await setDoc(doc(firestore, 'admins', 'limited-admin'), admin('limited-admin', {
      canSync: false,
    }));
    await setDoc(doc(firestore, 'users', 'user-1'), {
      uid: 'user-1',
      email: 'user@example.test',
      rol: 'ciudadano',
      estadoActivo: true,
    });
    await setDoc(doc(firestore, 'sync_requests', 'request-1'), {
      requestedBy: 'user-1',
      status: 'pending',
    });
    await setDoc(doc(firestore, 'devices', 'device-1'), {
      ownerId: 'user-1',
      lastSeen: 'seeded',
    });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

test('active admin can read and write users', async () => {
  const firestore = testEnv.authenticatedContext('active-admin').firestore();
  const userRef = doc(firestore, 'users', 'user-1');

  await assertSucceeds(getDoc(userRef));
  await assertSucceeds(updateDoc(userRef, { estadoActivo: false }));
  await assertSucceeds(setDoc(doc(firestore, 'users', 'user-2'), {
    uid: 'user-2',
    rol: 'ciudadano',
    estadoActivo: true,
  }));
  await assertSucceeds(deleteDoc(doc(firestore, 'users', 'user-2')));
});

test('inactive admin cannot read or write users', async () => {
  const firestore = testEnv.authenticatedContext('inactive-admin').firestore();
  const userRef = doc(firestore, 'users', 'user-1');

  await assertFails(getDoc(userRef));
  await assertFails(updateDoc(userRef, { estadoActivo: false }));
});

test('authenticated non-admin cannot write admin records', async () => {
  const firestore = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(setDoc(doc(firestore, 'admins', 'new-admin'), admin('new-admin')));
  await assertFails(updateDoc(doc(firestore, 'admins', 'active-admin'), {
    estadoActivo: false,
  }));
});

test('unauthenticated requests cannot read admin data', async () => {
  const firestore = testEnv.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(firestore, 'admins', 'active-admin')));
  await assertFails(getDocs(collection(firestore, 'users')));
  await assertFails(getDoc(doc(firestore, 'sync_requests', 'request-1')));
  await assertFails(getDoc(doc(firestore, 'devices', 'device-1')));
});

test('sync requests require an active admin with sync permission', async () => {
  const firestore = testEnv.authenticatedContext('active-admin').firestore();
  const requestRef = doc(firestore, 'sync_requests', 'request-1');

  await assertSucceeds(getDoc(requestRef));
  await assertSucceeds(updateDoc(requestRef, { status: 'processed' }));
  await assertFails(
    getDoc(doc(
      testEnv.authenticatedContext('limited-admin').firestore(),
      'sync_requests',
      'request-1',
    )),
  );
  await assertFails(
    setDoc(
      doc(
        testEnv.authenticatedContext('user-1').firestore(),
        'sync_requests',
        'request-2',
      ),
      { status: 'pending' },
    ),
  );
});

test('authenticated users can write their devices; only admins can read them', async () => {
  const userFirestore = testEnv.authenticatedContext('user-1').firestore();
  const deviceRef = doc(userFirestore, 'devices', 'device-2');

  await assertSucceeds(setDoc(deviceRef, {
    ownerId: 'user-1',
    lastSeen: 'updated',
  }));
  await assertFails(getDoc(doc(userFirestore, 'devices', 'device-1')));

  const adminFirestore = testEnv.authenticatedContext('active-admin').firestore();
  await assertSucceeds(getDoc(doc(adminFirestore, 'devices', 'device-1')));
  await assertSucceeds(setDoc(doc(userFirestore, 'devices', 'device-3'), {
    ownerId: 'user-1',
  }));
});
