<?php
/**
 * includes/firmas.php
 * NIP de 4 dígitos (guardado solo como hash) y firmas electrónicas.
 * Flujo de firma: el usuario escribe su NIP → el servidor lo identifica, comprueba que pueda firmar
 * ese bloque y deja una autorización en la sesión → al guardar la orden el SERVIDOR toma la imagen
 * de la tabla «firmas» (nunca se acepta una imagen enviada por el navegador).
 */
declare(strict_types=1);

require_once __DIR__ . '/mtto.php';

const NIP_MAX_FALLOS = 8;          // intentos fallidos permitidos por IP…
const NIP_VENTANA_SEG = 600;       // …cada 10 minutos
const FIRMA_VIGENCIA_SEG = 1800;   // una firma autorizada se puede guardar durante 30 minutos
const BLOQUES_FIRMA = ['reporto', 'ejecuto', 'recibio'];

function nip_formato_ok(mixed $v): bool
{
    return is_string($v) && preg_match('/^\d{4}$/', $v) === 1;
}

function ip_cliente(): string
{
    return mb_substr((string)($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0'), 0, 45);
}

/** ¿Esta IP ya agotó sus intentos fallidos? */
function nip_bloqueado(): bool
{
    $st = db()->prepare('SELECT COUNT(*) FROM nip_intentos WHERE ip = ? AND creado > NOW() - INTERVAL ' . NIP_VENTANA_SEG . ' SECOND');
    $st->execute([ip_cliente()]);
    return (int)$st->fetchColumn() >= NIP_MAX_FALLOS;
}

function nip_registrar_fallo(): void
{
    db()->prepare('INSERT INTO nip_intentos (ip) VALUES (?)')->execute([ip_cliente()]);
    if (random_int(1, 50) === 1) {   // limpieza ocasional
        db()->exec('DELETE FROM nip_intentos WHERE creado < NOW() - INTERVAL 1 DAY');
    }
}

/**
 * Busca al usuario activo dueño de un NIP (null si nadie lo tiene).
 * $excluirId: ignora a ese usuario (para comprobar que el NIP nuevo no lo use otra persona).
 */
function nip_buscar_usuario(string $nip, ?int $excluirId = null, bool $soloActivos = true): ?array
{
    $filas = db()->query('SELECT id, nombre, usuario, rol, trabajador_id, nip_hash FROM usuarios WHERE nip_hash IS NOT NULL' . ($soloActivos ? ' AND activo = 1' : ''))->fetchAll();
    foreach ($filas as $f) {
        if ($excluirId !== null && (int)$f['id'] === $excluirId) continue;
        if (password_verify($nip, (string)$f['nip_hash'])) {
            unset($f['nip_hash']);
            return $f;
        }
    }
    return null;
}

/** Imagen de firma de un usuario (data URL PNG) o null. */
function firma_de_usuario(int $usuarioId): ?string
{
    $st = db()->prepare('SELECT imagen FROM firmas WHERE usuario_id = ?');
    $st->execute([$usuarioId]);
    $img = $st->fetchColumn();
    return $img ? (string)$img : null;
}

/**
 * Valida un NIP para firmar un bloque. Responde en JSON si algo falla; si todo va bien devuelve el usuario.
 * $ctx: 'publico' (el reportante se identifica con su tarjeta) o 'panel'.
 * $reportanteId: id del trabajador que reporta (solo bloque «reporto»).
 */
function firmar_con_nip(string $bloque, mixed $nip, ?int $reportanteId = null): array
{
    if (!in_array($bloque, BLOQUES_FIRMA, true)) {
        json_out(['ok' => false, 'error' => 'Bloque de firma no válido.'], 422);
    }
    if (!nip_formato_ok($nip)) {
        json_out(['ok' => false, 'error' => 'El NIP debe ser de 4 dígitos.'], 422);
    }
    if (nip_bloqueado()) {
        json_out(['ok' => false, 'error' => 'Demasiados intentos fallidos. Espere unos minutos.'], 429);
    }
    $u = nip_buscar_usuario($nip);
    if (!$u) {
        nip_registrar_fallo();
        json_out(['ok' => false, 'error' => 'NIP incorrecto.'], 401);
    }
    if ($bloque === 'reporto' && $reportanteId !== null && (int)($u['trabajador_id'] ?? 0) !== $reportanteId) {
        nip_registrar_fallo();
        json_out(['ok' => false, 'error' => 'Ese NIP no pertenece a quien reporta.'], 403);
    }
    if ($bloque === 'ejecuto' && !in_array($u['rol'], ['administrador', 'tecnico'], true)) {
        json_out(['ok' => false, 'error' => 'Solo personal de mantenimiento puede firmar como quien ejecutó.'], 403);
    }
    $img = firma_de_usuario((int)$u['id']);
    if (!$img) {
        json_out(['ok' => false, 'error' => 'Su usuario no tiene firma cargada. Pida al administrador que la cargue.'], 409);
    }
    $_SESSION['firmas_ok'][$bloque] = ['uid' => (int)$u['id'], 't' => time()];
    return ['usuario' => $u, 'imagen' => $img];
}

/** Autorización vigente para un bloque: ['uid'=>…, 'nombre'=>…, 'imagen'=>…] o null. La imagen sale de la BD. */
function firma_autorizada(string $bloque): ?array
{
    $a = $_SESSION['firmas_ok'][$bloque] ?? null;
    if (!is_array($a) || (time() - (int)$a['t']) > FIRMA_VIGENCIA_SEG) return null;
    $st = db()->prepare('SELECT u.id, u.nombre, f.imagen FROM usuarios u JOIN firmas f ON f.usuario_id = u.id WHERE u.id = ? AND u.activo = 1');
    $st->execute([(int)$a['uid']]);
    $r = $st->fetch();
    return $r ? ['uid' => (int)$r['id'], 'nombre' => (string)$r['nombre'], 'imagen' => (string)$r['imagen']] : null;
}

function firma_consumir(string $bloque): void
{
    unset($_SESSION['firmas_ok'][$bloque]);
}

/** Foto de perfil: JPEG/PNG/WebP en base64, hasta ~300 KB. */
function foto_valida(mixed $v): ?string
{
    $v = (string)$v;
    if ($v === '' || strlen($v) > 400000) return null;
    return preg_match('#^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$#', $v) ? $v : null;
}
