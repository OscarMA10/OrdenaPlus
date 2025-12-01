# Ordena+ - MVP

## Descripción General

Aplicación móvil cuyo objetivo es facilitar la **clasificación rápida** de fotos y vídeos del dispositivo mediante una interfaz basada en un **sistema de arrastrar y soltar** (drag-and-drop) hacia carpetas creadas por el usuario. La app actúa como un organizador visual centrado en rapidez, simplicidad y orden progresivo.

Compatible con **Android** (prioritario) y **iOS** (dependiendo de limitaciones de acceso a archivos).

## Objetivo del MVP

Desarrollar una aplicación capaz de:

1. **Leer y mostrar** archivos multimedia (imágenes y vídeos) del dispositivo.
2. **Detectar nuevos archivos** y colocarlos automáticamente en una carpeta por defecto ("Archivos sin organizar").
3. **Permitir organizarlos** arrastrándolos a carpetas creadas por el usuario mediante una interfaz tipo **ruleta circular**.
4. **Mantener un flujo de trabajo rápido**: clasificar, omitir, deshacer y previsualizar.

## Plataformas

- **Android** (MVP obligatorio)
- **iOS** (opcional si las limitaciones de acceso a archivos lo permiten; usar PhotoKit)

## Permisos

### Android:

- `READ_MEDIA_IMAGES`
- `READ_MEDIA_VIDEO`
- Acceso a almacenamiento interno y externo (SD) mediante `MediaStore` y `DocumentFile`
- Solicitud gradual (just-in-time)

### iOS:

- Permisos de `PHPhotoLibrary` (`.readWrite` solo cuando sea necesario)

## Arquitectura

- Cache de miniaturas: API del sistema + caché propia LRU
- Escaneo de archivos: **indexación incremental** en segundo plano

## Funcionalidades Principales del MVP

### 1. Escaneo e Indexación

- Lectura inicial del catálogo multimedia del sistema.
- Indexación progresiva con barra de progreso.
- Nuevas fotos/vídeos detectados → se añaden automáticamente a **"Archivos sin organizar"**.
- Orden de visualización: primero los **más antiguos**, luego los más recientes.

### 2. Sistema de Carpetas

Carpetas iniciales por defecto:

- **Archivos sin organizar** (no editable / no eliminable)
- **Papelera** (no editable / no eliminable)
- **Fotos** (editable)
- **Vídeos** (editable)

El usuario puede:

- Crear nuevas carpetas
- Editar nombre e icono
- Eliminar carpetas propias
- Mover carpetas a SD (si el sistema lo permite)

### 3. Clasificación mediante ruleta circular

Pantalla principal:

- Se muestra 1 archivo multimedia a la vez (foto o vídeo).
- Alrededor del archivo aparece una **rueda** con todas las carpetas.
- El usuario arrastra la foto/vídeo hacia una carpeta → el archivo se mueve físicamente en el sistema de archivos.
- Animación visual de movimiento + confirmación breve.

### 4. Acciones Rápidas

- **Atrás / Deshacer**: revierte la última acción.
- **Omitir**: pasa al siguiente archivo sin clasificar.
- **Ampliar**: clic sobre la miniatura → abre visor de imagen o reproductor de vídeo.

### 5. Gestión de Archivos

- Mover archivos entre memoria interna y SD (si el sistema permite escritura).
- Papelera con opción "Vaciar papelera".
- Acciones por lote desde cualquier carpeta: seleccionar varios y mover/eliminar.

### 6. Estadísticas Básicas

- Porcentaje de archivos organizados
- Número de archivos organizados hoy

### 7. Personalización Básica

- Modo claro/oscuro
- Tamaño del carrusel / ruleta
- Tamaño de miniaturas
- Activar/desactivar animaciones

## Flujo Principal del Usuario

1. Primera apertura → permisos → indexación inicial.
2. Se abre pantalla de clasificación mostrando el archivo más antiguo de “Archivos sin organizar”.
3. El usuario arrastra el archivo a una carpeta → pasa automáticamente al siguiente.
4. Si pulsa “Omitir” → pasa al siguiente sin mover.
5. Si pulsa “Atrás” → se restaura la acción anterior.
6. Proceso continuo hasta que el usuario deja la app o no queden archivos por organizar.

## Estructura de Datos (Planteada pero NO Final)

`MediaItem`:

- id
- uri
- tipo (foto/vídeo)
- fecha creación
- ubicación actual
- carpeta asignada (id carpeta)

`Folder`:

- id
- nombre
- tipo (default/custom)
- ruta real en almacenamiento

## Requisitos Técnicos Clave

- Uso de `MediaStore` para compatibilidad con Android 10+.
- Uso de SAF (Storage Access Framework) si se requiere escribir en SD.
- Miniaturas generadas bajo demanda + caché LRU.
- Animaciones fluidas en la ruleta (canvas + physics o motor simple).
- Controlador de deshacer con pila de acciones.
