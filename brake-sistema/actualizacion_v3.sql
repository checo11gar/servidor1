-- =====================================================================
--  ACTUALIZACIÓN V3 — Sistema de mantenimiento (Paquete de actualizaciones 2)
--  phpMyAdmin → base brake_sistema → pestaña "SQL" → pegar todo → Continuar.
--  No borra nada. Se puede ejecutar más de una vez. Compatible con MariaDB (XAMPP).
-- =====================================================================
USE brake_sistema;

-- ---------------------------------------------------------------------
-- Trabajadores: todos los que pueden reportar fallas con su número de tarjeta.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trabajadores (
  id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tarjeta  VARCHAR(20)  NOT NULL,
  nombre   VARCHAR(120) NOT NULL,
  area     VARCHAR(80)  NULL,
  puesto   VARCHAR(80)  NULL,
  activo   TINYINT(1)   NOT NULL DEFAULT 1,
  creado   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tarjeta (tarjeta),
  KEY idx_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Acceso al panel: un trabajador puede tener además usuario/contraseña.
-- 'tecnico' entra al panel y atiende órdenes; 'administrador' además gestiona usuarios.
ALTER TABLE usuarios
  MODIFY rol ENUM('administrador','tecnico','usuario') NOT NULL DEFAULT 'usuario';
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS trabajador_id INT UNSIGNED NULL AFTER rol;
ALTER TABLE usuarios ADD UNIQUE KEY IF NOT EXISTS uq_usr_trab (trabajador_id);
ALTER TABLE usuarios
  ADD FOREIGN KEY IF NOT EXISTS fk_usr_trab (trabajador_id)
    REFERENCES trabajadores (id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------
-- Equipos (computadoras, impresoras, máquinas…). Pueden asignarse a un trabajador.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS equipos (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  identificador  VARCHAR(40)  NOT NULL,
  nombre         VARCHAR(120) NOT NULL,
  tipo           VARCHAR(40)  NOT NULL DEFAULT 'Computadora',
  marca          VARCHAR(60)  NULL,
  modelo         VARCHAR(60)  NULL,
  serie          VARCHAR(80)  NULL,
  area           VARCHAR(80)  NULL,
  trabajador_id  INT UNSIGNED NULL,
  notas          TEXT NULL,
  activo         TINYINT(1)   NOT NULL DEFAULT 1,
  creado         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_identificador (identificador),
  KEY idx_trab (trabajador_id),
  CONSTRAINT fk_eq_trab FOREIGN KEY (trabajador_id)
    REFERENCES trabajadores (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Órdenes de mantenimiento correctivo (réplica digital del formato en papel).
-- Folio automático: OMC-00001, OMC-00002, …
-- Estados: pendiente (recién reportada) → verificada → en_proceso → finalizada
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ordenes_correctivas (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  folio              VARCHAR(20)  NULL,
  token              CHAR(32)     NOT NULL,
  estado             ENUM('pendiente','verificada','en_proceso','finalizada') NOT NULL DEFAULT 'pendiente',
  tipo_falla         ENUM('hardware','software') NOT NULL DEFAULT 'hardware',
  prioridad          ENUM('baja','media','alta','critica') NOT NULL DEFAULT 'media',
  area               VARCHAR(80)  NULL,
  reporta_id         INT UNSIGNED NULL,
  reporta_tarjeta    VARCHAR(20)  NOT NULL,
  reporta_nombre     VARCHAR(120) NOT NULL,
  equipo_id          INT UNSIGNED NULL,
  equipo_ident       VARCHAR(60)  NULL,
  fecha_paro         DATETIME     NOT NULL,
  fecha_ejecucion    DATETIME     NULL,
  fecha_entrega      DATETIME     NULL,
  reporte            TEXT         NOT NULL,
  descripcion        TEXT         NULL,
  ejecuto_id         INT UNSIGNED NULL,
  ejecuto_nombre     VARCHAR(120) NULL,
  recibio_nombre     VARCHAR(120) NULL,
  firma_reporto      MEDIUMTEXT   NULL,
  firma_ejecuto      MEDIUMTEXT   NULL,
  firma_recibio      MEDIUMTEXT   NULL,
  fecha_firma_reporto DATE        NULL,
  fecha_firma_ejecuto DATE        NULL,
  fecha_firma_recibio DATE        NULL,
  creado             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  finalizado         DATETIME     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_folio (folio),
  KEY idx_estado (estado),
  KEY idx_creado (creado),
  KEY idx_equipo (equipo_id),
  KEY idx_reporta (reporta_id),
  CONSTRAINT fk_oc_trab FOREIGN KEY (reporta_id) REFERENCES trabajadores (id) ON DELETE SET NULL,
  CONSTRAINT fk_oc_eq   FOREIGN KEY (equipo_id)  REFERENCES equipos (id)      ON DELETE SET NULL,
  CONSTRAINT fk_oc_usr  FOREIGN KEY (ejecuto_id) REFERENCES usuarios (id)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bitácora de cambios de estado (de aquí sale el tiempo medio de cierre).
CREATE TABLE IF NOT EXISTS ordenes_historial (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  orden_id    INT UNSIGNED NOT NULL,
  estado      VARCHAR(20)  NOT NULL,
  usuario_id  INT UNSIGNED NULL,
  nota        VARCHAR(255) NULL,
  fecha       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_orden (orden_id),
  CONSTRAINT fk_oh_orden FOREIGN KEY (orden_id) REFERENCES ordenes_correctivas (id) ON DELETE CASCADE,
  CONSTRAINT fk_oh_usr   FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Mantenimiento preventivo (calendario). Al marcar "realizado" una tarea
-- periódica, el sistema programa la siguiente automáticamente.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS preventivos (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  titulo          VARCHAR(150) NOT NULL,
  equipo_id       INT UNSIGNED NULL,
  fecha           DATE         NOT NULL,
  frecuencia      ENUM('unica','semanal','mensual','bimestral','trimestral','semestral','anual') NOT NULL DEFAULT 'unica',
  estado          ENUM('programado','realizado','cancelado') NOT NULL DEFAULT 'programado',
  responsable_id  INT UNSIGNED NULL,
  notas           TEXT NULL,
  realizado_en    DATETIME NULL,
  creado          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_fecha (fecha),
  CONSTRAINT fk_pv_eq  FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE SET NULL,
  CONSTRAINT fk_pv_usr FOREIGN KEY (responsable_id) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
