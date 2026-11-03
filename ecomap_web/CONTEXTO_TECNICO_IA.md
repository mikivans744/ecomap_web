# Contexto tecnico de ECOMAP Web

Documento de referencia para entender el estado actual del repositorio y proporcionar contexto a otra IA. Describe lo encontrado en el codigo; no implica que todos los componentes esten integrados o listos para produccion.

## 1. Resumen del proyecto

ECOMAP Web es una aplicacion Flutter orientada a navegador que presenta un panel administrativo para una plataforma de reciclaje y apoyo comunitario. El proyecto usa Dart/Flutter y Firebase Authentication + Cloud Firestore. Hay codigo preparado para almacenamiento local con Hive, estado con Riverpod, navegacion con GoRouter y un asistente Gemini, pero partes importantes de estas integraciones no estan conectadas al flujo principal.

El flujo que realmente arranca actualmente ofrece inicializacion Firebase, inicio de sesion de administrador y un dashboard. Los indicadores, graficas, alertas y secciones de navegacion del dashboard son principalmente contenido estatico/de demostracion; no representan consultas en vivo a Firestore.

## 2. Tecnologias y dependencias

- Flutter y Dart SDK `^3.5.0`.
- Firebase Core `^3.2.0`, Firebase Auth `^5.2.0` y Cloud Firestore `^5.2.0`.
- Riverpod `flutter_riverpod ^2.6.1` y generadores/lints asociados.
- GoRouter `^14.2.0`.
- Google Fonts `^6.2.1`.
- Hive `^2.2.3`.
- Cliente de Gemini `google_generative_ai ^0.4.0`.
- Pruebas con `flutter_test`; el backend de provisionamiento administrativo usa Node.js y `firebase-admin`.

La configuracion de Firebase para Flutter esta en `lib/firebase_options.dart`; el proyecto declarado en `firebase.json` es `ecomap-ae07e` y las reglas se toman de `firestore.rules`. La configuracion cliente de Firebase no debe confundirse con una credencial privada de cuenta de servicio.

## 3. Estructura del codigo fuente

```text
lib/
  main.dart                         Inicio Flutter, Firebase y puerta de autenticacion
  firebase_options.dart             Configuracion Firebase por plataforma
  core/
    auth/                            Servicio/estado/proveedor de autenticacion admin
    constants/route_names.dart       Nombres declarados de rutas
    routing/                         GoRouter y guard de autenticacion
    theme/                           Colores y tema Material
  data/
    datasources/firebase/            Adaptador Firebase Auth alternativo
    datasources/local/               Almacenamiento Hive, cache y audit log local
    models/                          Modelos de transporte, por ejemplo sincronizacion
    repositories/                    Implementaciones Firestore para admin y sync
  domain/
    entities/                        Entidades de negocio y enums
    repositories/                    Contratos de repositorios
    services/                        Contratos y servicios Gemini/notificaciones
  presentation/
    pages/auth/                      Pantalla de login
    pages/dashboard/                 Dashboard admin
    widgets/dashboard/               Componentes visuales del dashboard
test/                                Pruebas unitarias y de widgets
scripts/                             Provisionamiento del administrador con Firebase Admin SDK
web/                                 Shell HTML, manifest e iconos Flutter Web
```

## 4. Arquitectura: intencion y estado real

La estructura sugiere una arquitectura por capas:

1. `presentation`: interfaz y estado local de pantallas.
2. `domain`: entidades, contratos de repositorio y servicios de negocio.
3. `data`: adaptadores de Firebase/Hive y conversion de modelos.
4. `core`: autenticacion transversal, rutas, tema y constantes.

Sin embargo, actualmente no es una Clean Architecture plenamente conectada:

- `main.dart` no envuelve la app en `ProviderScope`; los proveedores Riverpod no controlan el arranque.
- `main.dart` no usa `AppRouter`; el flujo real cambia entre login y dashboard mediante `AdminAuthGate` + `StreamBuilder`.
- `LoginPage` instancia `AdminAuthServiceImpl()` directamente en vez de recibir el servicio desde un proveedor o una abstraccion inyectada.
- `AppRouter` y `AuthGuard` existen, pero no son el enrutamiento activo de la app.
- Los contratos `UserRepository`, `AdminRepository` y `SyncRepository` no todos tienen implementaciones visibles/consumidas por pantallas; se hallo implementacion para admin y sync, no para usuarios.
- Dashboard y paneles no consumen los repositorios Firestore encontrados.
- Se declara almacenamiento Hive, pero no se encontro `Hive.init` ni `Hive.openBox` dentro de `lib/`. Las implementaciones asumen que las cajas ya fueron abiertas.
- Hay una segunda abstraccion Firebase Auth en `data/datasources/firebase/` que parece duplicar parte de `core/auth/` y no aparece conectada al flujo principal.

