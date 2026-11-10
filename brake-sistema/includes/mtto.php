<?php
/**
 * includes/mtto.php
 * Reglas compartidas del módulo de mantenimiento: estados, prioridades,
 * cálculo de tiempos, folio y permisos del panel.
 */
declare(strict_types=1);

require_once __DIR__ . '/auth.php';

const ESTADOS = [
    'pendiente'  => 'Pendiente',
    'verificada' => 'Verificada',
    'en_proceso' => 'En proceso',
    'finalizada' => 'Finalizada',
];
const PRIORIDADES = ['baja' => 'Baja', 'media' => 'Media', 'alta' => 'Alta', 'critica' => 'Crítica'];
const TIPOS_FALLA = ['hardware' => 'Hardware', 'software' => 'Software'];
const FRECUENCIAS = [
    'unica' => 'Única vez', 'semanal' => 'Semanal', 'mensual' => 'Mensual', 'bimestral' => 'Bimestral',
    'trimestral' => 'Trimestral', 'semestral' => 'Semestral', 'anual' => 'Anual',
];

/** ¿Puede entrar al panel? (administrador o técnico) */
function es_personal_mtto(?array $u = null): bool
{
    $u ??= usuario_actual();
    return $u !== null && in_array($u['rol'], ['administrador', 'tecnico'], true);
}

/** Exige sesión de administrador o técnico. */
function require_panel(bool $json = false): array
{
    $u = require_login($json);
    if (!es_personal_mtto($u)) {
        if ($json) {
            json_out(['ok' => false, 'error' => 'Solo personal de mantenimiento o administradores.'], 403);
        }
        header('Location: ' . app_url('index.php'));
        exit;
    }
    return $u;
}

/** Minutos entre dos fechas 'Y-m-d H:i:s' (null si falta alguna o es negativo). */
function minutos_entre(?string $a, ?string $b): ?int
{
    if (!$a || !$b) return null;
    $m = (int)round((strtotime($b) - strtotime($a)) / 60);
    return $m >= 0 ? $m : null;
}

/** 135 → "2 h 15 min" */
function duracion_texto(?int $min): string
{
    if ($min === null) return '';
    $h = intdiv($min, 60);
    $m = $min % 60;
    if ($h >= 24) {
        $d = intdiv($h, 24);
        $h %= 24;
        return $d . ' d ' . $h . ' h ' . $m . ' min';
    }
    return ($h ? $h . ' h ' : '') . $m . ' min';
}

/** Convierte "2026-10-21T08:30" o "2026-10-21 08:30" a formato MySQL; null si vacío o inválido. */
function fecha_hora_sql(mixed $v): ?string
{
    $v = trim((string)$v);
    if ($v === '') return null;
    $t = strtotime(str_replace('T', ' ', $v));
    return $t ? date('Y-m-d H:i:00', $t) : null;
}

function fecha_sql(mixed $v): ?string
{
    $v = trim((string)$v);
    if ($v === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $v)) return null;
    return $v;
}

/** Acepta solo una firma PNG en base64 razonable (≤ 300 KB). */
function firma_valida(mixed $v): ?string
{
    $v = (string)$v;
    if ($v === '') return null;
    if (strlen($v) > 400000 || !preg_match('#^data:image/png;base64,[A-Za-z0-9+/=]+$#', $v)) return null;
    return $v;
}

/** Normaliza un número de tarjeta: sin espacios; los ceros a la izquierda no importan al buscar. */
function tarjeta_limpia(mixed $v): string
{
    return preg_replace('/\s+/', '', trim((string)$v));
}

/** Busca un trabajador activo por tarjeta (tolera ceros a la izquierda). */
function buscar_trabajador(string $tarjeta): ?array
{
    if ($tarjeta === '' || strlen($tarjeta) > 20) return null;
    $sinCeros = ltrim($tarjeta, '0');
    $st = db()->prepare(
        "SELECT id, tarjeta, nombre, area, puesto, activo FROM trabajadores
          WHERE tarjeta = ? OR (TRIM(LEADING '0' FROM tarjeta) = ? AND ? <> '')
          ORDER BY tarjeta = ? DESC LIMIT 1"
    );
    $st->execute([$tarjeta, $sinCeros, $sinCeros, $tarjeta]);
    $t = $st->fetch();
    return $t ?: null;
}

/** Guarda el cambio de estado en la bitácora. */
function registrar_historial(int $ordenId, string $estado, ?int $usuarioId, string $nota = ''): void
{
    db()->prepare('INSERT INTO ordenes_historial (orden_id, estado, usuario_id, nota) VALUES (?, ?, ?, ?)')
        ->execute([$ordenId, $estado, $usuarioId, mb_substr($nota, 0, 255)]);
}

/** Formatea una orden para enviarla al navegador (agrega textos y tiempos calculados). */
function orden_para_json(array $o, bool $conFirmas = true): array
{
    $o['id'] = (int)$o['id'];
    $o['estado_texto']    = ESTADOS[$o['estado']] ?? $o['estado'];
    $o['prioridad_texto'] = PRIORIDADES[$o['prioridad']] ?? $o['prioridad'];
    $o['tipo_texto']      = TIPOS_FALLA[$o['tipo_falla']] ?? $o['tipo_falla'];
    $o['tiempo_mtto_min']   = minutos_entre($o['fecha_ejecucion'], $o['fecha_entrega']);
    $o['tiempo_muerto_min'] = minutos_entre($o['fecha_paro'], $o['fecha_entrega']);
    $o['tiempo_mtto']   = duracion_texto($o['tiempo_mtto_min']);
    $o['tiempo_muerto'] = duracion_texto($o['tiempo_muerto_min']);
    if (!$conFirmas) {
        $o['tiene_firma_reporto'] = !empty($o['firma_reporto']);
        unset($o['firma_reporto'], $o['firma_ejecuto'], $o['firma_recibio']);
    }
    return $o;
}

/** Siguiente fecha de un preventivo periódico. */
function siguiente_fecha(string $fecha, string $frecuencia): ?string
{
    $saltos = [
        'semanal' => '+1 week', 'mensual' => '+1 month', 'bimestral' => '+2 months',
        'trimestral' => '+3 months', 'semestral' => '+6 months', 'anual' => '+1 year',
    ];
    if (!isset($saltos[$frecuencia])) return null;
    return date('Y-m-d', strtotime($fecha . ' ' . $saltos[$frecuencia]));
}

/** Leer el cuerpo JSON de una petición POST. */
function cuerpo_json(): array
{
    $raw = file_get_contents('php://input') ?: '';
    $d = json_decode($raw, true);
    return is_array($d) ? $d : [];
}

/** CSRF desde cabecera (las peticiones JSON lo mandan en X-CSRF-Token). */
function exigir_post_csrf(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_out(['ok' => false, 'error' => 'Método no permitido.'], 405);
    }
    if (!csrf_ok()) {
        json_out(['ok' => false, 'error' => 'La página expiró. Recárguela e intente de nuevo.'], 419);
    }
}
