# Configuración de la URL del Proxy de Gemini

La aplicación lee `GEMINI_FUNCTION_URL` durante la compilación mediante
`String.fromEnvironment`. El valor debe ser la URL HTTP de la función
`geminiChat`; no incluyas tokens ni claves API en esta variable.

## En desarrollo local

Inicia el emulador de Cloud Functions desde la raíz del proyecto:

```bash
firebase emulators:start --only functions
```

En otra terminal, inicia Flutter Web usando la URL local del emulador. Sustituye
`TU_PROYECTO` por el ID del proyecto Firebase usado por la aplicación:

```bash
flutter run -d chrome --dart-define=GEMINI_FUNCTION_URL=http://127.0.0.1:5001/TU_PROYECTO/us-central1/geminiChat
```

Por ejemplo, para el proyecto configurado actualmente (`ecomap-ae07e`):

```bash
flutter run -d chrome --dart-define=GEMINI_FUNCTION_URL=http://127.0.0.1:5001/ecomap-ae07e/us-central1/geminiChat
```

El navegador debe poder acceder al emulador en `127.0.0.1`. Si se usa un
emulador de Firebase Authentication, debe estar configurado para que la función
pueda validar los tokens de desarrollo.

## Usar una función desplegada

Despliega la función en el proyecto Firebase:

```bash
firebase deploy --only functions:geminiChat --project TU_PROYECTO
```

La URL de la función sigue el formato:

```text
https://us-central1-TU_PROYECTO.cloudfunctions.net/geminiChat
```

Usa esa URL al ejecutar Flutter Web:

```bash
flutter run -d chrome --dart-define=GEMINI_FUNCTION_URL=https://us-central1-TU_PROYECTO.cloudfunctions.net/geminiChat
```

Para generar el build web con una URL concreta:

```bash
flutter build web --dart-define=GEMINI_FUNCTION_URL=https://us-central1-TU_PROYECTO.cloudfunctions.net/geminiChat
```

Después, despliega el contenido de `build/web` en el hosting elegido. El valor
de `--dart-define` queda incorporado al build; vuelve a compilar si cambia la
URL entre entornos. Si no se proporciona, la aplicación usa la URL
predeterminada definida en `geminiFunctionUrlProvider`.

## Configurar la clave de Gemini

`GEMINI_FUNCTION_URL` solo configura el endpoint y no reemplaza
`GEMINI_API_KEY`. Configura la clave en el entorno del servidor de Cloud
Functions y nunca la incluyas en Flutter, en `--dart-define` ni en este archivo.
