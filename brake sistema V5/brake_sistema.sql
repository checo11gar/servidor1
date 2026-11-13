-- =====================================================================
--  AUTO MANUFACTURAS BRAKE, S.A. DE C.V.  -  Base de datos del sistema
--  Importar en phpMyAdmin (pestaña "Importar") o pegar en la pestaña "SQL".
-- =====================================================================

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS brake_sistema
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE brake_sistema;

-- ---------------------------------------------------------------------
-- Usuarios
-- rol: 'administrador' | 'tecnico' (panel de mantenimiento) | 'usuario'
-- password: se guarda con password_hash() y se verifica con password_verify()
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre    VARCHAR(120) NOT NULL,
  usuario   VARCHAR(50)  NOT NULL,
  password  VARCHAR(255) NOT NULL,
  rol       ENUM('administrador','usuario') NOT NULL DEFAULT 'usuario',
  activo    TINYINT(1)   NOT NULL DEFAULT 1,
  creado    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_usuario (usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Usuarios iniciales (CAMBIAR LAS CONTRASEÑAS después del primer acceso)
--   administrador:  usuario = admin     contraseña = Admin#Brake2026
--   usuario normal: usuario = consulta  contraseña = Usuario#2026
-- Los valores de "password" son hashes generados con password_hash().
-- ---------------------------------------------------------------------
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol) VALUES
('Administrador del sistema', 'admin',
 '$2y$10$iNNEv7o.91xGCB6F7grRyOgWmO2t8L8nGWnZ/JZJERNUi6/y.2EiS', 'administrador'),
('Usuario de consulta', 'consulta',
 '$2y$10$6n3jTZOjWclZL1fg.Qz.SeJJFrQDLWNpmvojtLASbXIhOUjWZtbsa', 'usuario');


-- =====================================================================
--  Módulo de mantenimiento (v3) incluido para instalaciones nuevas
-- =====================================================================

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


-- =====================================================================
--  Incluye ACTUALIZACIÓN V4 (datos de trabajadores y equipos)
-- =====================================================================
-- =====================================================================
--  ACTUALIZACIÓN V4 — Datos reales + campos de la lista maestra de equipo de cómputo
--  phpMyAdmin → base brake_sistema → pestaña "SQL" → pegar todo → Continuar.
--  Requiere haber ejecutado antes actualizacion_v3.sql (o tener brake_sistema.sql nuevo).
--  No borra nada. Se puede ejecutar más de una vez (actualiza los mismos registros).
-- =====================================================================
SET NAMES utf8mb4;
USE brake_sistema;

-- ---------------------------------------------------------------------
-- 1) Equipos: columnas de la "Lista maestra equipo de cómputo"
-- ---------------------------------------------------------------------
ALTER TABLE equipos
  ADD COLUMN IF NOT EXISTS responsable      VARCHAR(120) NULL AFTER area,
  ADD COLUMN IF NOT EXISTS nombre_red       VARCHAR(80)  NULL AFTER serie,
  ADD COLUMN IF NOT EXISTS ip               VARCHAR(60)  NULL AFTER nombre_red,
  ADD COLUMN IF NOT EXISTS hardware         TEXT         NULL AFTER ip,
  ADD COLUMN IF NOT EXISTS monitor          VARCHAR(255) NULL AFTER hardware,
  ADD COLUMN IF NOT EXISTS perifericos      TEXT         NULL AFTER monitor,
  ADD COLUMN IF NOT EXISTS nivel_exposicion VARCHAR(20)  NULL AFTER perifericos,
  ADD COLUMN IF NOT EXISTS estatus          VARCHAR(30)  NULL AFTER nivel_exposicion,
  ADD COLUMN IF NOT EXISTS frecuencia_mtto  VARCHAR(20)  NULL AFTER estatus,
  ADD COLUMN IF NOT EXISTS ultimo_mtto      DATE         NULL AFTER frecuencia_mtto,
  ADD COLUMN IF NOT EXISTS proximo_mtto     DATE         NULL AFTER ultimo_mtto;
ALTER TABLE equipos MODIFY tipo VARCHAR(60) NOT NULL DEFAULT 'Computadora';
ALTER TABLE equipos ADD KEY IF NOT EXISTS idx_area (area);

