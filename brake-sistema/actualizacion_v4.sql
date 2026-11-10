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
