# Convención de campos Firestore — ECOMAP

- Todos los campos almacenados en Firestore usan camelCase.
- Ejemplos: `estadoActivo`, `createdAt`, `updatedAt`, `lastLoginAt`,
  `displayName`, `isActive` (booleano), `role`, `zona`.
- Los documentos Dart usan el mismo nombre que el campo Firestore; por
  ejemplo, `user.estadoActivo`.
- Los scripts de setup y migración escriben campos camelCase.
- Las reglas de Firestore deben consultar campos camelCase.
- Los nombres de colecciones y los valores de enumeración no son campos y
  conservan sus identificadores actuales.
