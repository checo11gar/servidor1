<?php
/**
 * api/panel.php — API del panel de mantenimiento (administradores y técnicos).
 * Todas las peticiones: POST JSON {accion, …} con cabecera X-CSRF-Token.
 * Las acciones de usuarios e importación son solo para administradores.
 */
declare(strict_types=1);
require_once __DIR__ . '/../includes/mtto.php';

$yo = require_panel(true);
exigir_post_csrf();
$esAdmin = $yo['rol'] === 'administrador';
$d = cuerpo_json();
$accion = (string)($d['accion'] ?? '');
$pdo = db();

function solo_admin(bool $esAdmin): void
{
    if (!$esAdmin) json_out(['ok' => false, 'error' => 'Solo un administrador puede hacer esto.'], 403);
}
function txt(array $d, string $k, int $max): string
{
    return mb_substr(trim((string)($d[$k] ?? '')), 0, $max);
}
function id_de(array $d, string $k = 'id'): int
{
    $v = filter_var($d[$k] ?? null, FILTER_VALIDATE_INT);
    return $v && $v > 0 ? (int)$v : 0;
}
function tecnicos(): array
{
    return db()->query("SELECT id, nombre, rol FROM usuarios WHERE activo = 1 AND rol IN ('administrador','tecnico') ORDER BY nombre")->fetchAll();
}
function equipos_min(): array
{
    return db()->query('SELECT id, identificador, nombre, area FROM equipos WHERE activo = 1 ORDER BY identificador')->fetchAll();
}

function badges_panel(): array
{
    $p = db();
    return [
        'abiertas'  => (int)$p->query("SELECT COUNT(*) FROM ordenes_correctivas WHERE estado <> 'finalizada'")->fetchColumn(),
        'nuevas'    => (int)$p->query("SELECT COUNT(*) FROM ordenes_correctivas WHERE estado = 'pendiente'")->fetchColumn(),
        'vencidos'  => (int)$p->query("SELECT COUNT(*) FROM preventivos WHERE estado = 'programado' AND fecha < CURDATE()")->fetchColumn(),
        'equipos'   => (int)$p->query('SELECT COUNT(*) FROM equipos WHERE activo = 1')->fetchColumn(),
        'trabajadores' => (int)$p->query('SELECT COUNT(*) FROM trabajadores WHERE activo = 1')->fetchColumn(),
    ];
}

