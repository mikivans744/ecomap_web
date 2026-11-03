import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';

const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID;
const SERVICE_ACCOUNT_PATH =
  process.env.FIREBASE_SERVICE_ACCOUNT ?? './service-account.json';

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('Faltan ADMIN_EMAIL y ADMIN_PASSWORD en variables de entorno');
  process.exit(1);
}

const permissions = {
  manageUsers: true,
  viewTransactions: true,
  viewReports: true,
  forceSync: true,
  moderateComplaints: true,
  viewStatistics: true,
  manageRoles: true,
};

const serviceAccount = JSON.parse(
  await readFile(SERVICE_ACCOUNT_PATH, 'utf8'),
);

initializeApp({
  credential: cert(serviceAccount),
  projectId: PROJECT_ID ?? serviceAccount.project_id,
});

const auth = getAuth();
const firestore = getFirestore();

const user = await auth.getUserByEmail(ADMIN_EMAIL).catch(async () => {
  return auth.createUser({
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    emailVerified: true,
  });
});

await firestore.collection('admins').doc(user.uid).set(
  {
    email: ADMIN_EMAIL,
    role: 'admin',
    estadoActivo: true,
    permissions,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  { merge: true },
);

const adminDoc = await firestore.collection('admins').doc(user.uid).get();
console.log(`Administrador configurado: ${user.uid}`);
console.log(`Rol: ${adminDoc.data()?.role}`);
console.log(
  `Permisos: ${JSON.stringify(adminDoc.data()?.permissions ?? permissions)}`,
);