Por ello, al modificar el sistema hay que tratar como fuente de verdad el flujo activo de cada feature y no asumir que una clase existente ya se usa en produccion.

## 5. Arranque y autenticacion

Secuencia de ejecucion actual:

1. `main()` inicializa bindings Flutter y monta `EcomapWebApp`.
2. El `State` de la app ejecuta `Firebase.initializeApp` usando `DefaultFirebaseOptions.currentPlatform`.
3. Mientras inicializa, muestra `LoadingScreen`; ante error muestra una pantalla con accion de reintento.
4. Tras inicializar Firebase crea `AdminAuthServiceImpl` y monta `AdminAuthGate`.
5. La puerta escucha `FirebaseAuth.authStateChanges()`. El servicio transforma cada `User?` en `AdminAuthState` consultando `/admins/{uid}`.
6. `signInWithEmailAndPassword` autentica con Firebase Auth, consulta el documento de administrador y exige `role == 'admin'`. Si no es admin, cierra la sesion y lanza el error `not-admin`.
7. Un estado admin abre `DashboardPage`; usuario anonimo o no admin ve `LoginPage`.
8. El cierre de sesion vuelve a depender del stream de Firebase Auth.

`AdminPermissions` define capacidades como gestionar usuarios, revisar transacciones/reportes y forzar sincronizacion. El estado actual permite acceso al dashboard unicamente mediante `isAdmin`; no se ve aplicacion de permisos individuales a rutas/acciones del dashboard.

## 6. Presentacion

### Login

`LoginPage` contiene formulario de correo y contrasena, validacion basica, estado de envio, ocultar/mostrar contrasena y mensajes de error. La autenticacion se delega directamente a `AdminAuthServiceImpl`.

### Dashboard

`DashboardPage` tiene layout adaptable, barra lateral/drawer, boton de cierre de sesion, notificaciones, tarjetas de metricas, paneles con iconos de grafica, alertas y un panel de asistente.

Las cifras (material reciclado, usuarios activos, reputacion y reportes), las graficas, alertas y elementos de navegacion se construyen como datos estaticos en la pantalla. Las acciones de navegacion no cambian de pagina (`onTap` vacio o solo cierra el drawer). No inferir que las vistas de Usuarios, Reciclaje, Moderacion, Mapa o Soporte ya estan implementadas: `RouteNames` solo enumera nombres y las dos rutas configuradas en `AppRouter` son login y dashboard.

El tema usa Material 3, Google Fonts Poppins y una paleta verde definida en `core/theme/`.

## 7. Dominio y contratos

Entidades declaradas en `domain/entities/`:

- `AdminUser`: id, correo, nombre, rol (`admin`, `moderator`, `auditor`), activo y fechas.
- `RecyclingTransaction`: usuario, recolector, categoria, peso, puntos, estado y fechas.
- `ReportComplaint`: denunciante, usuario reportado, categoria, descripcion, estado de moderacion, fechas y nota.
- `SyncStatus`: dispositivo, estado (`pending`, `syncing`, `synced`, `failed`), pendientes, fecha y error.
- `SystemNotification`: identificador, titulo, mensaje, prioridad y fecha.
- `UserRating`: usuario evaluado, autor, puntuacion, comentario, estado (`active`, `disputed`, `hidden`) y fechas.

Contratos de repositorio:

- `AdminRepository`: observar administrador actual, leer por id y actualizar rol/estado activo.
- `SyncRepository`: solicitar sincronizacion y marcar dispositivo sincronizado.
- `UserRepository`: observar usuarios y actualizar reputacion.

Servicios:

- `GeminiAssistantService`: contrato `ask(prompt)`. Existe implementacion Gemini parametrizada por API key y modelo `gemini-2.0-flash`, y `NoopGeminiAssistantService` para modo no configurado. El dashboard usa `NoopGeminiAssistantService` por defecto; no se encontro configuracion segura de una API key ni inyeccion de `GeminiAssistantServiceImpl` en el arranque.
- `SystemNotificationService`: implementacion en memoria, no persistente ni sincronizada con Firestore.

## 8. Persistencia e integracion de datos

### Firestore visible

- `AdminAuthServiceImpl` lee `admins/{uid}` y valida el campo `role` con valor `admin`.
- `FirestoreAdminRepository` opera sobre `admins`, filtra `is_active == true`, y espera campos `email`, `display_name`, `role`, `is_active`, `created_at` y `last_login_at`.
- `SyncRepositoryImpl.forceSync` escribe en `sync_requests/{deviceId}` usando `requires_sync`, `updated_by`, `device_id`, `reason`, `updated_at`.
- `SyncRepositoryImpl.markDeviceSynced` actualiza `devices/{deviceId}` con `requires_sync`, `synced_by` y `last_sync_requested_at`.
- `SyncStatusModel` convierte entre mapa Firestore y entidad, usando `device_id`, `status`, `pending_count`, `last_sync_at`, `last_error`.

