<?php
/**
 * api/publico.php — Acceso SIN contraseña, solo con número de tarjeta.
 *   POST accion=buscar   {tarjeta}           → datos del trabajador, sus equipos y sus últimas órdenes
 *   POST accion=reportar {tarjeta, …formato} → crea la orden de mantenimiento correctivo
 * Todas las peticiones llevan el token CSRF de la sesión en la cabecera X-CSRF-Token.
 */
declare(strict_types=1);
require_once __DIR__ . '/../includes/mtto.php';

exigir_post_csrf();
$d = cuerpo_json();
$accion = (string)($d['accion'] ?? '');

// Límite simple contra pruebas de tarjetas: 15 tarjetas no encontradas cada 10 minutos por sesión.
$_SESSION['tarj_fallos'] = array_values(array_filter(
    (array)($_SESSION['tarj_fallos'] ?? []),
    fn($t) => $t > time() - 600
));
if (count($_SESSION['tarj_fallos']) >= 15) {
    json_out(['ok' => false, 'error' => 'Demasiados intentos. Espere unos minutos.'], 429);
}

$tarjeta = tarjeta_limpia($d['tarjeta'] ?? '');
$trab = buscar_trabajador($tarjeta);
if (!$trab) {
    $_SESSION['tarj_fallos'][] = time();
    json_out(['ok' => false, 'error' => 'Ese número de tarjeta no está registrado. Pida a Mantenimiento que lo den de alta.'], 404);
}
if ((int)$trab['activo'] !== 1) {
    json_out(['ok' => false, 'error' => 'Esa tarjeta está dada de baja. Consulte con Mantenimiento.'], 403);
}
$trabId = (int)$trab['id'];

if ($accion === 'buscar') {
    // Ficha completa solo de los equipos asignados a esta tarjeta.
    $st = db()->prepare('SELECT id, identificador, nombre, tipo, marca, modelo, serie, area, responsable, nombre_red, ip,
                                hardware, monitor, perifericos, estatus, frecuencia_mtto, ultimo_mtto, proximo_mtto, notas,
                                (SELECT MIN(p.fecha) FROM preventivos p WHERE p.equipo_id = equipos.id AND p.estado = \'programado\') AS prox_preventivo,
                                (SELECT COUNT(*) FROM ordenes_correctivas o WHERE o.equipo_id = equipos.id AND o.estado <> \'finalizada\') AS abiertas
                           FROM equipos WHERE trabajador_id = ? AND activo = 1 ORDER BY identificador');
    $st->execute([$trabId]);
    $mios = $st->fetchAll();

    // Del resto solo lo necesario para elegirlo en la lista.
    $todos = db()->query('SELECT id, identificador, nombre, tipo, area, responsable FROM equipos WHERE activo = 1 ORDER BY area, identificador')->fetchAll();

    $st = db()->prepare('SELECT id, folio, token, estado, tipo_falla, prioridad, equipo_ident, fecha_paro, creado, reporte
                           FROM ordenes_correctivas WHERE reporta_id = ? ORDER BY id DESC LIMIT 10');
    $st->execute([$trabId]);
    $ordenes = array_map(function ($o) {
        $o['estado_texto'] = ESTADOS[$o['estado']] ?? $o['estado'];
        $o['reporte'] = mb_strimwidth((string)$o['reporte'], 0, 90, '…');
        return $o;
    }, $st->fetchAll());

    json_out([
        'ok' => true,
        'trabajador' => ['tarjeta' => $trab['tarjeta'], 'nombre' => $trab['nombre'], 'area' => $trab['area'], 'puesto' => $trab['puesto']],
        'mis_equipos' => $mios,
        'equipos' => $todos,
        'ordenes' => $ordenes,
    ]);
}

if ($accion === 'reportar') {
    $reporte = trim((string)($d['reporte'] ?? ''));
    if (mb_strlen($reporte) < 5) {
        json_out(['ok' => false, 'error' => 'Describa la falla en «Reporte del mantenimiento».'], 422);
    }
    $tipo = (string)($d['tipo_falla'] ?? '');
    if (!isset(TIPOS_FALLA[$tipo])) {
        json_out(['ok' => false, 'error' => 'Indique si la falla es de hardware o de software.'], 422);
    }
    $prioridad = (string)($d['prioridad'] ?? 'media');
    if (!isset(PRIORIDADES[$prioridad])) $prioridad = 'media';

    $fechaParo = fecha_hora_sql($d['fecha_paro'] ?? '') ?? date('Y-m-d H:i:00');
    if (strtotime($fechaParo) > time() + 300) {
        json_out(['ok' => false, 'error' => 'La fecha y hora de paro no puede ser futura.'], 422);
    }

    // Equipo: uno del catálogo o un identificador escrito a mano.
    $equipoId = null;
    $equipoIdent = mb_substr(trim((string)($d['equipo_ident'] ?? '')), 0, 60);
    $eid = filter_var($d['equipo_id'] ?? null, FILTER_VALIDATE_INT);
    if ($eid) {
        $st = db()->prepare('SELECT id, identificador FROM equipos WHERE id = ? AND activo = 1');
        $st->execute([$eid]);
        if ($eq = $st->fetch()) {
            $equipoId = (int)$eq['id'];
            $equipoIdent = $eq['identificador'];
        }
    }
    if ($equipoIdent === '') {
        json_out(['ok' => false, 'error' => 'Indique el identificador del equipo.'], 422);
    }

    $area = mb_substr(trim((string)($d['area'] ?? '')), 0, 80) ?: $trab['area'];
    $firma = firma_valida($d['firma_reporto'] ?? '');

    $pdo = db();
    $pdo->beginTransaction();
    $token = bin2hex(random_bytes(16));
    $pdo->prepare(
        'INSERT INTO ordenes_correctivas
           (token, estado, tipo_falla, prioridad, area, reporta_id, reporta_tarjeta, reporta_nombre,
            equipo_id, equipo_ident, fecha_paro, reporte, firma_reporto, fecha_firma_reporto)
         VALUES (?, \'pendiente\', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURDATE())'
    )->execute([
        $token, $tipo, $prioridad, $area, $trabId, $trab['tarjeta'], $trab['nombre'],
        $equipoId, $equipoIdent, $fechaParo, mb_substr($reporte, 0, 5000), $firma,
    ]);
    $id = (int)$pdo->lastInsertId();
    $folio = sprintf('OMC-%05d', $id);
    $pdo->prepare('UPDATE ordenes_correctivas SET folio = ? WHERE id = ?')->execute([$folio, $id]);
    registrar_historial($id, 'pendiente', null, 'Reportada por ' . $trab['nombre'] . ' (tarjeta ' . $trab['tarjeta'] . ')');
    $pdo->commit();

    json_out(['ok' => true, 'id' => $id, 'folio' => $folio, 'token' => $token]);
}

json_out(['ok' => false, 'error' => 'Acción no reconocida.'], 400);
