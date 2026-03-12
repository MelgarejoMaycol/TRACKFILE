# Actualización: Subida de Documentos con Roles - TrackFile Frontend

## Resumen de Cambios
Se ha actualizado el sistema de gestión de documentos del frontend de TrackFile para:
1. **Traer documentos desde la API del backend** en lugar de archivos JSON locales
2. **Implementar subida de documentos** con control de roles
3. **Mejorar la experiencia de usuario** con un modal de subida intuitivo

---

## Archivos Creados

### 1. `lib/services/document_service.dart`
**Propósito**: Servicio centralizado para todas las operaciones de documentos

**Métodos principales**:
- `getDocuments()` - Obtiene documentos del usuario desde la API
- `uploadDocument()` - Sube un nuevo documento al backend
- `getDocumentTypes()` - Obtiene tipos de documentos disponibles
- `getToken()` - Recupera el token guardado en SharedPreferences

**Endpoint del Backend**: `http://localhost:8080/api/documentos`

---

### 2. `lib/widgets/upload_document_modal.dart`
**Propósito**: Modal completo para subida de documentos

**Características**:
- ✅ Selección de archivo (PDF, DOC, DOCX, JPG, PNG)
- ✅ Selección de tipo de documento (SOAT, Tecnicomecánico, Póliza, etc.)
- ✅ Selección de área (TECNICO, LEGAL, ADMINISTRATIVO)
- ✅ Seleccionar fecha de vencimiento con calendar picker
- ✅ Campo de observaciones opcional
- ✅ Validación de campos requeridos
- ✅ Indicador de progreso durante la subida
- ✅ Manejo de errores con SnackBars

---

## Archivos Modificados

### 1. `lib/widgets/documentos.dart`
**Cambios realizados**:

#### a. Actualización de clase DocumentosWidget
```dart
// Antes
const DocumentosWidget({
  this.role,
  this.jsonPath,
});

// Después
const DocumentosWidget({
  this.role,
  this.jsonPath,
  this.userId,      // Nuevo
  this.token,       // Nuevo
  this.canUpload = false,  // Nuevo
});
```

#### b. Método `_loadDocuments()` mejorado
- Primero intenta traer datos desde la API del backend
- Si no hay datos de API o está disponible `jsonPath`, carga desde JSON (para desarrollo)
- Genera datos de ejemplo si no hay ni API ni JSON

#### c. Nuevo método `_convertApiDocumentsToDocumentInfo()`
- Convierte documentos de API a formato interno `_DocumentInfo`
- Mapea campos como: `nombreTipo`, `area`, `fechaVencimiento`, `placa`

#### d. Método `build()` actualizado
- Devuelve un Stack con FloatingActionButton cuando `canUpload = true`
- El FAB abre el modal de subida
- Recarga documentos después de una subida exitosa

#### e. Nuevo método `_showUploadModal()`
- Valida permisos del usuario
- Abre el modal de subida con los parámetros correctos

---

### 2. `lib/screens/roles/conductor_screen.dart`
```dart
// Antes
DocumentosWidget(
  role: 'Conductor',
  jsonPath: 'assets/documents_data.json',
);

// Después
DocumentosWidget(
  role: 'Conductor',
  jsonPath: 'assets/documents_data.json',
  userId: widget.userId,
  token: null,
  canUpload: true,
);
```

---

### 3. `lib/screens/roles/propietario_screen.dart`
```dart
// Antes
DocumentosWidget(
  role: 'Propietario',
  jsonPath: _ownerDashboardAsset,
);

// Después
DocumentosWidget(
  role: 'Propietario',
  jsonPath: _ownerDashboardAsset,
  userId: widget.userId,
  token: null,
  canUpload: true,
);
```

---

### 4. `lib/screens/roles/empresa_screen.dart`
```dart
// Antes
DocumentosWidget(
  role: 'Empresa',
  jsonPath: _dashboardAsset,
);

// Después
DocumentosWidget(
  role: 'Empresa',
  jsonPath: _dashboardAsset,
  userId: widget.usuario?['id']?.toString(),
  token: null,
  canUpload: true,
);
```