### Hive local

- `AdminStorage`/`HiveAdminStorage` usan la caja `admin_panel_config`.
- `AdminCache` usa `admin_cache`.
- `AuditLogCache` usa `audit_logs` y limita entradas conservadas, 100 por defecto.
- Estas clases existen pero no se hallo inicializacion/ apertura de Hive en el arranque Flutter ni uso en el dashboard.

### Reglas Firestore configuradas

`firestore.rules` declara las colecciones `admins`, `users`, `transactions`, `reports`, `complaints`, `sync` y `stats`. `isAdmin()` considera admin al usuario autenticado cuyo documento `admins/{uid}` tiene `role == 'admin'`.

Las reglas permiten que un propietario autenticado cree y actualice su propio documento en `/admins/{adminId}`. Como ese mismo documento determina si el usuario es admin, un usuario normal podria intentar asignarse el rol `admin`. Este es un hallazgo de seguridad critico que se debe corregir en las reglas y validar con Firebase Emulator antes de desplegar.

Hay discrepancias adicionales que pueden causar denegaciones o datos inconsistentes:

- Reglas cubren `/sync/{id}`, pero el repositorio escribe `/sync_requests/{deviceId}` y `/devices/{deviceId}`. Si no existen reglas adicionales fuera de este repositorio, Firestore denegara esas operaciones por defecto.
- El script de provisionamiento crea `admins/{uid}` con `createdAt` (camelCase), mientras `FirestoreAdminRepository` lee `created_at` (snake_case); en ese repositorio la fecha podria quedar en epoch.
- `FirestoreAdminRepository.watchCurrentAdmin()` requiere `is_active == true`, mientras el script de provisionamiento visible no establece `is_active`; ese stream no encontraria el admin creado por el script.
- `AdminAuthServiceImpl` busca el rol en el documento directamente, por lo que el flujo de login y el repositorio de perfil aplican expectativas distintas al mismo documento.
- El script escribe tambien `permissions` y `updatedAt`; las reglas y el resto de modelos deben mantenerse alineados con el esquema real y las convenciones de nombres.

La aplicacion cliente solo puede evaluar su estado local; la seguridad real depende de las reglas desplegadas en Firebase. Confirmar siempre el proyecto y las reglas activas antes de una conclusion operativa.

## 9. Provisionamiento y secretos

`scripts/setup_admin.mjs` usa Firebase Admin SDK para buscar/crear un usuario Firebase Auth y escribir su documento de administrador. Lee una cuenta de servicio desde `FIREBASE_SERVICE_ACCOUNT` (por defecto una ruta local `service-account.json`) y admite variables de entorno para proyecto, correo y contrasena.

Riesgos encontrados en el script: tiene valores de respaldo para correo y contrasena de administrador codificados en el codigo. No repetir esos valores en prompts, documentos, logs ni repositorios; sustituirlos por configuracion externa obligatoria y rotar/revocar cualquier credencial que haya sido expuesta. Los archivos `service-account.json` de la raiz y `scripts/` son credenciales privadas potenciales: no leerlos, copiarlos, subirlos a Git ni compartirlos con una IA. Verificar si fueron versionados y revocar la clave si existe posibilidad de exposicion. La clave de Gemini tampoco debe incorporarse al cliente web, pues las variables del cliente pueden inspeccionarse.

## 10. Pruebas y nivel de cobertura

Pruebas existentes:

- `test/admin_auth_test.dart`: guard de acceso y usuarios admin/no admin.
- `test/fase2_core_test.dart`: entidades, tema y rutas.
- `test/fase3_data_test.dart`: payload de sincronizacion, conversion de estado y caches Hive.
- `test/fase4_ui_test.dart`: formulario, dashboard, metricas y puerta de autenticacion.
- `test/fase5_ai_and_notifications_test.dart`: servicio de asistente inyectado y notificaciones en memoria.
- `test/widget_test.dart`: prueba base de widget.

Las pruebas cubren contratos/modelos y widgets con dobles o datos locales; no demuestran reglas de Firestore desplegadas, autorizacion real contra Firebase, persistencia en Firestore, calidad de datos del dashboard ni funcionamiento de Gemini real.

Comandos usuales desde la raiz Flutter: `flutter pub get`, `flutter analyze` y `flutter test`. Pruebas de seguridad de reglas deberian ejecutarse con Firebase Emulator y casos de usuario normal/admin.

