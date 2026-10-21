# TrackFile — Gestión documental y operativa

[![Flutter CI](https://github.com/MelgarejoMaycol/TRACKFILE/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/MelgarejoMaycol/TRACKFILE/actions/workflows/flutter-ci.yml)
[![Backend CI](https://github.com/MelgarejoMaycol/BackTrackfile/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/MelgarejoMaycol/BackTrackfile/actions/workflows/backend-ci.yml)

Proyecto de grado desarrollado para facilitar el seguimiento de documentos y procesos operativos de empresas de transporte.

**Aplicación:** https://trackfile.vercel.app/  
**Frontend:** Flutter y Dart  
**Backend:** [Java 17, Spring Boot 3, Spring Security y PostgreSQL](https://github.com/MelgarejoMaycol/BackTrackfile)

## Objetivo y alcance

TrackFile reúne gestión de usuarios y empresas, vehículos, conductores, propietarios, documentos, solicitudes, mantenimiento y notificaciones. La solución separa el cliente Flutter de una API REST con persistencia en PostgreSQL.

## Mi participación

- Análisis de necesidades y diseño de flujos de consulta y seguimiento documental.
- Desarrollo e integración de interfaces, servicios y persistencia de datos.
- Trabajo con autenticación, archivos y funcionalidades operativas.
- Implementación como proyecto académico; no se presenta como experiencia laboral contratada.

## Arquitectura

```text
Flutter / Dart (cliente)
     │ HTTP / JSON
     ▼
Spring Boot (API REST)
     │
     ▼
PostgreSQL (datos)
```

El backend incluye Spring Security, JWT, Spring Data JPA, validación de entrada, gestión de archivos con Cloudinary y notificaciones por correo. Consulta su [README](https://github.com/MelgarejoMaycol/BackTrackfile#readme) para información de instalación y configuración.

## Ejecutar el cliente

Requiere Flutter SDK y un dispositivo o emulador compatible. Los valores concretos de entorno y el endpoint de la API deben configurarse de acuerdo con la aplicación.

```bash
git clone https://github.com/MelgarejoMaycol/TRACKFILE.git
cd TRACKFILE
flutter pub get
flutter run
```

Para revisar la calidad del cliente:
```bash
flutter analyze
flutter test
flutter build web --release
```
Los tres comandos forman parte del CI automatizado. El backend mantiene una verificación Maven independiente.

**Nota sobre artefactos:** el historial de este repositorio todavía contiene archivos de `build/` y APK generados por compilaciones anteriores. Se ha añadido una regla para no incorporar nuevos artefactos; la limpieza de los ya versionados requiere migrar primero el despliegue web a compilación desde fuentes para evitar interrumpirlo.

## Revisión técnica

- [Código del frontend](https://github.com/MelgarejoMaycol/TRACKFILE)
- [Código y documentación de la API](https://github.com/MelgarejoMaycol/BackTrackfile)
- [Portafolio profesional](https://melgarejomaycol.vercel.app/)

**Autor:** Maycol Melgarejo — Unidades Tecnológicas de Santander.
