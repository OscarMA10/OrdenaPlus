# Ordena+ - SRS

## 1. Introducción

Ordena+ es una aplicación móvil cuyo propósito es permitir al usuario **organizar de manera rápida y eficiente** sus fotos y vídeos mediante una interfaz de clasificación por arrastre.

### 1.1 Objetivos

- Clasificar medios de forma intuitiva y veloz.
- Permitir gestión de carpetas personalizadas.
- Detectar y mostrar elementos sin organizar.
- Integrarse de forma nativa con los sistemas Android/iOS.

### 1.2 Público Objetivo

Usuarios con grandes cantidades de fotos/vídeos que desean ordenarlos fácilmente.

## 2. Alcance del Sistema

El MVP consiste en:

- Clasificación uno a uno con ruleta circular.
- Gestión básica de carpetas.
- Acciones de deshacer y omitir.
- Vista previa y reproducción.
- Soporte a memoria interna y SD (Android).

## 3. Requisitos Funcionales

### RF01 - Acceso a la Galería

La app podrá leer fotos y vídeos desde:

- Memoria Interna
- Tarjetas SD
- Álbumes del Sistema

### RF02 - Carpetas Predeterminadas

- Archivos sin organizar (no editable)
- Papelera (no editable)
- Fotos (editable)
- Vídeos (editable)

### RF03 - Clasificación por Arrastre

El usuario arrastra la miniatura hacia una carpeta de la ruleta.

### RF04 - Detección de Nuevos Archivos

Todo archivo nuevo se añade automáticamente a "Archivos sin organizar".

### RF05 - Orden de Clasificación

Se mostrarán primero los archivos más antiguos.

### RF06 - Acciones Adicionales

- Omitir
- Atrás (deshacer)
- Eliminar → Papelera
- Ampliar / Reproducir

### RF07 - Gestión de Carpetas

Crear/editar/eliminar carpetas personalizadas.

## 4. Requisitos No Funcionales

### RNF01 - Rendimiento

- Indexación incremental para no bloquear la app.

### RNF02 - Usabilidad

- Gestos suaves
- Interfaz minimalista

### RNF03 - Seguridad

- Solo permisos necesarios solicitados en tiempo de uso.

### RNF04 - Portabilidad

- Android prioridad
- iOS compatible según restricciones

## 5. Riesgos

- Limitaciones de PhotoKit para mover archivos.
- Acceso a SD muy dependiente del fabricante.

## 6. Notas importantes sobre permisos y limitaciones

- **Android**: pedir permisos `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` (según API), y usar SAF para escritura en SD. Implementar `just-in-time`.
- **iOS**: usar PhotoKit vía `photo_manager`. iOS puede impedir mover físicamente archivos fuera del sandbox; en su lugar, se usarán álbumes y copias dentro del container del app o manipulación de assets con PhotoKit (solicitar `PHPhotoLibrary` permisos).
- **Performance**: operaciones de I/O grandes deben correr en isolates / background (Flutter compute) y usar paginación.