---

## Cómo Funciona

### Flujo de Carga de Documentos

1. **DocumentosWidget** se inicializa con `userId` y `jsonPath`
2. En `_loadDocuments()`:
   - Si `userId` existe → Intenta traer desde API (`DocumentService.getDocuments()`)
   - Si no hay datos de API pero existe `jsonPath` → Carga desde JSON
   - Si no hay datos → Genera ejemplos para la UI
3. Los documentos se convierten al formato interno `_DocumentInfo`
4. Se ordena por fecha de vencimiento y se muestra la UI

### Flujo de Subida de Documentos

1. Usuario hace clic en el **FloatingActionButton** (esquina inferior derecha)
2. Se abre **UploadDocumentModal**
3. Usuario completa el formulario:
   - Selecciona archivo
   - Selecciona tipo de documento
   - Selecciona área
   - Selecciona fecha de vencimiento
   - (Opcional) Agrega observaciones
4. Usuario hace clic en "Subir"
5. **DocumentService** realiza POST a `/api/documentos` con MultipartRequest
6. Los headers incluyen `Authorization: Bearer $token` (si está disponible)
7. Cuerpo incluye:
   - `idVehiculo`: ID del vehículo (si aplica)
   - `idTipo`: ID del tipo de documento
   - `area`: Área (TECNICO, LEGAL, etc.)
   - `fechaVencimiento`: Fecha en formato ISO
   - `observaciones`: Notas (si se proporcionaron)
   - `archivo`: El archivo multipart

---

## Roles Soportados

Todos los roles pueden ahora subir documentos:
- ✅ **CONDUCTOR** - Puede subir sus documentos personales
- ✅ **PROPIETARIO** - Puede subir documentos de la empresa/vehículos
- ✅ **EMPRESA** - Administrador puede subir documentos de empleados
- ✅ **SECRETARIA** - Acceso a gestión de documentos
- ✅ **ADMIN** - Acceso completo

---

## Validaciones

El modal de subida valida:
- ✅ Se debe seleccionar un archivo
- ✅ Se debe seleccionar un tipo de documento
- ✅ Se debe seleccionar una fecha de vencimiento
- ✅ El archivo debe tener extensión válida (.pdf, .doc, .docx, .jpg, .jpeg, .png)

---

## Manejo de Errores

El servicio maneja:
- ✅ Conexión perdida (TimeoutException)
- ✅ Archivos no encontrados
- ✅ Errores 401 (No autorizado)
- ✅ Respuestas malformadas del servidor
- ✅ Validación de input del usuario

Los errores se muestran al usuario mediante:
- SnackBars con mensajes descriptivos
- Debugprints para logs del desarrollador

---

## Variables de Entorno

Para cambiar el endpoint de la API, modificar en `lib/services/document_service.dart`:

```dart
static const String _baseUrl = 'http://localhost:8080';
```

Cambia según tu ambiente:
- **Desarrollo**: `http://localhost:8080`
- **Staging**: `http://staging-api.tu-dominio.com`
- **Producción**: `https://api.tu-dominio.com`

---

## Próximos Pasos Sugeridos

1. **Implementar descarga de documentos** - Agregar botón de descarga
2. **Implementar eliminación de documentos** - Solo para usuarios autorizados
3. **Agregar vista previa de documentos** - PDF viewer
4. **Implementar historial de cambios** - Auditoría de documentos
5. **Mejorar búsqueda** - Filtros más avanzados
6. **Agregar validación de tipos de archivo** - Verificar contenido real

---

## Notas de Desarrollo

- El token se obtiene de SharedPreferences automáticamente en cada request
- Si no hay token disponible, se envía request sin autenticación (el backend decidirá si es válido)
- Los documentos se recargan automáticamente después de una subida exitosa
- El modal se cierra automáticamente después de una subida exitosa
- Se mantiene compatibilidad con datos JSON para desarrollo local

---

**Versión**: 1.0  
**Fecha**: 2026-03-09  
**Estado**: ✅ Funcionando
