# Ordena+

Este directorio contiene el código fuente Flutter de Ordena+.

## 🛠️ Configuración y Ejecución

### Requisitos Previos

- Flutter SDK (Stable Channel)
- Android Studio / VS Code
- Dispositivo Android o Emulador (API 21+)

### Instalación de Dependencias

Ejecuta el siguiente comando en este directorio:

```bash
flutter pub get
```

### Ejecutar la App

Para depurar en un dispositivo conectado:

```bash
flutter run
```

Para compilar un APK de release:

```bash
flutter build apk --release
```

## 🏗️ Estructura de Directorios

- `lib/domain`: Modelos, Repositorios (Interfaces) y Lógica de Negocio.
- `lib/data`: Implementación de Repositorios, Servicios (Database, Cache).
- `lib/presentation`: UI (Screens, Widgets) y State Management (Providers/Notifiers).
- `lib/main.dart`: Punto de entrada, configuración de rutas (GoRouter) y temas.

## 🔑 Permisos

La app requiere permisos de almacenamiento (`MANAGE_EXTERNAL_STORAGE` en Android 11+) para gestionar archivos y moverlos entre carpetas y tarjetas SD. Estos se solicitan en tiempo de ejecución.