## 11. Hallazgos priorizados

1. **Critico: escalamiento de privilegios en reglas.** Un usuario autenticado puede escribir su documento de administrador propio y el campo `role` sirve como criterio de admin. Cerrar la autoasignacion de rol; la creacion/cambio de roles debe quedar en Admin SDK o en una operacion admin estrictamente autorizada. Agregar pruebas de reglas.
2. **Alto: secretos/configuracion de administrador.** El script contiene credenciales de respaldo y el workspace incluye archivos con nombre `service-account.json`. No revelar valores; revisar exposicion/versionado y rotar secretos.
3. **Alto: reglas y colecciones de sync no coinciden.** Alinear `sync`, `sync_requests` y `devices` entre cliente, backend y reglas, con permisos minimos.
4. **Medio: esquema de admin divergente.** `createdAt`/`created_at` y ausencia de `is_active` entre setup y repositorio pueden romper consultas o presentar fechas equivocadas.
5. **Medio: arquitectura declarada no integrada.** Riverpod, GoRouter, repositorios Firestore y Hive no gobiernan actualmente el flujo principal observado; hay implementaciones duplicadas y dependencias directas desde UI.
6. **Medio: dashboard de demostracion.** No usar cifras/alertas actuales como metricas reales; conectar fuentes y estados de carga/error antes de tomar decisiones operativas.
7. **Medio: Gemini en cliente.** No enviar una clave privada desde Flutter Web. Si se habilita IA, mediar las llamadas mediante backend autenticado y limitar/registrar solicitudes.

## 12. Instrucciones para una IA que trabaje en este repositorio

Usa este bloque como contexto inicial. Verifica el codigo actual antes de cambiarlo, ya que este resumen describe el estado observado y puede quedar desactualizado.

```text
Trabajas en ECOMAP Web, una aplicacion Flutter Web/Dart 3.5 para administrar una plataforma de reciclaje y apoyo comunitario. Backend: Firebase Authentication y Cloud Firestore. El repositorio contiene capas core/data/domain/presentation, pero la arquitectura esta parcialmente integrada.

Flujo activo: lib/main.dart inicializa Firebase; AdminAuthGate escucha AdminAuthServiceImpl y muestra LoginPage o DashboardPage. El login valida Firebase Auth y exige role == 'admin' en admins/{uid}. El dashboard contiene datos de ejemplo y navegacion sin destinos funcionales. No asumas que Riverpod, GoRouter, Hive, repositorios Firestore ni Gemini real estan conectados a la interfaz; inspecciona los usos antes de depender de ellos.

Entidades: AdminUser, RecyclingTransaction, ReportComplaint, SyncStatus, SystemNotification, UserRating. Contratos: AdminRepository, SyncRepository, UserRepository. Adaptadores visibles: FirestoreAdminRepository y SyncRepositoryImpl. Servicios IA/notificaciones: GeminiAssistantService (Noop por defecto) e InMemorySystemNotificationService. Stack y versiones exactas estan en pubspec.yaml.

Seguridad prioritaria: firestore.rules permite al propietario crear/actualizar admins/{uid}, pero ese documento y role == 'admin' conceden privilegios; esto puede permitir escalamiento. No expongas credenciales. scripts/setup_admin.mjs contiene valores de respaldo para credenciales y hay archivos service-account.json potencialmente privados. No abras ni incluyas esos archivos en contexto. Nunca pongas claves Gemini en Flutter Web; usar backend.

Desalineaciones conocidas: reglas usan /sync, implementacion escribe /sync_requests y /devices; setup_admin escribe createdAt y no is_active, mientras FirestoreAdminRepository espera created_at e is_active. Revisar esquema y reglas antes de modificar sync/admin.

Antes de editar: identifica el flujo realmente usado, consulta reglas Firebase y pruebas cercanas, conserva convenciones Dart existentes y aplica cambios pequeños. No supongas que los datos visibles del dashboard son reales. Valida con flutter analyze y flutter test; cambios en reglas necesitan pruebas con Firebase Emulator. Explica claramente incertidumbres y riesgos de despliegue.
```

## 13. Fuentes principales

- `lib/main.dart`
- `lib/core/auth/admin_auth_service.dart`
- `lib/core/auth/admin_auth_state.dart`
- `lib/core/routing/app_router.dart` y `lib/core/routing/auth_guard.dart`
- `lib/presentation/pages/auth/login_page.dart`
- `lib/presentation/pages/dashboard/dashboard_page.dart`
- `lib/domain/entities/` y `lib/domain/repositories/`
- `lib/data/repositories/` y `lib/data/datasources/local/`
- `firestore.rules`, `firebase.json` y `scripts/setup_admin.mjs`
- `pubspec.yaml` y `test/`