-- ---------------------------------------------------------------------
-- 2) Trabajadores (145) — archivo trabajadores.xlsx
--    El área se tomó de la lista de equipos cuando el responsable se pudo identificar.
-- ---------------------------------------------------------------------
INSERT INTO trabajadores (tarjeta, nombre, area, activo) VALUES
  ('2', 'RODOLFO REAL MORALES', NULL, 1),
  ('3', 'JAIME SALINAS GONZALEZ', NULL, 1),
  ('56', 'JORGE RODRIGUEZ MOTA', NULL, 1),
  ('124', 'SUSANA DIANA CASASOLA SANDOVAL', NULL, 1),
  ('141', 'ANA LILIA GARAY CABALLERO', NULL, 1),
  ('335', 'FANNY ROSALIA SALAS ANGUIANO', NULL, 1),
  ('348', 'MARIA INES ESTRADA CASASOLA', NULL, 1),
  ('350', 'ROSICELA ESTRADA PEREZ', NULL, 1),
  ('423', 'ANA LIDIA MENDOZA LEMUS', NULL, 1),
  ('434', 'ENRIQUE GUTIERREZ ORTIZ', NULL, 1),
  ('445', 'ADRIANA ESPINOZA CERON', NULL, 1),
  ('461', 'ALBERTO GARCIA MORALES', NULL, 1),
  ('465', 'VERONICA MEZA MARTINEZ', 'RRHH', 1),
  ('476', 'GLORIA MARTINEZ ORTEGA', NULL, 1),
  ('484', 'DIONICIA SALINAS HERNANDEZ', NULL, 1),
  ('524', 'IGNACIO PEREZ VILLANUEVA', NULL, 1),
  ('542', 'ESMERALDA MEZA MARTINEZ', 'Gerencia', 1),
  ('543', 'EDUARDO MARTINEZ NAVARRO', NULL, 1),
  ('552', 'JUDITH MARIBEL SALDAÑA CORONA', NULL, 1),
  ('563', 'CLAUDIA DOLORES SANTOS MARTINEZ', NULL, 1),
  ('567', 'JOSE LUIS LOPEZ PASCUAL', NULL, 1),
  ('570', 'OCTAVIO GABRIEL AOKI CORONA', 'Planeacion', 1),
  ('580', 'ALEJANDRA RESENDIZ LOPEZ', NULL, 1),
  ('581', 'MARIA NATALIA GARCIA GARCIA', 'Calidad', 1),
  ('584', 'ADRIAN REYES RAMIREZ', NULL, 1),
  ('585', 'FERNANDO CORONA GOMEZ', NULL, 1),
  ('586', 'JUAN CARLOS LICONA GABRIEL', NULL, 1),
  ('587', 'ALONDRA OLGA RIVERO AGUILAR', 'Produccion', 1),
  ('597', 'RUTILO REYES RAMIREZ', NULL, 1),
  ('607', 'MARIA DE LA LUZ GARCIA FLORES', NULL, 1),
  ('622', 'JESUS CASTELAN LUNA', NULL, 1),
  ('644', 'JONATHAN JESUS GARCIA FLORES', NULL, 1),
  ('647', 'NAYELI VANESSA SALAZAR DURAN', NULL, 1),
  ('653', 'MARTHA ALICIA MARQUEZ RAMIREZ', NULL, 1),
  ('655', 'ELVIRA PAZ RODRIGUEZ TENORIO', NULL, 1),
  ('709', 'ANA IVON GARCIA FLORES', 'Produccion', 1),
  ('726', 'VICENTE ROBERTO CRUZ GONZALEZ', 'Almacen', 1),
  ('740', 'ALFONSO REYES MARTINEZ', NULL, 1),
  ('834', 'ANTONIO BASILIO FRANCISCO', NULL, 1),
  ('837', 'MARCO ANTONIO ENCISO GARCIA', 'Sistemas', 1),
  ('844', 'BRENDA PAOLA HERNANDEZ HINOJOSA', NULL, 1),
  ('852', 'MARCELA VALENTIN CAYETANO', NULL, 1),
  ('866', 'JUANA CERON LAZARO', NULL, 1),
  ('867', 'VERONICA MARTINEZ HERNANDEZ', NULL, 1),
  ('879', 'SANDRA MANZANO MONROY', NULL, 1),
  ('893', 'BLANCA VIANEY HERNANDEZ MARTINEZ', NULL, 1),
  ('898', 'ESTHELA GARCIA GARCIA', NULL, 1),
  ('899', 'ISIDRA LOPEZ LOPEZ', NULL, 1),
  ('922', 'MARCOS RIVERA SALAS', 'Almacen', 1),
  ('944', 'FABIOLA VALDES SIERRA', NULL, 1),
  ('991', 'LUCIANA MONTALVO PEREZ', NULL, 1),
  ('1002', 'EDGAR OSVALDO DIAZ MORALES', NULL, 1),
  ('1034', 'YERENA MIRIAM ESTRADA HERNANDEZ', 'Almacen', 1),
  ('1048', 'DIANA HERNANDEZ GARCIA', NULL, 1),
  ('1062', 'WENDY LESLIE MENDEZ RIOS', 'Compras', 1),
  ('1066', 'SANDRA YADIRA MIJANGOS NAJERA', NULL, 1),
  ('1068', 'PERLA SUHEY RODRIGUEZ CRUZ', NULL, 1),
  ('1073', 'LETICIA MENDIOLA DELGADO', NULL, 1),
  ('1104', 'MICAELA GUERRA ANGELES', NULL, 1),
  ('1110', 'MARISOL MENDOZA VILLANUEVA', NULL, 1),
  ('1157', 'CARMEN KARINA SANCHEZ ONTIVEROS', NULL, 1),
  ('1164', 'LESLIE JIMENEZ AVILA', NULL, 1),
  ('1188', 'ALAN JEOVANNY MONTIEL VELAZQUEZ', 'Laboratorio', 1),
  ('1205', 'ZAIRA MARIA ALEMAN ARIAS', NULL, 1),
  ('1244', 'JESUS ALAVEZ GARCIA', NULL, 1),
  ('1246', 'LEYDI GOMEZ JIMENEZ', NULL, 1),
  ('1247', 'BEATRIZ ADRIANA BECERRA FLORES', NULL, 1),
  ('1264', 'GABRIEL GARCIA GARCIA', NULL, 1),
  ('1267', 'JUDITH TIERRAFRIA PINEDA', NULL, 1),
  ('1276', 'VALERIA FLORES MARTINEZ', 'Ing Producto', 1),
  ('1293', 'ERNESTO RESENDIZ LOPEZ', NULL, 1),
  ('1308', 'ROSA GARCIA ALCANTAR', NULL, 1),
  ('1309', 'SUSANA TOLEDO LOPEZ', NULL, 1),
  ('1338', 'YESICCA GALINDO GUTIERREZ', NULL, 1),
  ('1344', 'MA. DE LOURDES BERNALDA GARCIA GARCIA', NULL, 1),
  ('1351', 'BENJAMIN LEANDRO HERNANDEZ RAMIREZ', NULL, 1),
  ('1354', 'DAMARIS CHAVEZ MARQUEZ', NULL, 1),
  ('1360', 'JADIRA GALINDO GUTIERREZ', NULL, 1),
  ('1366', 'SALOME DIAZ ORIZONTE', NULL, 1),
  ('1370', 'ANA KAREN PINEDA RAMIREZ', NULL, 1),
  ('1374', 'MAGDALENA SILVA VELAZQUEZ', NULL, 1),
  ('1378', 'JONATHAN FRANCISCO ALARCON BERNAL', NULL, 1),
  ('1386', 'LUZ NAYDELIN BARRIOS ANAYA', 'EHS', 1),
  ('1394', 'DAYANA YOSELIN ULIN LAIZA', NULL, 1),
  ('1395', 'MIRANDA ADALI JUAREZ CRUZ', 'Bodega', 1),
  ('1396', 'DIANA EDITH GARZON AMARO', NULL, 1),
  ('1397', 'VANESSA SANCHEZ GONZALEZ', NULL, 1),
  ('1400', 'MONSERRATH FRAGOSO SEGUNDO', NULL, 1),
  ('1401', 'EDUARDO TORRES CASTILLO', 'Ing Producto', 1),
  ('1403', 'DIANA RAMIREZ SINTO', NULL, 1),
  ('1409', 'ANAYELY CARBAJAL CRUZ', NULL, 1),
  ('1412', 'GUADALUPE MARTINEZ ORTEGA', NULL, 1),
  ('1414', 'BRYAN JOSUE ARELLANO HERNANDEZ', NULL, 1),
  ('1415', 'CESAR FABIAN ADAME VALDES', NULL, 1),
  ('1416', 'HIDDEKEL LUIS AZUL GACHUZ CORTES', NULL, 1),
  ('1418', 'ALEJANDRA GARCIA MONROY', NULL, 1),
  ('1426', 'JAVIER BACILIO FRANCISCO', NULL, 1),
  ('1428', 'ALEXIS ARIEL CRUZ VAZQUEZ', NULL, 1),
  ('1429', 'BERENICE SOLIS HERNANDEZ', NULL, 1),
  ('1430', 'DAVID ISMAEL SALINAS GUERRA', NULL, 1),
  ('1434', 'PAULA LETICIA MARTINEZ MARTINEZ', NULL, 1),
  ('1435', 'CARLOS IVAN AVALOS GARCIA', NULL, 1),
  ('1436', 'NORMA LIDIA VICENCIO CRUZ', NULL, 1),
  ('1441', 'HAYDEE PEREZ ROMO', NULL, 1),
  ('1446', 'CRISTINA GARCIA GARCIA', NULL, 1),
  ('1449', 'MARIA LUISA VAZQUEZ CASASOLA', NULL, 1),
  ('1451', 'FLORA CORONA MENDOZA', NULL, 1),
  ('1452', 'JESUS ALFONSO HERNANDEZ RAMIREZ', NULL, 1),
  ('1458', 'JESUS MAURICIO CRUZ LUGO', NULL, 1),
  ('1461', 'DALIA IVON VARGAS CASASOLA', NULL, 1),
  ('1463', 'LETICIA VALENCIA TEMOXTLE', NULL, 1),
  ('1467', 'LUIS ENRIQUE GOMEZ MARTINEZ', NULL, 1),
  ('1471', 'CLAUDIA ISABEL MARTINEZ COSME', NULL, 1),
  ('1479', 'ROXANA GUTIERREZ CHAVEZ', NULL, 1),
  ('1485', 'ARCENIA JOANA ROSAS TENORIO', NULL, 1),
  ('1486', 'ALMA DELIA ANTONIO PEREZ', NULL, 1),
  ('1487', 'ERIKA GARCIA DUARTE', NULL, 1),
  ('1488', 'LINA OSORIO ANTONIO', NULL, 1),
  ('1490', 'EDGAR ULISES GUERRERO VILLASEÑOR', NULL, 1),
  ('1491', 'JUANA MARIA DE JESUS JIMENEZ QUIROZ', NULL, 1),
  ('1492', 'MARIA DEL SOCORRO GARCIA ACOSTA', NULL, 1),
  ('1493', 'MARIA DE LOS ANGELES ORTEGA MARTINEZ', NULL, 1),
  ('1494', 'ROBERTO ZUÑIGA RAMIREZ', NULL, 1),
  ('1496', 'MARIA MAGDALENA SORIANO OROZCO', NULL, 1),
  ('1498', 'JUAN YUREM BALDERAS MEZA', NULL, 1),
  ('1499', 'MIRIAN ALEJANDRA GARZON ZARAGOZA', NULL, 1),
  ('1501', 'JANET JOSAHANDI ORTIZ MEDINA', NULL, 1),
  ('1503', 'AZUL AIMAR VAZQUEZ HERNANDEZ', NULL, 1),
  ('1504', 'CATHERINE MINOR ORTIZ', NULL, 1),
  ('1507', 'GABRIEL ALEJANDRO ADAME VALDES', NULL, 1),
  ('1508', 'JULIO ALFREDO RUBIO GARAY', NULL, 1),
  ('1509', 'FERNANDO DE JESUS FLORES', NULL, 1),
  ('1512', 'KAREN GARCIA ANGELES', NULL, 1),
  ('1513', 'OMAR SERRANO GONZALEZ', NULL, 1),
  ('1514', 'ARACELI GONZALEZ JIMENEZ', NULL, 1),
  ('1515', 'LORELI JAZMIN ESQUIVEL SUAREZ', 'Papeleria', 1),
  ('1516', 'PAMELA JAQUELINE ROJAS VIGUERAS', 'RRHH', 1),
  ('1517', 'KAREN REBECA MALDONADO VELAZQUEZ', 'Compras', 1),
  ('1520', 'DORALI AYLE RAMIREZ SALINAS', 'SGI', 1),
  ('1521', 'VALERY JANET LOPEZ GARCIA', NULL, 1),
  ('1522', 'CESAR BASILIO VALENTIN', NULL, 1),
  ('1523', 'JUAN JOSE ORTEGA MARTINEZ', NULL, 1),
  ('1524', 'KEVIN CALEB NAVARRO CARBAJAL', NULL, 1),
  ('1525', 'LEONARDO DAVID FLORES GARCIA', NULL, 1),
  ('1526', 'ANA JANETT HERNANDEZ CRUZ', NULL, 1)
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), area = COALESCE(trabajadores.area, VALUES(area));

