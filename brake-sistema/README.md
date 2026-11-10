# CoreFix Pro — Sistema de reporte de fallas
AUTO MANUFACTURAS BRAKE, S.A. DE C.V. · PHP + MySQL (XAMPP) · Versión 4

## Cómo funciona

- **`index.php`** (página de entrada): el trabajador escribe su **número de tarjeta** en *Responsable*, elige el equipo y llena la
  *Orden de mantenimiento correctivo* (hardware o software, firma con mouse o dedo). No necesita contraseña.
  Folio automático `OMC-00001`, `OMC-00002`… con opción de **imprimir / guardar en PDF** (`imprimir.php`).
- **`login.php`**: acceso solo para administradores y técnicos. Abre el panel (`dashboard.php`).
- **Panel** (`dashboard.php`): resumen, órdenes correctivas (*Pendiente → Verificada → En proceso → Finalizada*),
  calendario de preventivos, equipos, usuarios/trabajadores, exportar a CSV, formato en blanco.

## Instalación (XAMPP)

1. Copie la carpeta `brake-sistema` a `C:\xampp\htdocs\`.
2. phpMyAdmin → **Importar** → `brake_sistema.sql` (incluye trabajadores, equipos y preventivos).
3. Si MySQL tiene contraseña para `root`, edítela en `config/database.php` (`DB_PASS`).
4. Abra `http://localhost/brake-sistema/`.

Usuarios iniciales (cámbielos al entrar): `admin` / `Admin#Brake2026` y `marco.enciso` / `Mtto#Brake2026`.

## Actualizar una instalación existente (v3 → v4)

Respalde la base, ejecute `actualizacion_v4.sql` en phpMyAdmin (antes `actualizacion_v3.sql` si nunca la corrió)
y copie los archivos encima. Pulse **Ctrl + F5**.

## Estructura

```
brake-sistema/
├── index.php  login.php  logout.php  dashboard.php  imprimir.php
├── brake_sistema.sql  actualizacion_v3.sql  actualizacion_v4.sql
├── config/database.php          Conexión PDO y constantes
├── includes/auth.php, mtto.php  Sesiones, CSRF, roles, reglas de órdenes
├── api/publico.php, panel.php   Endpoints (formulario público / panel)
└── assets/ css (mtto, panel) · js (mtto-comun, publico, panel) · logo · vendor/xlsx (importar Excel)
```
