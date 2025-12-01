# Ordena+ 📁📸

Ordena+ es una aplicación móvil para Android/iOS diseñada para **clasificar fotos y vídeos de forma rápida y visual** mediante un sistema de arrastrar y soltar en una ruleta de carpetas.

## 🚀 Características Principales

- Detección automática de fotos/vídeos nuevos.
- Indexación incremental y caché de miniaturas.
- Clasificación rápida mediante ruleta circular (drag & drop).
- Carpetas predeterminadas: Archivos sin organizar, Papelera, Fotos, Vídeos.
- Acciones: Omitir, Deshacer, Ampliar/Reproducir, Mover a SD (Android).
- Crear/editar/eliminar carpetas personalizadas.
- Modo oscuro y personalización de interfaz y animaciones.

## ⚙️ Stack Técnico

- Flutter (stable)
- State management: Riverpod / Provider / Bloc (opcional)
- DB local: `sqflite` o `sembast`
- Plugins principales: `photo_manager`, `permission_handler`, `path_provider`, `file_picker`, `storage_access_framework` (Android), `video_player`

## 📝 Notas Importantes

- En Android soportamos mover archivos a SD usando SAF; en iOS los cambios se hacen mediante PhotoKit (limitaciones nativas).
- Permisos solicitados "just-in-time".

## 📄 Licencia

MIT License
