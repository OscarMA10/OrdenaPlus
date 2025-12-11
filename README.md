# Ordena+ 📁📸

Ordena+ es una aplicación móvil Android diseñada para **clasificar fotos y vídeos de forma rápida y visual** mediante un sistema eficiente de álbumes y "Seleccionar y Mover".

## 🚀 Características

- **Organización Visual**: Selecciona tus fotos y muévelas a cualquier álbum con un par de toques.
- **Gestión Inteligente**:
  - Detección automática de archivos.
  - Indexación rápida con caché de miniaturas optimizada.
  - Soporte para Almacenamiento Interno y Tarjetas SD.
- **Visualización Potente**:
  - Vista de Galería fluida (configurable).
  - Vista de Álbumes en Cuadrícula o Lista (configurable).
  - Búsqueda de Álbumes.
  - Reproductor de video y zoom de imágenes integrado.
- **Herramientas**:
  - Selección múltiple y eliminación por lotes.
  - Papelera de reciclaje con opción de borrado permanente.
  - Personalización de vistas.

## ⚙️ Arquitectura y Stack

El proyecto utiliza una arquitectura sólida y mantenible:

- **Framework**: Flutter (Dart).
- **Gestión de Estado**: Riverpod 2.0 (Code Generation + Providers).
- **Base de Datos Local**: SQFLite (persistencia de metadatos de medios).
- **Navegación**: GoRouter (basada en URLs/paginación).
- **Acceso a Medios**:
  - `photo_manager`: Acceso nativo optimizado a la galería.
  - `external_path`: Gestión de rutas de almacenamiento en Android.
  - `sqflite`: Caché local para velocidad extrema.

## 📂 Estructura del Proyecto

El código fuente de la aplicación se encuentra en el directorio `ordena_plus/`.

---

© 2025 Ordena+ Team. MIT License.