-- ---------------------------------------------------------------------
-- 3) Equipos (95) — archivo equipos_de_computo.xlsx
--    Los que no traían identificador recibieron uno automático por tipo (PC-, LAP-, TEL-, IMP-, RED-…).
--    trabajador_id = tarjeta del responsable cuando su nombre coincide sin duda con la lista de trabajadores.
-- ---------------------------------------------------------------------
INSERT INTO equipos (identificador, nombre, tipo, marca, modelo, serie, area, responsable, trabajador_id, nombre_red, ip, hardware, monitor, perifericos, nivel_exposicion, estatus, frecuencia_mtto, ultimo_mtto, proximo_mtto, notas, activo) VALUES
  ('PC-001', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', '00:BE:43:D5:15:55', 'Alta Direccion', 'Ing. Juan Meza', NULL, 'DESKTOP-E6E2LDB', '10.10.10.10', NULL, NULL, NULL, 'Bajo', 'Activo', 'Anual', '2026-10-19', '2027-10-19', 'Identificador asignado por el sistema', 1),
  ('LAP-001', 'Laptop Dell', 'Laptop (Dell)', 'Dell', NULL, NULL, 'Alta Direccion', 'Ing. Juan Meza', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-001', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Alta Direccion', 'Ing. Juan Meza', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-002', 'Laptop Dell Alienware', 'Laptop (Dell)', 'Dell', 'Alienware', 'E4:B9:7A:29:5B:BD', 'Alta Direccion', 'Ing Antonio Meza', NULL, 'DESKTOP-7GN52SH', '10.10.10.13', NULL, NULL, NULL, 'Bajo', 'Activo', 'Anual', NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-003', 'Laptop Dell', 'Laptop (Dell)', 'Dell', NULL, NULL, 'Alta Direccion', 'Ing Antonio Meza', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-002', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Alta Direccion', 'Ing Antonio Meza', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-002', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', 'CC:96:E5:07:32:53', 'Alta Direccion', 'Ing Jose Luis', NULL, 'DESKTOP-O1C4T94', '10.10.10.14', NULL, NULL, NULL, 'Bajo', 'Activo', 'Anual', NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-004', 'Laptop Dell', 'Laptop (Dell)', 'Dell', NULL, NULL, 'Alta Direccion', 'Ing Jose Luis', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-003', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Alta Direccion', 'Ing Jose Luis', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-003', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Gerencia', 'Esmeralda Meza', (SELECT id FROM trabajadores WHERE tarjeta = '542'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-004', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Gerencia', 'Esmeralda Meza', (SELECT id FROM trabajadores WHERE tarjeta = '542'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-005', 'Laptop Dell', 'Laptop (Dell)', 'Dell', NULL, NULL, 'Gerencia', 'Esmeralda Meza', (SELECT id FROM trabajadores WHERE tarjeta = '542'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-004', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', '6C:2B:59:D0:67:7A', 'RRHH', 'Veronica Meza', (SELECT id FROM trabajadores WHERE tarjeta = '465'), 'DESKTOP-104S00H', '10.10.10.31', 'Procesador Intel(R) Core(TM) i5-8500 CPU @ 3.00GHz 3.00 GHz
RAM instalada 16.0 GB 4/4 2666 MHz DDR4
Almacenamiento 224 GB SSD ADATA SU630
Tarjeta gráfica Intel(R) HD Graphics 630', 'Monitore Marca DELL 1366*768 VGA, DP', 'Teclado Marca NACEB y Mause DELL', 'Bajo', 'Activo', 'Anual', NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-005', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'RRHH', 'Veronica Meza', (SELECT id FROM trabajadores WHERE tarjeta = '465'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('CHK-001', 'Checador Personal', 'Checador Personal', NULL, NULL, NULL, 'RRHH', 'RRHH', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-005', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', '8C:EC:4B:82:6A:7B', 'RRHH', 'Jaqueline Rojas', (SELECT id FROM trabajadores WHERE tarjeta = '1516'), 'DESKTOP-TV53LGH', '10.10.10.29', 'Procesador Intel(R) Core(TM) i5-8500 CPU @ 3.00GHz 3.00 GHz
RAM instalada 16.0 GB 1/2 2666 MHz DDR4
Almacenamiento 224 GB SSD ADATA SU630
Tarjeta gráfica Intel(R) HD Graphics 630', 'Monitore Marca DELL 1366*768 VGA, DP', 'Teclado Marca DELL y Mause Logitech Inalambrico Bluethoo (Presonal)
cuenta con Respaldo de energia No Brake', 'Bajo', 'Activo', 'Anual', NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-006', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'RRHH', 'Jaqueline Rojas', (SELECT id FROM trabajadores WHERE tarjeta = '1516'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-006', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'EHS', 'Naydelin', (SELECT id FROM trabajadores WHERE tarjeta = '1386'), 'SI-naydelin', '10.10.10.45', 'Procesador Intel(R) Core(TM) i5-7500 CPU @ 3.40GHz 3.41 GHz
RAM instalada 16.0 GB 1/2 2400 MHz DDR4
Almacenamiento 224 GB SSD ADATA SU630
Tarjeta gráfica Intel(R) HD Graphics 630', 'Monitore Marca
DELL 1920*1080 VGA', 'Teclado Logitech K120 y Mause Marca DELL
No cuenta con Respaldo de energia No Brake', 'Bajo', 'Activo', 'Anual', NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-007', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Planeacion', 'Octavio', (SELECT id FROM trabajadores WHERE tarjeta = '570'), 'DESKTOP-BJ4HTQ7', '10.10.10.36', 'Procesador 12th Gen Intel(R) Core(TM) i3-12100 3.30 GHz
RAM instalada 16.0 GB 2/2 3200 MTs DDR4
Almacenamiento 256 GB NVMe
Tarjeta gráfica Intel(R) HD Graphics 730', 'Monitore Marca DELL
1920*1080 VGA', 'Teclado Marca DELL y Mause Logitech Inalambrico Bluethoo (Presonal)
cuenta con Respaldo de energia No Brake
mpresora Presonal DCP-T720DW', 'Bajo', 'Activo', 'Anual', NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-007', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Planeacion', 'Planeacion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-008', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Planeacion', 'Enrique', NULL, 'DESKTOP-MTGDDAQ', '10.10.10.35', 'Procesador 12th Gen Intel(R) Core(TM) i3-12100 3.30 GHz
RAM instalada 16.0 GB 1/2 3200 MTs DDR4
Almacenamiento 256 GB NVMe
Tarjeta gráfica Intel(R) HD Graphics 730', 'Monitore Marca DELL
1920*1080 VGA', 'Teclado y Mause Marca DELL
No cuenta con Respaldo de energia No Brake', 'Bajo', 'Activo', 'Anual', NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-009', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Calidad', 'Leticia', NULL, 'DESKTOP-FFFGJVG', '10.10.10.43', 'Procesador Intel(R) Core(TM) i5-6500T CPU @ 2.50GHz 2.50 GHz
RAM instalada 16.0 GB 1/2 2400 MHz DDR4
Almacenamiento 224 GB SSD ADATA SU630
Tarjeta gráfica Intel(R) HD Graphics 630', 'Monitore Marca DELL 1366*768 VGA', 'Teclado y Mause Marca DELL
No cuenta con Respaldo de energia No Brake', NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-010', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Calidad', 'Natalia', (SELECT id FROM trabajadores WHERE tarjeta = '581'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-011', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Compras', 'Rebeca', (SELECT id FROM trabajadores WHERE tarjeta = '1517'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-008', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Compras', 'Rebeca', (SELECT id FROM trabajadores WHERE tarjeta = '1517'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('CEL-001', 'Celular Motorola', 'Celular', 'Motorola', NULL, NULL, 'Compras', 'Rebeca', (SELECT id FROM trabajadores WHERE tarjeta = '1517'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-012', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Compras', 'Wendy', (SELECT id FROM trabajadores WHERE tarjeta = '1062'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-009', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Compras', 'Wendy', (SELECT id FROM trabajadores WHERE tarjeta = '1062'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-013', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Manteniento', 'Ing Roy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-014', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('SRV-001', 'Servidor Lenovo', 'Servidor (Lenovo)', 'Lenovo', NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-001', 'Router Cisco', 'Router', 'Cisco', NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-002', 'Conmutador Panasonic', 'Conmutador', 'Panasonic', NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-003', 'Router ASUS', 'Router', 'ASUS', NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-004', 'Reptidor IP', 'Reptidor IP', NULL, NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-005', 'Moden Telmex', 'Moden Telmex', NULL, NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-006', 'Moden Telmex', 'Moden Telmex', NULL, NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-007', 'Moden Telmex', 'Moden Telmex', NULL, NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-008', 'Moden Telmex', 'Moden Telmex', NULL, NULL, NULL, 'Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-009', 'Conmutador', 'Conmutador', NULL, NULL, NULL, 'Planta 1 / Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-010', 'Reptidor IP', 'Reptidor IP', NULL, NULL, NULL, 'Planta 1 / Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-011', 'Router TP-Link', 'Router', 'TP-Link', NULL, NULL, 'Planta 1 / Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-012', 'Moden Telmex', 'Moden Telmex', NULL, NULL, NULL, 'Planta 1 / Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('RED-013', 'Moden Telmex', 'Moden Telmex', NULL, NULL, NULL, 'Planta 1 / Sistemas', 'Marco Enciso', (SELECT id FROM trabajadores WHERE tarjeta = '837'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-015', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Ing Producto', 'Valeria Flores', (SELECT id FROM trabajadores WHERE tarjeta = '1276'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PLT-001', 'Plotter Corte', 'Plotter Corte', NULL, NULL, NULL, 'Ing Producto', 'Valeria Flores', (SELECT id FROM trabajadores WHERE tarjeta = '1276'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-010', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Ing Producto', 'Ing Producto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-016', 'Escritorio Dell Vostro', 'Escritorio Dell', 'Dell', 'Vostro', NULL, 'Ing Producto', 'Eduardo Torres', (SELECT id FROM trabajadores WHERE tarjeta = '1401'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-017', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'SGI', 'Ayle', (SELECT id FROM trabajadores WHERE tarjeta = '1520'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-018', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Produccion', 'Ana Ivone', (SELECT id FROM trabajadores WHERE tarjeta = '709'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-019', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Produccion', 'Claudia', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-020', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Produccion', 'Alondra', (SELECT id FROM trabajadores WHERE tarjeta = '587'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-021', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Produccion', 'Diana/Jesus', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-011', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Produccion', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-022', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Lider Produccion', 'Martinez', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-023', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Almacen', 'Vicente', (SELECT id FROM trabajadores WHERE tarjeta = '726'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-024', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Almacen', 'Yerena', (SELECT id FROM trabajadores WHERE tarjeta = '1034'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-025', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Almacen', 'Marcos Rivera', (SELECT id FROM trabajadores WHERE tarjeta = '922'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-026', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Planta / Acabado 1', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-029', 'Genérica / Tarjeta Armada', 'Genérica / Tarjeta', 'Armada', NULL, NULL, 'Planta / Acabado 2', 'Produccion', NULL, 'Automanufacturas', '10.10.10.83', 'Procesador celeron
RAM: 2GB 1/2 Ranuras Usadas
Tarjeta Madre: H61M-E
Fuente: 500W R500', NULL, 'Mause
Teclado', 'Alto', 'Activo', 'Mensual', '2026-09-10', '2026-10-12', NULL, 1),
  ('PC-027', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Planta / Acabado 3', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-028', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Preformas', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-030', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Flash', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-031', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Rectificado', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-032', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Pintura', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-033', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'MVL', 'Produccion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-034', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Laboratorio', 'Vanesa', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-035', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Laboratorio', 'Alan', (SELECT id FROM trabajadores WHERE tarjeta = '1188'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-006', 'Laptop Dell', 'Laptop (Dell)', NULL, NULL, NULL, 'Papeleria', 'Loreli', (SELECT id FROM trabajadores WHERE tarjeta = '1515'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-007', 'Laptop Dell', 'Laptop (Dell)', NULL, NULL, NULL, 'Papeleria', 'Wendy', (SELECT id FROM trabajadores WHERE tarjeta = '1062'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-008', 'Laptop Lenovo', 'Laptop (Lenovo)', NULL, NULL, NULL, 'Papeleria', 'Wendy', (SELECT id FROM trabajadores WHERE tarjeta = '1062'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('LAP-009', 'Laptop Lenovo', 'Laptop (Lenovo)', NULL, NULL, NULL, 'Papeleria', 'Wendy', (SELECT id FROM trabajadores WHERE tarjeta = '1062'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('CAM-001', 'Camara Kodak', 'Camara Kodak', NULL, NULL, NULL, 'Papeleria', 'Wendy', (SELECT id FROM trabajadores WHERE tarjeta = '1062'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('CEL-002', 'Iphone', 'Iphone', NULL, NULL, NULL, 'Papeleria', 'Wendy', (SELECT id FROM trabajadores WHERE tarjeta = '1062'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-036', 'Genérica / Tarjeta Windows XP', 'Genérica / Tarjeta', 'Windows', 'XP', NULL, 'Produccion', 'Martienez', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-001', 'Impresora Brother', 'Impresora', 'Brother', NULL, NULL, 'Alta Direccion', 'Ing. Jose Luis', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-002', 'Impresora Brother', 'Impresora', 'Brother', NULL, NULL, 'Gerencia', 'Esmeralda Meza', (SELECT id FROM trabajadores WHERE tarjeta = '542'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-003', 'Impresora Etiquetas Zebra', 'Impresora Etiquetas', 'Zebra', NULL, NULL, 'Administrativos', 'Sistemas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-004', 'Impresora Brother B/N', 'Impresora', 'Brother', 'B/N', NULL, 'Administrativos', 'Sistemas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-005', 'Impresora Brother Color', 'Impresora', 'Brother', 'Color', NULL, 'Administrativos', 'Sistemas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-006', 'Impresora Brother', 'Impresora', 'Brother', NULL, NULL, 'Administrativos', 'Octavio', (SELECT id FROM trabajadores WHERE tarjeta = '570'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-007', 'Impresora Epson', 'Impresora', 'Epson', NULL, NULL, 'Administrativos', 'Compras', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-008', 'Impresora Epson', 'Impresora', 'Epson', NULL, NULL, 'Laboratorio', 'Laboratorio', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('IMP-009', 'Impresora Etiquetas Godex', 'Impresora Etiquetas', 'Godex', NULL, NULL, 'Laboratorio', 'Laboratorio', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('ESC-001', 'Scaner Zebra', 'Scaner', 'Zebra', NULL, NULL, 'Sistemas', 'Sistemas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('ESC-002', 'Scaner Ganerico', 'Scaner', 'Ganerico', NULL, NULL, 'Administrativos', 'Planeacion', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-037', 'Genérica / Tarjeta', 'Genérica / Tarjeta', NULL, NULL, NULL, 'Bodega', 'Miranda', (SELECT id FROM trabajadores WHERE tarjeta = '1395'), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-038', 'Escritorio Dell', 'Escritorio Dell', NULL, NULL, NULL, 'Bodega', 'Ruben', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-012', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Sala Juntas', 'Sistemas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TV-001', 'Smart TV SONY', 'Smart TV', 'SONY', NULL, NULL, 'Sala Juntas', 'Sistemas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('PC-039', 'Escritorio Dell', 'Escritorio Dell', 'Dell', NULL, NULL, 'Planta 1', 'Alejandra', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-013', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Planta 1', 'Alejandra', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-014', 'Telefono IP', 'Telefono IP', NULL, NULL, NULL, 'Planta 1', 'Vijilante', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('CHK-002', 'Checador Personal', 'Checador Personal', NULL, NULL, NULL, 'Planta 1', 'Alejandra', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1),
  ('TEL-015', 'Telefono Analogo', 'Telefono Analogo', NULL, NULL, NULL, 'Vigilancia', 'Vigilancia', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Identificador asignado por el sistema', 1)
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), tipo = VALUES(tipo), marca = VALUES(marca), modelo = VALUES(modelo), serie = VALUES(serie), area = VALUES(area), responsable = VALUES(responsable), trabajador_id = VALUES(trabajador_id), nombre_red = VALUES(nombre_red), ip = VALUES(ip), hardware = VALUES(hardware), monitor = VALUES(monitor), perifericos = VALUES(perifericos), nivel_exposicion = VALUES(nivel_exposicion), estatus = VALUES(estatus), frecuencia_mtto = VALUES(frecuencia_mtto), ultimo_mtto = VALUES(ultimo_mtto), proximo_mtto = VALUES(proximo_mtto), activo = VALUES(activo);

-- ---------------------------------------------------------------------
-- 4) Ing. Marco Enciso (tarjeta 837): trabajador Y administrador/técnico del panel.
--    Con su tarjeta levanta órdenes; con usuario y contraseña entra al panel.
--    Usuario: marco.enciso   Contraseña inicial: Mtto#Brake2026   (CÁMBIELA al entrar)
-- ---------------------------------------------------------------------
UPDATE trabajadores SET area = COALESCE(area, 'Sistemas'), puesto = COALESCE(puesto, 'Técnico de mantenimiento / Administrador') WHERE tarjeta = '837';
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT t.nombre, 'marco.enciso', '$2y$10$0.tixX03IQspx6Ubey//buy3XAYYMr98uphGheXW34oiJVMzO8GZW', 'administrador', t.id, 1
  FROM trabajadores t
 WHERE t.tarjeta = '837' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);

-- ---------------------------------------------------------------------
-- 5) Calendario preventivo con las fechas de la lista de equipos
--    (último mantenimiento = realizado; próximo = programado, responsable Ing. Marco)
-- ---------------------------------------------------------------------
INSERT INTO preventivos (titulo, equipo_id, fecha, frecuencia, estado, responsable_id, notas, realizado_en)
SELECT 'Mantenimiento preventivo anual', e.id, '2026-10-19', 'anual', 'realizado', (SELECT id FROM usuarios WHERE usuario = 'marco.enciso'), 'Importado de la lista maestra de equipo de cómputo', '2026-10-19 09:00:00'
  FROM equipos e WHERE e.identificador = 'PC-001'
   AND NOT EXISTS (SELECT 1 FROM preventivos p WHERE p.equipo_id = e.id AND p.fecha = '2026-10-19');
INSERT INTO preventivos (titulo, equipo_id, fecha, frecuencia, estado, responsable_id, notas, realizado_en)
SELECT 'Mantenimiento preventivo anual', e.id, '2027-10-19', 'anual', 'programado', (SELECT id FROM usuarios WHERE usuario = 'marco.enciso'), 'Importado de la lista maestra de equipo de cómputo', NULL
  FROM equipos e WHERE e.identificador = 'PC-001'
   AND NOT EXISTS (SELECT 1 FROM preventivos p WHERE p.equipo_id = e.id AND p.fecha = '2027-10-19');
INSERT INTO preventivos (titulo, equipo_id, fecha, frecuencia, estado, responsable_id, notas, realizado_en)
SELECT 'Mantenimiento preventivo mensual', e.id, '2026-09-10', 'mensual', 'realizado', (SELECT id FROM usuarios WHERE usuario = 'marco.enciso'), 'Importado de la lista maestra de equipo de cómputo', '2026-09-10 09:00:00'
  FROM equipos e WHERE e.identificador = 'PC-029'
   AND NOT EXISTS (SELECT 1 FROM preventivos p WHERE p.equipo_id = e.id AND p.fecha = '2026-09-10');
INSERT INTO preventivos (titulo, equipo_id, fecha, frecuencia, estado, responsable_id, notas, realizado_en)
SELECT 'Mantenimiento preventivo mensual', e.id, '2026-10-12', 'mensual', 'programado', (SELECT id FROM usuarios WHERE usuario = 'marco.enciso'), 'Importado de la lista maestra de equipo de cómputo', NULL
  FROM equipos e WHERE e.identificador = 'PC-029'
   AND NOT EXISTS (SELECT 1 FROM preventivos p WHERE p.equipo_id = e.id AND p.fecha = '2026-10-12');


-- =====================================================================
--  Incluye ACTUALIZACIÓN V5 (NIP, firmas electrónicas y foto de perfil)
-- =====================================================================

USE brake_sistema;

-- ---------------------------------------------------------------------
-- 1) Usuarios: NIP de 4 dígitos (SOLO el hash, con password_hash) y foto de perfil.
--    La unicidad del NIP la valida el sistema (un hash con sal no admite índice UNIQUE).
-- ---------------------------------------------------------------------
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS nip_hash    VARCHAR(255) NULL AFTER password,
  ADD COLUMN IF NOT EXISTS nip_cambio  DATETIME     NULL AFTER nip_hash,
  ADD COLUMN IF NOT EXISTS foto        MEDIUMTEXT   NULL AFTER nip_cambio;

-- ---------------------------------------------------------------------
-- 2) Firmas electrónicas: una por usuario (imagen PNG en base64).
--    Las administra solo el administrador; se cargan en las órdenes con el NIP.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS firmas (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id   INT UNSIGNED NOT NULL,
  imagen       MEDIUMTEXT   NOT NULL,
  creado       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  actualizo_id INT UNSIGNED NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_firma_usuario (usuario_id),
  CONSTRAINT fk_firma_usr FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3) Intentos fallidos de NIP (límite por IP contra adivinar los 10,000 NIP posibles).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nip_intentos (
  id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  ip     VARCHAR(45)  NOT NULL,
  creado TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ip_fecha (ip, creado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- =====================================================================
-- NIP único para CADA trabajador (tabla usuarios, ligados por trabajador_id)
-- El NIP es el número de tarjeta rellenado a 4 dígitos (ej. 837→0837, 2→0002).
-- Se crea una cuenta de usuario (rol 'usuario') si aún no existe.
-- Esas cuentas NO sirven para entrar al panel (password inutilizable) salvo que el admin les asigne una.
-- =====================================================================

-- 1) Crear cuenta de usuario para cada trabajador sin cuenta
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'RODOLFO REAL MORALES', 't2', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '2' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JAIME SALINAS GONZALEZ', 't3', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '3' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JORGE RODRIGUEZ MOTA', 't56', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '56' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'SUSANA DIANA CASASOLA SANDOVAL', 't124', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '124' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ANA LILIA GARAY CABALLERO', 't141', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '141' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'FANNY ROSALIA SALAS ANGUIANO', 't335', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '335' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARIA INES ESTRADA CASASOLA', 't348', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '348' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ROSICELA ESTRADA PEREZ', 't350', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '350' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ANA LIDIA MENDOZA LEMUS', 't423', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '423' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ENRIQUE GUTIERREZ ORTIZ', 't434', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '434' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ADRIANA ESPINOZA CERON', 't445', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '445' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALBERTO GARCIA MORALES', 't461', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '461' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'VERONICA MEZA MARTINEZ', 't465', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '465' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'GLORIA MARTINEZ ORTEGA', 't476', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '476' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DIONICIA SALINAS HERNANDEZ', 't484', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '484' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'IGNACIO PEREZ VILLANUEVA', 't524', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '524' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ESMERALDA MEZA MARTINEZ', 't542', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '542' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'EDUARDO MARTINEZ NAVARRO', 't543', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '543' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JUDITH MARIBEL SALDAÑA CORONA', 't552', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '552' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CLAUDIA DOLORES SANTOS MARTINEZ', 't563', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '563' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JOSE LUIS LOPEZ PASCUAL', 't567', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '567' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'OCTAVIO GABRIEL AOKI CORONA', 't570', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '570' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALEJANDRA RESENDIZ LOPEZ', 't580', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '580' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARIA NATALIA GARCIA GARCIA', 't581', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '581' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ADRIAN REYES RAMIREZ', 't584', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '584' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'FERNANDO CORONA GOMEZ', 't585', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '585' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JUAN CARLOS LICONA GABRIEL', 't586', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '586' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALONDRA OLGA RIVERO AGUILAR', 't587', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '587' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'RUTILO REYES RAMIREZ', 't597', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '597' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARIA DE LA LUZ GARCIA FLORES', 't607', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '607' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JESUS CASTELAN LUNA', 't622', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '622' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JONATHAN JESUS GARCIA FLORES', 't644', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '644' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'NAYELI VANESSA SALAZAR DURAN', 't647', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '647' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARTHA ALICIA MARQUEZ RAMIREZ', 't653', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '653' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ELVIRA PAZ RODRIGUEZ TENORIO', 't655', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '655' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ANA IVON GARCIA FLORES', 't709', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '709' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'VICENTE ROBERTO CRUZ GONZALEZ', 't726', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '726' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALFONSO REYES MARTINEZ', 't740', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '740' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ANTONIO BASILIO FRANCISCO', 't834', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '834' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARCO ANTONIO ENCISO GARCIA', 't837', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '837' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'BRENDA PAOLA HERNANDEZ HINOJOSA', 't844', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '844' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARCELA VALENTIN CAYETANO', 't852', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '852' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JUANA CERON LAZARO', 't866', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '866' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'VERONICA MARTINEZ HERNANDEZ', 't867', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '867' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'SANDRA MANZANO MONROY', 't879', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '879' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'BLANCA VIANEY HERNANDEZ MARTINEZ', 't893', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '893' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ESTHELA GARCIA GARCIA', 't898', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '898' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ISIDRA LOPEZ LOPEZ', 't899', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '899' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARCOS RIVERA SALAS', 't922', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '922' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'FABIOLA VALDES SIERRA', 't944', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '944' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LUCIANA MONTALVO PEREZ', 't991', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '991' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'EDGAR OSVALDO DIAZ MORALES', 't1002', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1002' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'YERENA MIRIAM ESTRADA HERNANDEZ', 't1034', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1034' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DIANA HERNANDEZ GARCIA', 't1048', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1048' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'WENDY LESLIE MENDEZ RIOS', 't1062', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1062' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'SANDRA YADIRA MIJANGOS NAJERA', 't1066', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1066' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'PERLA SUHEY RODRIGUEZ CRUZ', 't1068', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1068' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LETICIA MENDIOLA DELGADO', 't1073', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1073' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MICAELA GUERRA ANGELES', 't1104', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1104' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARISOL MENDOZA VILLANUEVA', 't1110', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1110' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CARMEN KARINA SANCHEZ ONTIVEROS', 't1157', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1157' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LESLIE JIMENEZ AVILA', 't1164', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1164' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALAN JEOVANNY MONTIEL VELAZQUEZ', 't1188', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1188' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ZAIRA MARIA ALEMAN ARIAS', 't1205', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1205' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JESUS ALAVEZ GARCIA', 't1244', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1244' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LEYDI GOMEZ JIMENEZ', 't1246', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1246' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'BEATRIZ ADRIANA BECERRA FLORES', 't1247', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1247' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'GABRIEL GARCIA GARCIA', 't1264', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1264' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JUDITH TIERRAFRIA PINEDA', 't1267', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1267' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'VALERIA FLORES MARTINEZ', 't1276', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1276' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ERNESTO RESENDIZ LOPEZ', 't1293', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1293' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ROSA GARCIA ALCANTAR', 't1308', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1308' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'SUSANA TOLEDO LOPEZ', 't1309', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1309' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'YESICCA GALINDO GUTIERREZ', 't1338', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1338' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MA. DE LOURDES BERNALDA GARCIA GARCIA', 't1344', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1344' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'BENJAMIN LEANDRO HERNANDEZ RAMIREZ', 't1351', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1351' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DAMARIS CHAVEZ MARQUEZ', 't1354', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1354' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JADIRA GALINDO GUTIERREZ', 't1360', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1360' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'SALOME DIAZ ORIZONTE', 't1366', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1366' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ANA KAREN PINEDA RAMIREZ', 't1370', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1370' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MAGDALENA SILVA VELAZQUEZ', 't1374', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1374' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JONATHAN FRANCISCO ALARCON BERNAL', 't1378', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1378' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LUZ NAYDELIN BARRIOS ANAYA', 't1386', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1386' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DAYANA YOSELIN ULIN LAIZA', 't1394', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1394' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MIRANDA ADALI JUAREZ CRUZ', 't1395', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1395' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DIANA EDITH GARZON AMARO', 't1396', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1396' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'VANESSA SANCHEZ GONZALEZ', 't1397', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1397' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MONSERRATH FRAGOSO SEGUNDO', 't1400', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1400' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'EDUARDO TORRES CASTILLO', 't1401', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1401' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DIANA RAMIREZ SINTO', 't1403', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1403' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ANAYELY CARBAJAL CRUZ', 't1409', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1409' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'GUADALUPE MARTINEZ ORTEGA', 't1412', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1412' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'BRYAN JOSUE ARELLANO HERNANDEZ', 't1414', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1414' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CESAR FABIAN ADAME VALDES', 't1415', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1415' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'HIDDEKEL LUIS AZUL GACHUZ CORTES', 't1416', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1416' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALEJANDRA GARCIA MONROY', 't1418', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1418' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JAVIER BACILIO FRANCISCO', 't1426', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1426' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALEXIS ARIEL CRUZ VAZQUEZ', 't1428', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1428' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'BERENICE SOLIS HERNANDEZ', 't1429', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1429' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DAVID ISMAEL SALINAS GUERRA', 't1430', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1430' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'PAULA LETICIA MARTINEZ MARTINEZ', 't1434', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1434' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CARLOS IVAN AVALOS GARCIA', 't1435', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1435' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'NORMA LIDIA VICENCIO CRUZ', 't1436', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1436' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'HAYDEE PEREZ ROMO', 't1441', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1441' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CRISTINA GARCIA GARCIA', 't1446', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1446' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARIA LUISA VAZQUEZ CASASOLA', 't1449', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1449' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'FLORA CORONA MENDOZA', 't1451', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1451' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JESUS ALFONSO HERNANDEZ RAMIREZ', 't1452', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1452' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JESUS MAURICIO CRUZ LUGO', 't1458', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1458' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DALIA IVON VARGAS CASASOLA', 't1461', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1461' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LETICIA VALENCIA TEMOXTLE', 't1463', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1463' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LUIS ENRIQUE GOMEZ MARTINEZ', 't1467', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1467' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CLAUDIA ISABEL MARTINEZ COSME', 't1471', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1471' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ROXANA GUTIERREZ CHAVEZ', 't1479', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1479' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ARCENIA JOANA ROSAS TENORIO', 't1485', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1485' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ALMA DELIA ANTONIO PEREZ', 't1486', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1486' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ERIKA GARCIA DUARTE', 't1487', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1487' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LINA OSORIO ANTONIO', 't1488', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1488' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'EDGAR ULISES GUERRERO VILLASEÑOR', 't1490', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1490' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JUANA MARIA DE JESUS JIMENEZ QUIROZ', 't1491', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1491' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARIA DEL SOCORRO GARCIA ACOSTA', 't1492', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1492' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARIA DE LOS ANGELES ORTEGA MARTINEZ', 't1493', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1493' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ROBERTO ZUÑIGA RAMIREZ', 't1494', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1494' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MARIA MAGDALENA SORIANO OROZCO', 't1496', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1496' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JUAN YUREM BALDERAS MEZA', 't1498', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1498' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'MIRIAN ALEJANDRA GARZON ZARAGOZA', 't1499', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1499' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JANET JOSAHANDI ORTIZ MEDINA', 't1501', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1501' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'AZUL AIMAR VAZQUEZ HERNANDEZ', 't1503', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1503' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CATHERINE MINOR ORTIZ', 't1504', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1504' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'GABRIEL ALEJANDRO ADAME VALDES', 't1507', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1507' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JULIO ALFREDO RUBIO GARAY', 't1508', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1508' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'FERNANDO DE JESUS FLORES', 't1509', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1509' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'KAREN GARCIA ANGELES', 't1512', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1512' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'OMAR SERRANO GONZALEZ', 't1513', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1513' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ARACELI GONZALEZ JIMENEZ', 't1514', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1514' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LORELI JAZMIN ESQUIVEL SUAREZ', 't1515', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1515' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'PAMELA JAQUELINE ROJAS VIGUERAS', 't1516', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1516' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'KAREN REBECA MALDONADO VELAZQUEZ', 't1517', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1517' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'DORALI AYLE RAMIREZ SALINAS', 't1520', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1520' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'VALERY JANET LOPEZ GARCIA', 't1521', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1521' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'CESAR BASILIO VALENTIN', 't1522', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1522' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'JUAN JOSE ORTEGA MARTINEZ', 't1523', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1523' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'KEVIN CALEB NAVARRO CARBAJAL', 't1524', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1524' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'LEONARDO DAVID FLORES GARCIA', 't1525', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1525' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);
INSERT IGNORE INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo)
SELECT 'ANA JANETT HERNANDEZ CRUZ', 't1526', '$2y$10$ePZhFm.fwbsg5ayc206bBOs1vSO.pdEEuLAG/S44xLNRACF9YlDl2', 'usuario', t.id, 1
  FROM trabajadores t WHERE t.tarjeta = '1526' AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.trabajador_id = t.id);

-- 2) Asignar NIP único (solo si aún no tiene)
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$kPWRJQoOzK1cEtRPjentHO0mJ57/.QKkH.P6UVB190zakJkZfDytO', u.nip_cambio = NOW()
 WHERE t.tarjeta = '2' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$EJLIl8q3B4Vh0YvXYIACYO/RuoCtg1x4TYgH12OHlYHMY9uX32eHu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '3' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$GUaBPLOTaN7iihFPYexC2eyYZvuaslY2cdUsEiCL4pgfadq0Gs8ui', u.nip_cambio = NOW()
 WHERE t.tarjeta = '56' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$MRWVYxRe7Lm.NbKZLsXha.HJGXqKhgD3Qkv77h54bzq1Oz4X95h8i', u.nip_cambio = NOW()
 WHERE t.tarjeta = '124' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$ptajJdrvo778CBTLAHZTJ.NWxoOUGJti0C8XxD2rcB7TLnIevdrYe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '141' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$RBRqh/Qu/DubMvHcnUj15O8sZHK1emq33YuHNDrv0OjLEOiCojF7C', u.nip_cambio = NOW()
 WHERE t.tarjeta = '335' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$xOCT.3EMBGvyjfNcoI.N2eus1Cix3oNIq4ot.5LkibTwJeGOyjFIu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '348' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$AsteKoXe.0cnhzrpf8yArOWkYYVR9EIeVhsRSAabnNS0.naXsxbq.', u.nip_cambio = NOW()
 WHERE t.tarjeta = '350' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$kFf62zeRxVDTqx1zVnIiiuuVnVqN3nOnIDN1B6wCUN2rBAd8ZgZZe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '423' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$AzRjXEAJ/2dZknFcUKs95ukz57gTm4qGUHBoU2QCWKn6ASRXqE0ti', u.nip_cambio = NOW()
 WHERE t.tarjeta = '434' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$du7q8KuoG4KBD5GRm6Mn6.7SX.vdnDGgtO45eAprbn5LuRM2TobiW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '445' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$QaJbRowvl8au71aGCh29F.HDcPD7HXuZAzyvx/G0LR0D0Vr8Jd56G', u.nip_cambio = NOW()
 WHERE t.tarjeta = '461' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$pTbIx3zSrPXx/r9UeLAbquOMk.hHsHMPH8t8l4dnAjvpYy5hOR5Pm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '465' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$o7BWYhSDp5Kwv.kVP3MhNuARVw.O6AtUtTmorf8YIDj2DjxEHRmja', u.nip_cambio = NOW()
 WHERE t.tarjeta = '476' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$pALUWiV1pmJUlyCewPwU/e0S47iVS8m5mZ9CbW.YqGnJpS6oceUYC', u.nip_cambio = NOW()
 WHERE t.tarjeta = '484' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$rrxFOpsGW90VQ.VQ0g2fauuqmKmtFglvKtGfo9jSk1l7JZbC8BEmm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '524' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$ClqTuMYrvlETUZGfSKJCMuD/NcmWHOyc88hVlYQx99R4eLKWUsIPu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '542' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$y5Sqtq/o6kPAXT4.jvJji.0sPsysRcegU7ZVeT0pWiHI38901734O', u.nip_cambio = NOW()
 WHERE t.tarjeta = '543' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$AullRGpb9V34OnIAt4KUJeVu9.0NgIPkxgNvrDA5XISRn0wyP4FNK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '552' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$UfR38LkxD7TSY.0XOOUOT.4cnhik/t0IRu7ihoLW0yEpdZhE7r8TW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '563' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$THIl5eTqkcOjta4jkdn82.bhg/Hu0n7oI.u9cfsAOlsr6dvKQzGHq', u.nip_cambio = NOW()
 WHERE t.tarjeta = '567' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$tInUzRCt5Qy7.dwlOKCkYuzhJfbJx8zYOPnITyJ9geu.SAEs/L8sG', u.nip_cambio = NOW()
 WHERE t.tarjeta = '570' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$/Z4.ilo/8Kl8EkUdBXDtIeQyiKB2nh9xF5pLnmSYho6V1z0zOvCBe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '580' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$qSLyYTmu5ytIhg83MkD3guYnFR0jPr28Y087UGa5RxjDX5Rc4GK96', u.nip_cambio = NOW()
 WHERE t.tarjeta = '581' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$mqsotXot.iMPP/IW87F0mu3t.djEtGlY7cbbZBODa7f0jUNuCJa5W', u.nip_cambio = NOW()
 WHERE t.tarjeta = '584' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$5EnwzWJlPQflc0SLtvXUXe2f7NY.2ox1EsPqfNedPuwYKy11zPgRy', u.nip_cambio = NOW()
 WHERE t.tarjeta = '585' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$vygaBRiFClepSlAF6oKKDuWjMBdEA/Wc8f8/mttd2wTbVJ11T24Ve', u.nip_cambio = NOW()
 WHERE t.tarjeta = '586' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$3FsOoojUo941F4/dB045z.FSsYiBGAlktDkzpg9M91Gc54AaC3sLW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '587' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$cGB5s.wPu3KGT64I0K879ua80JlhSud28i9k2xlSHyhYJBCJdf9Ga', u.nip_cambio = NOW()
 WHERE t.tarjeta = '597' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$y/4BTKaqTZFqt0/Wv6PMM.Cd6pmgNYJf2BUajC6fKdYTPDJ4vwarG', u.nip_cambio = NOW()
 WHERE t.tarjeta = '607' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$F3TrL528qhM3cZ0mQKcZEu3.kdCZ1XUjEjZpj2mO3gU90HWeTBCqy', u.nip_cambio = NOW()
 WHERE t.tarjeta = '622' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$1mORfkukrs0oyy/60LYLPen2LV4N.IpSm4IUbarI7snFv/zSiHdXe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '644' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$2SxAw4RYHJrRjD/4iTxG1extu.0MlV9KTZ7uAfvpxCBGh1a02FuPa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '647' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$YvecQkuBt2LNh3wawRl9T.DFSFILuja0c3JZkYMPEUgKRE4LAR6RK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '653' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$IYlE8M4FGDRVWtmU3dm7ZeVjg.SwMEb2EQYA9tnEyAKQ4YOTvYSyy', u.nip_cambio = NOW()
 WHERE t.tarjeta = '655' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$SzSkRctmVPKchFAgR30Ps.gkxT1LTMXkUUFqvF2MgNlUy4gcfxOzG', u.nip_cambio = NOW()
 WHERE t.tarjeta = '709' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$iPmDXdnwKaKCmkhGj3akOePPdZxPXtEZ7r37z56TPr1jaKvflwrP2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '726' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$aiOvJ4.lZaBkZ8DaH/HWT.cqdyD2n5E5CMo2H9P7hBup9QSyLkPeu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '740' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$uzGHAfx/MQaf72uzlpfNReOCMjyyoI78JMf33qDePN2oDpnC3A9KW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '834' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$ifdPppY85.iop1t/ehyeuuF3EQc72vzdKynDsHPfFmpr336XO2Vg6', u.nip_cambio = NOW()
 WHERE t.tarjeta = '837' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$LYbXzXQ5OO/jK9FSkAUvYuWEk7gdbLWogUGZfgHpIUuLR89DES4R.', u.nip_cambio = NOW()
 WHERE t.tarjeta = '844' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$FElFedUpqnZfDajG9a1o4eQ6UOlZg60QsreyQIX5iyCiktMc87Y1K', u.nip_cambio = NOW()
 WHERE t.tarjeta = '852' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$kTkusALI6.MXZ8iW9Oy1X.xT6m08zCfAwb0YyFhLuUxE./AFDGbXe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '866' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$sJufmG6En77q1SBhPPQrb.jmh.WeD.z5ju91JCCoFj5I5DAW0vlDa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '867' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$3uonrgkOy80D9mCfM0idw.KhApyGInsmcbTCBq/izJSfiaGLE4i3K', u.nip_cambio = NOW()
 WHERE t.tarjeta = '879' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$y0zzMcpWOSA5lPLBK.9bI.4ZUbuhKJooxXtGC1Tj93.gnkd.ZD2De', u.nip_cambio = NOW()
 WHERE t.tarjeta = '893' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$vsu2z1BloVuN1yQe2VeKzuUcw2vKwep/Fs9I0h/pQ1dj1ti.XOzS6', u.nip_cambio = NOW()
 WHERE t.tarjeta = '898' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$UoQ7P1sPUNuVRD5wXsygj.6VWzS16IrFm2SW0O9DWKEKsryIDAynS', u.nip_cambio = NOW()
 WHERE t.tarjeta = '899' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$V49h7RT2t6Vb9oANtlclOuqQkBdAEW2oqGD7799P9VgIZOmUg9VJu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '922' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$vQ8NhUP89CyYlx9a0nS/kud5ejeySmYlolFyarQhrObQp125FzVoe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '944' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$y8hQbp3jn7hA1xw5cjTuUOej5NkVmXtXdO3CksTfbgmV3/HDsEpke', u.nip_cambio = NOW()
 WHERE t.tarjeta = '991' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$KR1Cs1AXCR/ygFUHT1R.bu6tqzYor13ez6O18ZNmxAmrb6cRKv0H2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1002' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$Jt70rGWdS2BLFCIXcu/ZuuT1MDSyEarrd8fH9UfcY/77a9mK4OKgO', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1034' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$GFXAyK0FFbHXO/.d3ONmReZVvhUIOU9j2CjiLlufzGHoOP/2j/ovi', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1048' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$r1T.JCIkCi9CqpJCTy3yi.Q.7Z2ZDeqsO.5YN.MpqKsHYxrK2ygiu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1062' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$55UqPAoid8QR5pRINo6eM.tnsO8.I5N4EXRvktjsa.lEi2OBEQMYW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1066' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$0fuZpKRhDkfMzDvLiFNbX.QW31.uEM8arGSHO1wK3bROFh364iFq2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1068' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$BBR0/cw/BKVuMiwnU9V8V.l7/YuKBx4wKnV1bo.ag4zxpSU4Rimi.', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1073' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$ckAIVi7dsfCarOz9nKlYteBr83LYMSZ.UVgW.qT1pd2n0RDvhxDYW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1104' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$lKl16Qio.RQ.KQVzvEBb6eySjMwBcsGigMo1vk5rZVe6C3xmkV/Y2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1110' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$rhaK6Dj35dkTb45DtUJuQeVHgatEs6BnW2cMzJ945mPgOn9Q.3ULu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1157' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$9hzByIUp6/RDmdcEkk2T1uWMWXfdrF4PSEte1/RIK/uGA72BdrXFa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1164' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$K4B7k8CKebvaFYCWtlv2NO8F6XegbMkp1yEglPnZqO9OA2ODVNmNa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1188' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$7p2p3EGKxy/ZoOKvdq7OledSfoV3sVoXTTW.SLl0jCvHlNcMbN2re', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1205' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$MvpQ5h3PoUKKhwKvymjVc.M8GNBudWHPt2kDwJjdtirWc4490RRhy', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1244' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$cck7ioIFMD2AIb.I3V3fn.lF5kvO3T/543Wcjc9Lo5bPf4zGNZdw.', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1246' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$wvR6vvmBQjyMGbIL/oB6oen9QUoaTGGYoQz1.SPHI3FUFWKkO/s8.', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1247' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$rtXh4gUGOyQDqnkybHuO2ehkYvl6XPH3d1psuqOeQfFtpaOUqmqqW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1264' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$G4HUB.KV1VuSq22ToAKk.uG/ELEiDf.W8X52DG5pG8CoGzaKlv2aO', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1267' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$jX.p1IyWKXU2nJlBKJFbBOs0Ou0Ikh0IaMpL//w/M2oduv9sTPX8S', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1276' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$H64x/7wFAeX2a/mBxEEm4.OdZRbKHibt0gRJeLR464zO98ZiqLGJm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1293' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$bSRjJyay28kAuKWv95F3auPyeyDzYEpxUWC.WVXw5GXRh/mvWIUv2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1308' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$H2f1Q9EQ.AQslRRB.DTjVOvZb97t3HcmNh.Co/QPLH566qAhTBEkS', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1309' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$kEdDVa46ZpZTlzQAnhzZA.q.uIkM/zEbMXDVCAaJsGTfHsk3j8zYq', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1338' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$CkTvQzbaMko1PaN0lLhoReCn7/LhAnyG9CkCeXTBAE6onwHXwcZMq', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1344' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$wtaecCLkv2GmASpudrYO7u/zZ11QRDojOHlAzwUJ8xW/jNgZxv//m', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1351' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$2mSXQWL7C3rvTiA1Yo7uMuA1kpP1aQ0pzShoT2wncF6LFI0Cshsu2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1354' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$ocFB7GirMhxAlGqBJSP4neSkHKqb1rxoNbPVELbNlZuXYc1PoUqMa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1360' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$53yF.5UlKqxLi1FDM41nyOBncaS4d1fNwCPcJ4SNS4PdnBVXnlsXa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1366' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$iRQ7rKLXnY5/qdxCnEJZ1.xr9vQ8qVAjqsTP3tc0oj/t2NrcFGD5q', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1370' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$t9ZrtsxgisrZTS922125juh36zgqy.lJb053s7Ie7FMydJcsv7AFC', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1374' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$UZdkwJrGnGqS89hJms0Vle206nbV0TVAwVDzzVRPVENBx1vc0IWD6', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1378' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$vQQXFMWRwjMCtZk5yvXowOpfYV24WJkxTxclceZ1/HGqqmfz9nUaK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1386' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$BBnXrPFvIwTJShguU2VYV.Lxscs71I3eIfhu7FWMmF6OwtIUyzFWG', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1394' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$UWZ5hcdFocaXXLCkerosPe72Ry8eS.t7AX2JBliRXvOaKqZXLuieC', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1395' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$v0h05m3qMQCzAhzOLhyz7uE4wI0aOGJlTrJtpGe9x6olkgq4P4IjC', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1396' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$6YXeFESb6O326MZ2EwCxPOAO.rJ/iYzur9mdqbVXcy4fWR4p33AdO', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1397' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$2jNbbw3mpdf7ZtV/ixIihOZd0x5WgDr1fvGsPdrgGk4clC/cspFFu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1400' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$CnnProKPY4cmRSXxWF3aPeFIgrR2w4Cxjt6plaCWy8DRfLRmY/MnK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1401' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$bqFXfwS.ucd/dvxavBSk9uu9q5JyMR2zBpyL/vl/dgb3fAvAO.otq', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1403' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$lauaS89BB/rfNTc7P8spFuJtRrbnpSx7wa.MVte2uODsLpGr3YZjW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1409' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$5NXM6d6bdxU3IABWFTOC3eFYmtoImlpRyRebd57J7Az93uFbvpEx2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1412' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$EznpiQ/9nEA1htREBorskOVIwuVoP8gdQNzztSqRCbb0iBs8x7Yeq', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1414' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$3xitiruvdFfxWdnnLqd7O.71Epnc0h/yFjDs6erLPNs.l9o2QX8Tm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1415' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$GAXFpLQZ5txaQJOFy7Q75ufd/cR2kyTPXrQBWI.U9KZtkS5.ERUmW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1416' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$K2naMMmPCNwz/iNHI2FXo.KsXEkgjGfvwQr.1c9JFesU.1zIDiTY6', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1418' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$1LhwB1UIEO5YWAYbDgmxSepUKB5/Mfaf8MGZwxDKI605uGAQqw81i', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1426' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$/x0Z2CiqCA31PMdoBXjs7e24Ch7Q/U1b94lvnf.GVXAQlqibWu2g6', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1428' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$r/x4mLtX2iVGzLpHuqIw6.i5nVbOyCwbDkIFYn15O3GW9uz5VbmfW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1429' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$OZfqoD1hcwOrbSlmqtrO5uzB0E8mqTQcK8Cz5qB1aGZfKDJS5kob2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1430' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$V21TVfjajyU68OhUqm2A5O.VrTfrUP12DncN3H1y3aq6WntEOUX1S', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1434' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$Oiq3iN8tEsGf/egaZTxPtuYNvbltLTiFIgJSJDCLnwzsvtdy3m5iK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1435' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$Xi5YW/YQnN1Bh5KHU3bb/uTn2Vw8NhA44B6otapCmdaJSqaA.0ijW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1436' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$SRzlY/JQWuZAZiLmdfMpl.QhRUhuLkOQj4orvyhylI/TRXsYMWwEa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1441' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$gFWYzV4Pw9buIFifHei5YeGmQkZCKeOIt673HDCxm3yIaBYYawwli', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1446' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$bX2R6K3UhjqR0oJ/rt2jxe.h8HYRZdT17EdwmPnakxd/1Ja8nob1.', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1449' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$GTCyGdf.ISiJWt1rb7/aue.HE/nymQEiRNhpsERLmaZcmg/CYlEvy', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1451' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$.1rGQn8DOxmZ2rMoYTNI6.L6Y4hbXjeCl209icsl5xaekg3Wsxigi', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1452' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$Gr6xri/CZTpQCTjCa6x0gOpHw3wbt30031MnlewMqeM1wK4HFwkvq', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1458' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$rujSmPl0uhtOdvhd0UGYMuCSU4d/P2GXWtRcJ4Kld3HmzL5Jp44WW', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1461' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$IG.0VnNf1G/W2vb7h4zA4uK8tgrIKV6H3E38vHrVtCZJw.ML1QUYC', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1463' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$HdLQUKBH1I6UXGtksAHIMeYpzlBN0gDtlm.yAGwP3A3Zd9Rq06C.2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1467' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$uwKgJ4Y4/XoCvZZeo8RiPe./E10d.d8LeAnI/qPTIq39EMe5V/POa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1471' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$CqKReOdFO2Gk4bZ1CdCXleCwTZi7ugl7JuUGfHgud.6N4EmzQ2DR2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1479' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$IwHwDFmBaxVmAMNw3DE2CeN/MzuXdSbGcnM9u0yvMGGfFnRXYB2rK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1485' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$8pBXYxTjhW6IIpNawZNZUOa.CVMtYllnvH.SyLBb0NPqsrWNcD0j6', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1486' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$h9t6mffYl1kfdO6RQxcReuObDk2sSzqB3F2.t0vnqwh2DYwmcqa3G', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1487' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$JVEwWZK2haiXT16uKuiJKe9NtoqcYP2vIMufUtqTPJtHr53M5aWXm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1488' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$lDxXdaMNIWKDHCfOtIsrJesz8nh0PsuFjzKGzIb3EsIjnNyTaAtCa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1490' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$gdBIwexk87go0qjN/.BLveMv6Cvncr3GV33GYjZXdKZ/tQWJmxRMq', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1491' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$GIQkkn2W7uhBKNXJw4epgORa1yFLpS7KWMx.qfTFJ3W4ayB1geI5C', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1492' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$68MreOV5Q22NB3cU8KpVv.ao2.hMvLuiD7RdGv4Ib23opQFNKRTK6', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1493' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$.ULQCWouszgfZtKr.jEAQu/r./xWBG40Rbq2VymCHnMBExZ0Li42S', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1494' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$6.OIvNYDd4rI/IY1Obv04eEkuAMb9/NNQZgNil5QVqtky/o/x8wyC', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1496' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$PwWpoWsRDylU2WK/yomXq.XJBF9ruQhFiYmXl1pfPrrMRn8zNqxBO', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1498' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$DKmG/Wg7OG.NvMvlyYXlp.1UZF/zgFmv9n9bg9NFYpTOsYHKoJVRy', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1499' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$.FtZv5Q84j4FnlU/es6HbunL7O.RgR5GsJGKlDxLWuKoO5vOtUV1C', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1501' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$Owa1bpuxDyDV08ZtduxCduJz6CR1Lngbo01feLcERg61yzKE6CaJa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1503' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$rT3umUcZo5miHOxmJGITFOLSrx5f7VNRm8cBXXnhDwZIeDGIIL4bK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1504' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$b3GpnH3OYkKwC8Poa9QkVOsO0hiihy3a521jsZZFcLMudUL5LRbNm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1507' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$UDHYa70zP6m5iRmKiEcKz.YWYI6AXvmLGJhvXSACms.Z4pZRaMCbm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1508' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$BGOr.UCx6hTQfkSHu4THbOkDplaE/t.948Ldh7fMDDMQ.I8TkjYKa', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1509' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$Xk6XAvB72eZ8.jmLIpetMOUAIX7VdnNnxn9Fv/5nJj6.zTzNW.aR2', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1512' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$a3iAJ8sKqJ0luU7WmPRIsuXdREXILspZQfDxRzGtyWytKnXvaC69u', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1513' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$IIdBw3aXvz2/otA.DoK1Iuhl21wQNMOuLSGuBINChyaMO1V0t8hWe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1514' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$xLZwCYrThPCw.XmSdU4oze4tlc7mpxZ1c6fICyJ6YETraP5AQYygK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1515' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$bleHVsfsBjD.cLeSoRieWeUMTTLRCacJK.hvWvOgG.VPAipnEwhjK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1516' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$vVLyP7oSwWb7Ui0KT0sWq.ES94TiihFJDhq0PDtxwNeh1wFKa6.nS', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1517' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$QsEXD5e7AZa9r1fTKzVkH.PpeZ24sYklrlYTI0AwnWkcWaJPLmw6O', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1520' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$s890e6eC6mUb2gjDwoEmc.Ygrx4jTx0/zDFj.dv6TD1btdgSgWmNK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1521' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$5tV.m2eLE75zVLwRO8cgxe5vhVZpomtQZhCo4A0qLVmpqA4AyDaHm', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1522' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$w9DxItLdf0GhWpQbonuT.uabOoP34LMTfOwxS/HadWoBXBoGkIQCe', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1523' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$B9JqJBsrBpIBdiQUOk4u3Oap32Cp0RysocDHGHPQx2gfgEP1GU5Gu', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1524' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$ECzt0L1Vesh27gFbMLz04Oz8w.z4JOV.r6kVQl6cR04vewCvslTyy', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1525' AND u.nip_hash IS NULL;
UPDATE usuarios u JOIN trabajadores t ON t.id = u.trabajador_id
   SET u.nip_hash = '$2y$10$R2wvnRMQWi8CwY8cRhyiYu8TEKkGSS3KMn45.v32B31D9/yGUCikK', u.nip_cambio = NOW()
 WHERE t.tarjeta = '1526' AND u.nip_hash IS NULL;

-- 3) NIP de cuentas sin tarjeta (admin, consulta) si aún no tienen
UPDATE usuarios SET nip_hash = '$2y$10$NEsUD0oxVxLyX4wopBE/Ruq9VSbFUehzNphHnZE5OPn1oNZ1GM2l.', nip_cambio = NOW() WHERE usuario = 'admin' AND nip_hash IS NULL;
UPDATE usuarios SET nip_hash = '$2y$10$OKVnTHrvErMo3GfxgEqp6.1MBkUzWERxL0ktd4xOnpxtPtML3jaHy', nip_cambio = NOW() WHERE usuario = 'consulta' AND nip_hash IS NULL;
UPDATE usuarios SET nip_hash = '$2y$10$CAnISOQjVP5vT5wz6CYYeu1665moakzYW29R.fA0vMsTvie18tVay', nip_cambio = NOW() WHERE usuario = 'marco.enciso' AND nip_hash IS NULL;