switch ($accion) {

/* =================================================================== RESUMEN */
case 'resumen':
    $cnt = $pdo->query("SELECT
        SUM(estado <> 'finalizada')                                   AS abiertas,
        SUM(estado = 'pendiente')                                     AS pendientes,
        SUM(estado = 'verificada')                                    AS verificadas,
        SUM(estado = 'en_proceso')                                    AS en_proceso,
        SUM(estado <> 'finalizada' AND prioridad = 'critica')         AS criticos,
        SUM(estado <> 'finalizada' AND prioridad IN ('critica','alta')) AS urgentes,
        SUM(estado = 'finalizada' AND finalizado >= NOW() - INTERVAL 30 DAY) AS cerrados30,
        SUM(estado = 'finalizada' AND finalizado >= NOW() - INTERVAL 60 DAY AND finalizado < NOW() - INTERVAL 30 DAY) AS cerrados30_ant,
        SUM(creado >= NOW() - INTERVAL 7 DAY)                          AS creadas7,
        SUM(creado >= NOW() - INTERVAL 14 DAY AND creado < NOW() - INTERVAL 7 DAY) AS creadas7_ant,
        SUM(prioridad IN ('critica','alta') AND creado >= NOW() - INTERVAL 7 DAY) AS urg7,
        SUM(prioridad IN ('critica','alta') AND creado >= NOW() - INTERVAL 14 DAY AND creado < NOW() - INTERVAL 7 DAY) AS urg7_ant,
        AVG(CASE WHEN estado = 'finalizada' AND finalizado >= NOW() - INTERVAL 30 DAY
                 THEN TIMESTAMPDIFF(MINUTE, creado, finalizado) END)  AS cierre_min,
        AVG(CASE WHEN estado = 'finalizada' AND finalizado >= NOW() - INTERVAL 60 DAY AND finalizado < NOW() - INTERVAL 30 DAY
                 THEN TIMESTAMPDIFF(MINUTE, creado, finalizado) END)  AS cierre_min_ant
      FROM ordenes_correctivas")->fetch();
    $pct = function ($a, $b): ?float {
        $a = (float)$a; $b = (float)$b;
        if ($b == 0.0) return $a > 0 ? 100.0 : null;
        return round(($a - $b) / $b * 100, 1);
    };

    // Mini-gráficas de las tarjetas: últimos 14 días
    $serie = function (string $sql) use ($pdo): array {
        $dias = [];
        for ($i = 13; $i >= 0; $i--) $dias[date('Y-m-d', strtotime("-$i day"))] = 0;
        $st = $pdo->prepare($sql);
        $st->execute([array_key_first($dias)]);
        foreach ($st as $r) if (isset($dias[$r['f']])) $dias[$r['f']] = (float)$r['n'];
        return array_values($dias);
    };
    $spark = [
        'creadas'  => $serie('SELECT DATE(creado) f, COUNT(*) n FROM ordenes_correctivas WHERE creado >= ? GROUP BY DATE(creado)'),
        'urgentes' => $serie("SELECT DATE(creado) f, COUNT(*) n FROM ordenes_correctivas WHERE prioridad IN ('critica','alta') AND creado >= ? GROUP BY DATE(creado)"),
        'cerradas' => $serie('SELECT DATE(finalizado) f, COUNT(*) n FROM ordenes_correctivas WHERE finalizado >= ? GROUP BY DATE(finalizado)'),
        'cierre'   => $serie("SELECT DATE(finalizado) f, ROUND(AVG(TIMESTAMPDIFF(MINUTE, creado, finalizado)) / 60, 1) n
                                FROM ordenes_correctivas WHERE estado = 'finalizada' AND finalizado >= ? GROUP BY DATE(finalizado)"),
    ];

    $prio = array_fill_keys(array_keys(PRIORIDADES), 0);
    foreach ($pdo->query("SELECT prioridad, COUNT(*) n FROM ordenes_correctivas WHERE estado <> 'finalizada' GROUP BY prioridad") as $r) {
        $prio[$r['prioridad']] = (int)$r['n'];
    }
    $tipo = array_fill_keys(array_keys(TIPOS_FALLA), 0);
    foreach ($pdo->query("SELECT tipo_falla, COUNT(*) n FROM ordenes_correctivas WHERE creado >= NOW() - INTERVAL 90 DAY GROUP BY tipo_falla") as $r) {
        $tipo[$r['tipo_falla']] = (int)$r['n'];
    }
    $porTipoEquipo = $pdo->query(
        "SELECT COALESCE(e.tipo, 'Sin catálogo') AS tipo, COUNT(*) AS n
           FROM ordenes_correctivas o LEFT JOIN equipos e ON e.id = o.equipo_id
          WHERE o.creado >= NOW() - INTERVAL 90 DAY
          GROUP BY COALESCE(e.tipo, 'Sin catálogo') ORDER BY n DESC LIMIT 5")->fetchAll();

    $topEquipos = $pdo->query(
        "SELECT o.equipo_ident AS equipo, MAX(e.nombre) AS nombre, MAX(e.area) AS area,
                COALESCE(MAX(t.nombre), MAX(e.responsable)) AS responsable, COUNT(*) AS n,
                SUM(o.tipo_falla = 'software') AS software, SUM(o.tipo_falla = 'hardware') AS hardware
           FROM ordenes_correctivas o
           LEFT JOIN equipos e ON e.id = o.equipo_id
           LEFT JOIN trabajadores t ON t.id = e.trabajador_id
          WHERE o.creado >= NOW() - INTERVAL 90 DAY
          GROUP BY o.equipo_ident ORDER BY n DESC LIMIT 6")->fetchAll();

    $proximos = $pdo->query(
        "SELECT p.id, p.titulo, p.fecha, p.frecuencia, e.identificador, e.area, u.nombre AS responsable
           FROM preventivos p
           LEFT JOIN equipos e ON e.id = p.equipo_id
           LEFT JOIN usuarios u ON u.id = p.responsable_id
          WHERE p.estado = 'programado'
          ORDER BY p.fecha LIMIT 6")->fetchAll();

    $recientes = array_map(fn($o) => orden_para_json($o + ['firma_reporto' => null, 'firma_ejecuto' => null, 'firma_recibio' => null], false),
        $pdo->query("SELECT id, folio, estado, tipo_falla, prioridad, area, reporta_nombre, equipo_ident, fecha_paro, fecha_ejecucion,
                            fecha_entrega, creado FROM ordenes_correctivas ORDER BY id DESC LIMIT 6")->fetchAll());

    $inv = $pdo->query("SELECT COUNT(*) total, SUM(activo = 1) activos, SUM(trabajador_id IS NULL) sin_tarjeta,
                               SUM(NOT EXISTS (SELECT 1 FROM preventivos p WHERE p.equipo_id = equipos.id AND p.estado = 'programado')) sin_preventivo
                          FROM equipos")->fetch();
    $porArea = $pdo->query("SELECT COALESCE(area, 'Sin área') area, COUNT(*) n,
                                   SUM(EXISTS (SELECT 1 FROM ordenes_correctivas o WHERE o.equipo_id = equipos.id AND o.estado <> 'finalizada')) con_falla
                              FROM equipos WHERE activo = 1 GROUP BY COALESCE(area, 'Sin área') ORDER BY n DESC LIMIT 8")->fetchAll();

    json_out(['ok' => true,
        'kpi' => [
            'abiertas' => (int)$cnt['abiertas'], 'pendientes' => (int)$cnt['pendientes'], 'verificadas' => (int)$cnt['verificadas'],
            'en_proceso' => (int)$cnt['en_proceso'], 'criticos' => (int)$cnt['criticos'], 'urgentes' => (int)$cnt['urgentes'],
            'cerrados30' => (int)$cnt['cerrados30'],
            'cierre' => $cnt['cierre_min'] !== null ? duracion_texto((int)round((float)$cnt['cierre_min'])) : '',
            'cierre_horas' => $cnt['cierre_min'] !== null ? round((float)$cnt['cierre_min'] / 60, 1) : null,
        ],
        'tendencia' => [
            'creadas' => $pct($cnt['creadas7'], $cnt['creadas7_ant']),
            'urgentes' => $pct($cnt['urg7'], $cnt['urg7_ant']),
            'cerradas' => $pct($cnt['cerrados30'], $cnt['cerrados30_ant']),
            'cierre' => ($cnt['cierre_min'] !== null && $cnt['cierre_min_ant'] !== null) ? $pct($cnt['cierre_min'], $cnt['cierre_min_ant']) : null,
        ],
        'spark' => $spark, 'prioridad' => $prio, 'tipo' => $tipo, 'por_tipo_equipo' => $porTipoEquipo,
        'top_equipos' => $topEquipos, 'proximos' => $proximos, 'recientes' => $recientes,
        'inventario' => array_map('intval', $inv), 'por_area' => $porArea,
        'badges' => badges_panel(),
    ]);

case 'grafica':   // creadas vs finalizadas en 7, 30 o 90 días
    $n = (int)($d['dias'] ?? 30);
    if (!in_array($n, [7, 30, 90], true)) $n = 30;
    $porSemana = $n === 90;
    $cubetas = [];
    if ($porSemana) {
        $lunes = strtotime('monday this week');
        for ($i = 12; $i >= 0; $i--) {
            $ini = strtotime("-$i week", $lunes);
            $cubetas[date('Y-m-d', $ini)] = ['etq' => date('d/m', $ini), 'creadas' => 0, 'cerradas' => 0];
        }
    } else {
        for ($i = $n - 1; $i >= 0; $i--) {
            $f = date('Y-m-d', strtotime("-$i day"));
            $cubetas[$f] = ['etq' => date('d/m', strtotime($f)), 'creadas' => 0, 'cerradas' => 0];
        }
    }
    $desde = array_key_first($cubetas);
    $clave = $porSemana ? "DATE(DATE_SUB(%s, INTERVAL WEEKDAY(%s) DAY))" : 'DATE(%s)';
    foreach (['creado' => 'creadas', 'finalizado' => 'cerradas'] as $col => $k) {
        $exp = sprintf($clave, $col, $col);
        $st = $pdo->prepare("SELECT $exp f, COUNT(*) n FROM ordenes_correctivas WHERE $col >= ? GROUP BY f");
        $st->execute([$desde]);
        foreach ($st as $r) if (isset($cubetas[$r['f']])) $cubetas[$r['f']][$k] = (int)$r['n'];
    }
    $tot = ['creadas' => array_sum(array_column($cubetas, 'creadas')), 'cerradas' => array_sum(array_column($cubetas, 'cerradas'))];
    json_out(['ok' => true, 'dias' => $n, 'por_semana' => $porSemana, 'puntos' => array_values($cubetas), 'totales' => $tot]);

case 'notificaciones':
    $nuevas = array_map(fn($o) => $o + ['estado_texto' => ESTADOS[$o['estado']]],
        $pdo->query("SELECT id, folio, estado, prioridad, equipo_ident, reporta_nombre, creado FROM ordenes_correctivas
                      WHERE estado = 'pendiente' ORDER BY FIELD(prioridad,'critica','alta','media','baja'), id DESC LIMIT 8")->fetchAll());
    $vencidos = $pdo->query("SELECT p.id, p.titulo, p.fecha, e.identificador FROM preventivos p LEFT JOIN equipos e ON e.id = p.equipo_id
                              WHERE p.estado = 'programado' AND p.fecha < CURDATE() ORDER BY p.fecha LIMIT 5")->fetchAll();
    $semana = $pdo->query("SELECT p.id, p.titulo, p.fecha, e.identificador FROM preventivos p LEFT JOIN equipos e ON e.id = p.equipo_id
                            WHERE p.estado = 'programado' AND p.fecha BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY ORDER BY p.fecha LIMIT 5")->fetchAll();
    $ultimo = (int)$pdo->query('SELECT COALESCE(MAX(id), 0) FROM ordenes_correctivas')->fetchColumn();
    json_out(['ok' => true, 'nuevas' => $nuevas, 'vencidos' => $vencidos, 'semana' => $semana, 'ultimo_id' => $ultimo, 'badges' => badges_panel()]);

case 'buscar_global':   // buscador rápido (Ctrl + K)
    $q = txt($d, 'q', 60);
    if (mb_strlen($q) < 2) json_out(['ok' => true, 'ordenes' => [], 'equipos' => [], 'trabajadores' => []]);
    $l = '%' . $q . '%';
    $st = $pdo->prepare('SELECT id, folio, estado, equipo_ident, reporta_nombre, reporte FROM ordenes_correctivas
                          WHERE folio LIKE ? OR reporta_nombre LIKE ? OR reporta_tarjeta LIKE ? OR equipo_ident LIKE ? OR reporte LIKE ?
                          ORDER BY id DESC LIMIT 6');
    $st->execute([$l, $l, $l, $l, $l]);
    $ord = array_map(fn($o) => ['estado_texto' => ESTADOS[$o['estado']], 'reporte' => mb_strimwidth((string)$o['reporte'], 0, 70, '…')] + $o, $st->fetchAll());
    $st = $pdo->prepare('SELECT id, identificador, nombre, area, responsable, ip FROM equipos
                          WHERE identificador LIKE ? OR nombre LIKE ? OR area LIKE ? OR responsable LIKE ? OR ip LIKE ? OR nombre_red LIKE ? OR serie LIKE ?
                          ORDER BY identificador LIMIT 6');
    $st->execute([$l, $l, $l, $l, $l, $l, $l]);
    $eq = $st->fetchAll();
    $st = $pdo->prepare('SELECT id, tarjeta, nombre, area FROM trabajadores WHERE tarjeta LIKE ? OR nombre LIKE ? ORDER BY nombre LIMIT 6');
    $st->execute([$q . '%', $l]);
    json_out(['ok' => true, 'ordenes' => $ord, 'equipos' => $eq, 'trabajadores' => $st->fetchAll()]);

case 'mi_password':
    $actual = (string)($d['actual'] ?? '');
    $nueva = (string)($d['nueva'] ?? '');
    $st = $pdo->prepare('SELECT password FROM usuarios WHERE id = ?');
    $st->execute([(int)$yo['id']]);
    if (!password_verify($actual, (string)$st->fetchColumn())) json_out(['ok' => false, 'error' => 'La contraseña actual no es correcta.'], 422);
    if (strlen($nueva) < 8) json_out(['ok' => false, 'error' => 'La nueva contraseña debe tener al menos 8 caracteres.'], 422);
    $pdo->prepare('UPDATE usuarios SET password = ? WHERE id = ?')->execute([password_hash($nueva, PASSWORD_DEFAULT), (int)$yo['id']]);
    json_out(['ok' => true, 'mensaje' => 'Contraseña actualizada.']);

/* =================================================================== ÓRDENES */
case 'ordenes_listar':
    $w = []; $p = [];
    $estado = (string)($d['estado'] ?? '');
    if ($estado === 'abiertas') { $w[] = "o.estado <> 'finalizada'"; }
    elseif (isset(ESTADOS[$estado])) { $w[] = 'o.estado = ?'; $p[] = $estado; }
    if (isset(TIPOS_FALLA[$d['tipo'] ?? ''])) { $w[] = 'o.tipo_falla = ?'; $p[] = $d['tipo']; }
    if (isset(PRIORIDADES[$d['prioridad'] ?? ''])) { $w[] = 'o.prioridad = ?'; $p[] = $d['prioridad']; }
    if ($f = fecha_sql($d['desde'] ?? '')) { $w[] = 'o.creado >= ?'; $p[] = $f . ' 00:00:00'; }
    if ($f = fecha_sql($d['hasta'] ?? '')) { $w[] = 'o.creado <= ?'; $p[] = $f . ' 23:59:59'; }
    $q = txt($d, 'q', 80);
    if ($q !== '') {
        $w[] = '(o.folio LIKE ? OR o.reporta_nombre LIKE ? OR o.reporta_tarjeta LIKE ? OR o.equipo_ident LIKE ? OR o.area LIKE ? OR o.reporte LIKE ?)';
        array_push($p, ...array_fill(0, 6, '%' . $q . '%'));
    }
    $sql = 'SELECT o.id, o.folio, o.estado, o.tipo_falla, o.prioridad, o.area, o.reporta_nombre, o.reporta_tarjeta,
                   o.equipo_ident, o.fecha_paro, o.fecha_ejecucion, o.fecha_entrega, o.reporte, o.descripcion, o.ejecuto_nombre, o.creado, o.finalizado
              FROM ordenes_correctivas o' . ($w ? ' WHERE ' . implode(' AND ', $w) : '') .
           " ORDER BY FIELD(o.estado,'pendiente','verificada','en_proceso','finalizada'),
                      FIELD(o.prioridad,'critica','alta','media','baja'), o.id DESC LIMIT " . (empty($d['completo']) ? 500 : 5000);
    $st = $pdo->prepare($sql);
    $st->execute($p);
    $filas = array_map(function ($o) {
        $o['firma_reporto'] = $o['firma_ejecuto'] = $o['firma_recibio'] = null;
        $o = orden_para_json($o, false);
        if (empty($d['completo'])) $o['reporte'] = mb_strimwidth((string)$o['reporte'], 0, 120, '…');
        return $o;
    }, $st->fetchAll());
    json_out(['ok' => true, 'ordenes' => $filas]);

case 'orden_obtener':
    $id = id_de($d);
    $st = $pdo->prepare('SELECT * FROM ordenes_correctivas WHERE id = ?');
    $st->execute([$id]);
    $o = $st->fetch();
    if (!$o) json_out(['ok' => false, 'error' => 'La orden no existe.'], 404);
    $st = $pdo->prepare('SELECT h.estado, h.nota, h.fecha, u.nombre FROM ordenes_historial h LEFT JOIN usuarios u ON u.id = h.usuario_id WHERE h.orden_id = ? ORDER BY h.id');
    $st->execute([$id]);
    $hist = array_map(fn($h) => $h + ['estado_texto' => ESTADOS[$h['estado']] ?? $h['estado']], $st->fetchAll());
    json_out(['ok' => true, 'orden' => orden_para_json($o), 'historial' => $hist, 'tecnicos' => tecnicos(), 'equipos' => equipos_min()]);

case 'orden_guardar':
    $id = id_de($d);
    $st = $pdo->prepare('SELECT * FROM ordenes_correctivas WHERE id = ?');
    $st->execute([$id]);
    $o = $st->fetch();
    if (!$o) json_out(['ok' => false, 'error' => 'La orden no existe.'], 404);

    $tipo = (string)($d['tipo_falla'] ?? $o['tipo_falla']);
    if (!isset(TIPOS_FALLA[$tipo])) $tipo = $o['tipo_falla'];
    $prio = (string)($d['prioridad'] ?? $o['prioridad']);
    if (!isset(PRIORIDADES[$prio])) $prio = $o['prioridad'];

    $equipoId = null; $equipoIdent = txt($d, 'equipo_ident', 60);
    if ($eid = id_de($d, 'equipo_id')) {
        $s = $pdo->prepare('SELECT id, identificador FROM equipos WHERE id = ?');
        $s->execute([$eid]);
        if ($eq = $s->fetch()) { $equipoId = (int)$eq['id']; $equipoIdent = $eq['identificador']; }
    }
    if ($equipoIdent === '') $equipoIdent = (string)$o['equipo_ident'];

    $paro = fecha_hora_sql($d['fecha_paro'] ?? '') ?? $o['fecha_paro'];
    $ejec = fecha_hora_sql($d['fecha_ejecucion'] ?? '');
    $entr = fecha_hora_sql($d['fecha_entrega'] ?? '');
    if ($ejec && $ejec < $paro) json_out(['ok' => false, 'error' => 'La ejecución no puede ser antes del paro.'], 422);
    if ($entr && $ejec && $entr < $ejec) json_out(['ok' => false, 'error' => 'La entrega no puede ser antes de la ejecución.'], 422);
    if ($entr && $entr < $paro) json_out(['ok' => false, 'error' => 'La entrega no puede ser antes del paro.'], 422);

    $ejecutoId = id_de($d, 'ejecuto_id') ?: null;
    $ejecutoNombre = null;
    if ($ejecutoId) {
        $s = $pdo->prepare('SELECT nombre FROM usuarios WHERE id = ?');
        $s->execute([$ejecutoId]);
        $ejecutoNombre = $s->fetchColumn() ?: null;
        if ($ejecutoNombre === null) $ejecutoId = null;
    }
    $reporte = txt($d, 'reporte', 5000);
    if ($reporte === '') $reporte = (string)$o['reporte'];

    $firma = fn(string $k) => array_key_exists($k, $d) ? firma_valida($d[$k]) : $o[$k];

    $pdo->prepare('UPDATE ordenes_correctivas SET
        area = ?, equipo_id = ?, equipo_ident = ?, tipo_falla = ?, prioridad = ?, fecha_paro = ?, fecha_ejecucion = ?, fecha_entrega = ?,
        reporte = ?, descripcion = ?, ejecuto_id = ?, ejecuto_nombre = ?, recibio_nombre = ?,
        firma_reporto = ?, firma_ejecuto = ?, firma_recibio = ?, fecha_firma_ejecuto = ?, fecha_firma_recibio = ?
        WHERE id = ?')->execute([
        txt($d, 'area', 80) ?: $o['area'], $equipoId, $equipoIdent, $tipo, $prio, $paro, $ejec, $entr,
        $reporte, txt($d, 'descripcion', 5000) ?: null, $ejecutoId, $ejecutoNombre, txt($d, 'recibio_nombre', 120) ?: null,
        $firma('firma_reporto'), $firma('firma_ejecuto'), $firma('firma_recibio'),
        fecha_sql($d['fecha_firma_ejecuto'] ?? '') ?? ($firma('firma_ejecuto') ? date('Y-m-d') : null),
        fecha_sql($d['fecha_firma_recibio'] ?? '') ?? ($firma('firma_recibio') ? date('Y-m-d') : null), $id,
    ]);
    json_out(['ok' => true, 'mensaje' => 'Orden ' . $o['folio'] . ' guardada.']);

case 'orden_estado':
    $id = id_de($d);
    $nuevo = (string)($d['estado'] ?? '');
    if (!isset(ESTADOS[$nuevo])) json_out(['ok' => false, 'error' => 'Estado no válido.'], 422);
    $st = $pdo->prepare('SELECT id, folio, estado, fecha_ejecucion, fecha_entrega, ejecuto_id FROM ordenes_correctivas WHERE id = ?');
    $st->execute([$id]);
    $o = $st->fetch();
    if (!$o) json_out(['ok' => false, 'error' => 'La orden no existe.'], 404);
    if ($o['estado'] === $nuevo) json_out(['ok' => true, 'mensaje' => 'Sin cambios.']);

    $sets = ['estado = ?']; $vals = [$nuevo];
    // Al pasar a "En proceso" se toma la hora de ejecución y el técnico si faltan.
    if ($nuevo === 'en_proceso' && !$o['fecha_ejecucion']) { $sets[] = 'fecha_ejecucion = NOW()'; }
    if (in_array($nuevo, ['en_proceso', 'finalizada'], true) && !$o['ejecuto_id']) {
        $sets[] = 'ejecuto_id = ?'; $sets[] = 'ejecuto_nombre = ?'; array_push($vals, (int)$yo['id'], $yo['nombre']);
    }
    if ($nuevo === 'finalizada') {
        $sets[] = 'finalizado = NOW()';
        if (!$o['fecha_entrega']) $sets[] = 'fecha_entrega = NOW()';
        if (!$o['fecha_ejecucion']) $sets[] = 'fecha_ejecucion = NOW()';
    } else {
        $sets[] = 'finalizado = NULL';
    }
    $vals[] = $id;
    $pdo->prepare('UPDATE ordenes_correctivas SET ' . implode(', ', $sets) . ' WHERE id = ?')->execute($vals);
    registrar_historial($id, $nuevo, (int)$yo['id'], txt($d, 'nota', 255));
    json_out(['ok' => true, 'mensaje' => $o['folio'] . ': ' . ESTADOS[$nuevo] . '.']);

case 'orden_eliminar':
    solo_admin($esAdmin);
    $pdo->prepare('DELETE FROM ordenes_correctivas WHERE id = ?')->execute([id_de($d)]);
    json_out(['ok' => true, 'mensaje' => 'Orden eliminada.']);

/* =================================================================== EQUIPOS */
case 'equipos_listar':
    $filas = $pdo->query(
        "SELECT e.*, t.tarjeta, t.nombre AS asignado,
                (SELECT COUNT(*) FROM ordenes_correctivas o WHERE o.equipo_id = e.id) AS fallas,
                (SELECT COUNT(*) FROM ordenes_correctivas o WHERE o.equipo_id = e.id AND o.estado <> 'finalizada') AS abiertas,
                (SELECT MIN(p.fecha) FROM preventivos p WHERE p.equipo_id = e.id AND p.estado = 'programado') AS prox_preventivo
           FROM equipos e LEFT JOIN trabajadores t ON t.id = e.trabajador_id
          ORDER BY e.activo DESC, e.identificador")->fetchAll();
    json_out(['ok' => true, 'equipos' => $filas]);

case 'equipo_guardar':
    $id = id_de($d);
    $ident = strtoupper(txt($d, 'identificador', 40));
    $nombre = txt($d, 'nombre', 120);
    if ($ident === '' || $nombre === '') json_out(['ok' => false, 'error' => 'Escriba el identificador y el nombre del equipo.'], 422);
    $s = $pdo->prepare('SELECT id FROM equipos WHERE identificador = ? AND id <> ?');
    $s->execute([$ident, $id]);
    if ($s->fetchColumn()) json_out(['ok' => false, 'error' => 'Ya existe un equipo con el identificador ' . $ident . '.'], 409);

    $trabId = null; $t = null;
    $tarj = tarjeta_limpia($d['tarjeta'] ?? '');
    if ($tarj !== '') {
        $t = buscar_trabajador($tarj);
        if (!$t) json_out(['ok' => false, 'error' => 'La tarjeta ' . $tarj . ' no está registrada.'], 422);
        $trabId = (int)$t['id'];
    }
    $fechaN = fn(string $k) => fecha_sql($d[$k] ?? '');
    $campos = [
        'identificador' => $ident, 'nombre' => $nombre, 'tipo' => txt($d, 'tipo', 60) ?: 'Computadora',
        'marca' => txt($d, 'marca', 60) ?: null, 'modelo' => txt($d, 'modelo', 60) ?: null, 'serie' => txt($d, 'serie', 80) ?: null,
        'area' => txt($d, 'area', 80) ?: null, 'responsable' => txt($d, 'responsable', 120) ?: ($trabId ? $t['nombre'] : null),
        'trabajador_id' => $trabId, 'nombre_red' => txt($d, 'nombre_red', 80) ?: null, 'ip' => txt($d, 'ip', 60) ?: null,
        'hardware' => txt($d, 'hardware', 2000) ?: null, 'monitor' => txt($d, 'monitor', 255) ?: null,
        'perifericos' => txt($d, 'perifericos', 2000) ?: null, 'nivel_exposicion' => txt($d, 'nivel_exposicion', 20) ?: null,
        'estatus' => txt($d, 'estatus', 30) ?: null, 'frecuencia_mtto' => txt($d, 'frecuencia_mtto', 20) ?: null,
        'ultimo_mtto' => $fechaN('ultimo_mtto'), 'proximo_mtto' => $fechaN('proximo_mtto'),
        'notas' => txt($d, 'notas', 2000) ?: null, 'activo' => empty($d['activo']) ? 0 : 1,
    ];
    if ($id) {
        $pdo->prepare('UPDATE equipos SET ' . implode(', ', array_map(fn($c) => "$c = ?", array_keys($campos))) . ' WHERE id = ?')
            ->execute([...array_values($campos), $id]);
    } else {
        $pdo->prepare('INSERT INTO equipos (' . implode(', ', array_keys($campos)) . ') VALUES (' . implode(', ', array_fill(0, count($campos), '?')) . ')')
            ->execute(array_values($campos));
    }
    json_out(['ok' => true, 'mensaje' => 'Equipo ' . $ident . ' guardado.']);

case 'equipo_eliminar':
    solo_admin($esAdmin);
    $pdo->prepare('DELETE FROM equipos WHERE id = ?')->execute([id_de($d)]);
    json_out(['ok' => true, 'mensaje' => 'Equipo eliminado. Sus órdenes anteriores conservan el identificador.']);

/* =================================================================== PREVENTIVOS */
case 'preventivos_listar':
    $desde = fecha_sql($d['desde'] ?? '') ?? date('Y-m-01');
    $hasta = fecha_sql($d['hasta'] ?? '') ?? date('Y-m-t');
    $st = $pdo->prepare(
        'SELECT p.*, e.identificador, e.nombre AS equipo_nombre, u.nombre AS responsable
           FROM preventivos p LEFT JOIN equipos e ON e.id = p.equipo_id LEFT JOIN usuarios u ON u.id = p.responsable_id
          WHERE p.fecha BETWEEN ? AND ? ORDER BY p.fecha, p.id');
    $st->execute([$desde, $hasta]);
    json_out(['ok' => true, 'preventivos' => $st->fetchAll(), 'equipos' => equipos_min(), 'tecnicos' => tecnicos(), 'hoy' => date('Y-m-d')]);

case 'preventivo_guardar':
    $id = id_de($d);
    $titulo = txt($d, 'titulo', 150);
    $fecha = fecha_sql($d['fecha'] ?? '');
    $frec = (string)($d['frecuencia'] ?? 'unica');
    if ($titulo === '' || !$fecha) json_out(['ok' => false, 'error' => 'Escriba qué se va a hacer y la fecha.'], 422);
    if (!isset(FRECUENCIAS[$frec])) $frec = 'unica';
    $vals = [$titulo, id_de($d, 'equipo_id') ?: null, $fecha, $frec, id_de($d, 'responsable_id') ?: null, txt($d, 'notas', 2000) ?: null];
    if ($id) {
        $vals[] = $id;
        $pdo->prepare('UPDATE preventivos SET titulo=?, equipo_id=?, fecha=?, frecuencia=?, responsable_id=?, notas=? WHERE id=?')->execute($vals);
    } else {
        $pdo->prepare('INSERT INTO preventivos (titulo, equipo_id, fecha, frecuencia, responsable_id, notas) VALUES (?,?,?,?,?,?)')->execute($vals);
    }
    json_out(['ok' => true, 'mensaje' => 'Mantenimiento preventivo guardado.']);

case 'preventivo_estado':
    $id = id_de($d);
    $nuevo = (string)($d['estado'] ?? '');
    if (!in_array($nuevo, ['programado', 'realizado', 'cancelado'], true)) json_out(['ok' => false, 'error' => 'Estado no válido.'], 422);
    $st = $pdo->prepare('SELECT * FROM preventivos WHERE id = ?');
    $st->execute([$id]);
    $p = $st->fetch();
    if (!$p) json_out(['ok' => false, 'error' => 'No existe.'], 404);
    $pdo->prepare('UPDATE preventivos SET estado = ?, realizado_en = ' . ($nuevo === 'realizado' ? 'NOW()' : 'NULL') . ' WHERE id = ?')->execute([$nuevo, $id]);
    $msg = 'Marcado como ' . $nuevo . '.';
    if ($nuevo === 'realizado' && $p['estado'] !== 'realizado' && ($sig = siguiente_fecha($p['fecha'], $p['frecuencia']))) {
        $s = $pdo->prepare("SELECT 1 FROM preventivos WHERE titulo = ? AND fecha = ? AND (equipo_id <=> ?) AND estado = 'programado'");
        $s->execute([$p['titulo'], $sig, $p['equipo_id']]);
        if (!$s->fetchColumn()) {
            $pdo->prepare('INSERT INTO preventivos (titulo, equipo_id, fecha, frecuencia, responsable_id, notas) VALUES (?,?,?,?,?,?)')
                ->execute([$p['titulo'], $p['equipo_id'], $sig, $p['frecuencia'], $p['responsable_id'], $p['notas']]);
            $msg .= ' Siguiente programado para el ' . date('d/m/Y', strtotime($sig)) . '.';
        }
    }
    json_out(['ok' => true, 'mensaje' => $msg]);

case 'preventivo_eliminar':
    $pdo->prepare('DELETE FROM preventivos WHERE id = ?')->execute([id_de($d)]);
    json_out(['ok' => true, 'mensaje' => 'Eliminado del calendario.']);

/* =================================================================== USUARIOS (trabajadores + cuentas) */
case 'usuarios_listar':
    $trab = $pdo->query(
        "SELECT t.*, u.id AS usuario_id, u.usuario, u.rol, u.activo AS cuenta_activa,
                (SELECT COUNT(*) FROM ordenes_correctivas o WHERE o.reporta_id = t.id) AS reportes,
                (SELECT COUNT(*) FROM ordenes_correctivas o WHERE o.reporta_id = t.id AND o.creado >= NOW() - INTERVAL 90 DAY) AS reportes90,
                (SELECT COUNT(*) FROM equipos e WHERE e.trabajador_id = t.id) AS equipos
           FROM trabajadores t LEFT JOIN usuarios u ON u.trabajador_id = t.id
          ORDER BY t.activo DESC, t.nombre")->fetchAll();
    $sinTarjeta = $pdo->query('SELECT id, nombre, usuario, rol, activo FROM usuarios WHERE trabajador_id IS NULL ORDER BY nombre')->fetchAll();
    $porPersona = $pdo->query(
        "SELECT o.reporta_nombre AS nombre, o.reporta_tarjeta AS tarjeta, COUNT(*) AS n,
                GROUP_CONCAT(DISTINCT o.equipo_ident ORDER BY o.equipo_ident SEPARATOR ', ') AS equipos
           FROM ordenes_correctivas o WHERE o.creado >= NOW() - INTERVAL 90 DAY
          GROUP BY o.reporta_tarjeta, o.reporta_nombre ORDER BY n DESC LIMIT 8")->fetchAll();
    $porEquipo = $pdo->query(
        "SELECT o.equipo_ident AS equipo, MAX(t.nombre) AS responsable, COUNT(*) AS n,
                SUM(o.tipo_falla='hardware') AS hardware, SUM(o.tipo_falla='software') AS software
           FROM ordenes_correctivas o LEFT JOIN equipos e ON e.id = o.equipo_id LEFT JOIN trabajadores t ON t.id = e.trabajador_id
          WHERE o.creado >= NOW() - INTERVAL 90 DAY
          GROUP BY o.equipo_ident ORDER BY n DESC LIMIT 8")->fetchAll();
    json_out(['ok' => true, 'trabajadores' => $trab, 'cuentas_sin_tarjeta' => $sinTarjeta,
              'por_persona' => $porPersona, 'por_equipo' => $porEquipo, 'es_admin' => $esAdmin, 'yo' => (int)$yo['id']]);

case 'trabajador_guardar':
    solo_admin($esAdmin);
    $id = id_de($d);
    $tarj = tarjeta_limpia($d['tarjeta'] ?? '');
    $nombre = txt($d, 'nombre', 120);
    if ($tarj === '' || strlen($tarj) > 20 || $nombre === '') json_out(['ok' => false, 'error' => 'Escriba la tarjeta y el nombre.'], 422);
    $s = $pdo->prepare('SELECT id FROM trabajadores WHERE tarjeta = ? AND id <> ?');
    $s->execute([$tarj, $id]);
    if ($s->fetchColumn()) json_out(['ok' => false, 'error' => 'La tarjeta ' . $tarj . ' ya está registrada.'], 409);

    // Acceso al panel (opcional)
    $rol = (string)($d['rol'] ?? '');
    $usuario = txt($d, 'usuario', 50);
    $pass = (string)($d['password'] ?? '');
    if ($rol !== '' && !in_array($rol, ['administrador', 'tecnico'], true)) $rol = '';

    $pdo->beginTransaction();
    $activo = empty($d['activo']) ? 0 : 1;
    $vals = [$tarj, $nombre, txt($d, 'area', 80) ?: null, txt($d, 'puesto', 80) ?: null, $activo];
    if ($id) {
        $vals[] = $id;
        $pdo->prepare('UPDATE trabajadores SET tarjeta=?, nombre=?, area=?, puesto=?, activo=? WHERE id=?')->execute($vals);
    } else {
        $pdo->prepare('INSERT INTO trabajadores (tarjeta, nombre, area, puesto, activo) VALUES (?,?,?,?,?)')->execute($vals);
        $id = (int)$pdo->lastInsertId();
    }

    $s = $pdo->prepare('SELECT id, rol FROM usuarios WHERE trabajador_id = ?');
    $s->execute([$id]);
    $cuenta = $s->fetch();
    if ($rol === '') {
        if ($cuenta) {
            if ((int)$cuenta['id'] === (int)$yo['id']) { $pdo->rollBack(); json_out(['ok' => false, 'error' => 'No puede quitarse su propio acceso.'], 422); }
            $pdo->prepare('DELETE FROM usuarios WHERE id = ?')->execute([$cuenta['id']]);
        }
    } else {
        if (!preg_match('/^[A-Za-z0-9._-]{3,50}$/', $usuario)) {
            $pdo->rollBack();
            json_out(['ok' => false, 'error' => 'El usuario del panel debe tener 3 a 50 letras, números, punto o guion.'], 422);
        }
        $s = $pdo->prepare('SELECT id FROM usuarios WHERE usuario = ? AND (trabajador_id IS NULL OR trabajador_id <> ?)');
        $s->execute([$usuario, $id]);
        if ($s->fetchColumn()) { $pdo->rollBack(); json_out(['ok' => false, 'error' => 'El usuario «' . $usuario . '» ya existe.'], 409); }
        if (!$cuenta && strlen($pass) < 8) { $pdo->rollBack(); json_out(['ok' => false, 'error' => 'La contraseña del panel debe tener al menos 8 caracteres.'], 422); }
        if ($pass !== '' && strlen($pass) < 8) { $pdo->rollBack(); json_out(['ok' => false, 'error' => 'La contraseña debe tener al menos 8 caracteres.'], 422); }
        if ($cuenta && (int)$cuenta['id'] === (int)$yo['id'] && ($rol !== 'administrador' || !$activo)) {
            $pdo->rollBack(); json_out(['ok' => false, 'error' => 'No puede quitarse a sí mismo el rol de administrador ni darse de baja.'], 422);
        }
        if ($cuenta) {
            $sql = 'UPDATE usuarios SET nombre=?, usuario=?, rol=?, activo=?' . ($pass !== '' ? ', password=?' : '') . ' WHERE id=?';
            $v = [$nombre, $usuario, $rol, $activo];
            if ($pass !== '') $v[] = password_hash($pass, PASSWORD_DEFAULT);
            $v[] = $cuenta['id'];
            $pdo->prepare($sql)->execute($v);
        } else {
            $pdo->prepare('INSERT INTO usuarios (nombre, usuario, password, rol, trabajador_id, activo) VALUES (?,?,?,?,?,?)')
                ->execute([$nombre, $usuario, password_hash($pass, PASSWORD_DEFAULT), $rol, $id, $activo]);
        }
    }
    $pdo->commit();
    json_out(['ok' => true, 'mensaje' => $nombre . ' guardado.']);

case 'trabajador_eliminar':
    solo_admin($esAdmin);
    $id = id_de($d);
    $s = $pdo->prepare('SELECT id FROM usuarios WHERE trabajador_id = ?');
    $s->execute([$id]);
    $uid = (int)$s->fetchColumn();
    if ($uid === (int)$yo['id']) json_out(['ok' => false, 'error' => 'No puede eliminar su propia tarjeta.'], 422);
    $pdo->beginTransaction();
    if ($uid) $pdo->prepare('DELETE FROM usuarios WHERE id = ?')->execute([$uid]);
    $pdo->prepare('DELETE FROM trabajadores WHERE id = ?')->execute([$id]);
    $pdo->commit();
    json_out(['ok' => true, 'mensaje' => 'Trabajador eliminado. Sus reportes anteriores se conservan.']);

case 'cuenta_guardar':   // cuentas del panel que aún no tienen tarjeta (por ejemplo «admin»)
    solo_admin($esAdmin);
    $id = id_de($d);
    $s = $pdo->prepare('SELECT * FROM usuarios WHERE id = ? AND trabajador_id IS NULL');
    $s->execute([$id]);
    $c = $s->fetch();
    if (!$c) json_out(['ok' => false, 'error' => 'Cuenta no encontrada.'], 404);
    $rol = (string)($d['rol'] ?? $c['rol']);
    if (!in_array($rol, ['administrador', 'tecnico', 'usuario'], true)) $rol = $c['rol'];
    $activo = empty($d['activo']) ? 0 : 1;
    if ($id === (int)$yo['id'] && ($rol !== 'administrador' || !$activo)) {
        json_out(['ok' => false, 'error' => 'No puede quitarse a sí mismo el rol de administrador ni darse de baja.'], 422);
    }
    $pass = (string)($d['password'] ?? '');
    if ($pass !== '' && strlen($pass) < 8) json_out(['ok' => false, 'error' => 'La contraseña debe tener al menos 8 caracteres.'], 422);
    $trabId = null;
    $tarj = tarjeta_limpia($d['tarjeta'] ?? '');
    if ($tarj !== '') {
        $t = buscar_trabajador($tarj);
        if (!$t) json_out(['ok' => false, 'error' => 'La tarjeta ' . $tarj . ' no está registrada. Regístrela primero en Trabajadores.'], 422);
        $s = $pdo->prepare('SELECT 1 FROM usuarios WHERE trabajador_id = ?');
        $s->execute([$t['id']]);
        if ($s->fetchColumn()) json_out(['ok' => false, 'error' => 'Esa tarjeta ya tiene una cuenta del panel.'], 409);
        $trabId = (int)$t['id'];
    }
    $sql = 'UPDATE usuarios SET rol=?, activo=?, trabajador_id=?' . ($pass !== '' ? ', password=?' : '') . ' WHERE id=?';
    $v = [$rol, $activo, $trabId];
    if ($pass !== '') $v[] = password_hash($pass, PASSWORD_DEFAULT);
    $v[] = $id;
    $pdo->prepare($sql)->execute($v);
    json_out(['ok' => true, 'mensaje' => 'Cuenta «' . $c['usuario'] . '» guardada.']);

case 'cuenta_eliminar':
    solo_admin($esAdmin);
    $id = id_de($d);
    if ($id === (int)$yo['id']) json_out(['ok' => false, 'error' => 'No puede eliminar su propia cuenta.'], 422);
    $pdo->prepare('DELETE FROM usuarios WHERE id = ? AND trabajador_id IS NULL')->execute([$id]);
    json_out(['ok' => true, 'mensaje' => 'Cuenta eliminada.']);

case 'trabajadores_importar':   // filas leídas del Excel en el navegador
    solo_admin($esAdmin);
    $filas = is_array($d['filas'] ?? null) ? $d['filas'] : [];
    if (!$filas || count($filas) > 5000) json_out(['ok' => false, 'error' => 'El archivo no tiene filas válidas (máximo 5000).'], 422);
    $nuevos = $act = $omit = 0;
    $pdo->beginTransaction();
    $ins = $pdo->prepare('INSERT INTO trabajadores (tarjeta, nombre, area, puesto, activo) VALUES (?,?,?,?,?)
                          ON DUPLICATE KEY UPDATE nombre=VALUES(nombre), area=VALUES(area), puesto=VALUES(puesto), activo=VALUES(activo)');
    foreach ($filas as $f) {
        $tarj = tarjeta_limpia($f['tarjeta'] ?? '');
        $nom = mb_substr(trim((string)($f['nombre'] ?? '')), 0, 120);
        if ($tarj === '' || strlen($tarj) > 20 || $nom === '') { $omit++; continue; }
        $st = mb_strtolower(trim((string)($f['status'] ?? '')));
        $activo = ($st === '' || !preg_match('/baja|inactiv/u', $st)) ? 1 : 0;
        $ins->execute([$tarj, $nom, mb_substr(trim((string)($f['area'] ?? '')), 0, 80) ?: null, mb_substr(trim((string)($f['puesto'] ?? '')), 0, 80) ?: null, $activo]);
        $ins->rowCount() === 1 ? $nuevos++ : $act++;
    }
    $pdo->commit();
    json_out(['ok' => true, 'mensaje' => "Importación lista: $nuevos nuevos, $act actualizados, $omit filas omitidas."]);

default:
    json_out(['ok' => false, 'error' => 'Acción no reconocida.'], 400);
}
