# CoreFix Pro — Sistema de reporte de fallas
AUTO MANUFACTURAS BRAKE, S.A. DE C.V. · PHP + MySQL (XAMPP) · Versión 5

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

Usuarios del panel (cámbielos al entrar):
- `admin` / `Admin#Brake2026`  · NIP: **2026**
- `marco.enciso` / `Mtto#Brake2026`  · NIP: **0837**
- `consulta` / `Usuario#2026`  · NIP: **1234**

**NIP de cada trabajador:** el número de tarjeta rellenado a 4 dígitos
(ej. tarjeta `837` → NIP `0837`, tarjeta `2` → NIP `0002`).
La v5 crea una cuenta en `usuarios` (rol *usuario*) para cada trabajador y le
asigna ese NIP. Así cualquiera puede firmar al reportar, aunque no entre al panel.

## Actualizar una instalación existente (v4 → v5)

Respalde la base, ejecute `actualizacion_v5.sql` en phpMyAdmin (antes `actualizacion_v4.sql` y `actualizacion_v3.sql`
si nunca las corrió) y copie los archivos encima. Pulse **Ctrl + F5**.

### Novedades de la v5
- **NIP y firmas electrónicas:** cada bloque de firma tiene **Cargar firma**; pide el NIP de 4 dígitos,
  el servidor lo valida (solo hash, únicos) y coloca la firma guardada de esa persona.
  En `index.php` solo se firma «Reportó» con el NIP de quien reporta (usuario ligado a su tarjeta).
- **NIP para todos:** se crea un usuario ligado a cada trabajador y se le asigna NIP (tarjeta a 4 dígitos).
- **Administrador:** menú **Firmas** y NIP en **Usuarios**. Cambiar/borrar NIP pide el NIP del admin.
- **Foto de perfil**, buscador completo, bloqueo tras 8 NIP incorrectos por IP.
- Se quitó la leyenda del nombre debajo de cada bloque de firma (era repetitiva).

## Estructura

```
brake-sistema/
├── index.php  login.php  logout.php  dashboard.php  imprimir.php
├── brake_sistema.sql  actualizacion_v3.sql  actualizacion_v4.sql  actualizacion_v5.sql
├── config/database.php          Conexión PDO y constantes
├── includes/auth.php, mtto.php, firmas.php  Sesiones, CSRF, roles, reglas de órdenes, NIP y firmas
├── api/publico.php, panel.php   Endpoints (formulario público / panel)
└── assets/ css (mtto, panel) · js (mtto-comun, publico, panel) · logo · vendor/xlsx (importar Excel)
```
