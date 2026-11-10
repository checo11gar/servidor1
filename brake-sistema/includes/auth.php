<?php
/**
 * includes/auth.php
 * Sesiones, roles, CSRF y utilidades compartidas por todo el sistema.
 */
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

if (session_status() === PHP_SESSION_NONE) {
    session_name('BRAKESESS');
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'secure'   => !empty($_SERVER['HTTPS']),
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    session_start();
}

// Cierre por inactividad
if (isset($_SESSION['ultima_actividad']) && (time() - $_SESSION['ultima_actividad']) > SESSION_IDLE_SECONDS) {
    $_SESSION = [];
    session_destroy();
    session_start();
}
$_SESSION['ultima_actividad'] = time();

header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: SAMEORIGIN');
header('Referrer-Policy: same-origin');

/** Escapa texto para imprimirlo en HTML. */
function e(?string $s): string
{
    return htmlspecialchars((string)$s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Respuesta JSON y fin de la ejecución. */
function json_out(array $data, int $code = 200): never
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

/** Usuario en sesión (se revalida contra la BD para respetar cambios de rol/baja). */
function usuario_actual(): ?array
{
    static $cache = false;
    if ($cache !== false) {
        return $cache;
    }
    if (empty($_SESSION['uid'])) {
        return $cache = null;
    }
    $st = db()->prepare('SELECT id, nombre, usuario, rol FROM usuarios WHERE id = ? AND activo = 1');
    $st->execute([(int)$_SESSION['uid']]);
    $u = $st->fetch();
    return $cache = ($u ?: null);
}

function es_admin(): bool
{
    $u = usuario_actual();
    return $u !== null && $u['rol'] === 'administrador';
}

/** Exige sesión iniciada. $json=true responde 401 en JSON en vez de redirigir. */
function require_login(bool $json = false): array
{
    $u = usuario_actual();
    if ($u === null) {
        if ($json) {
            json_out(['ok' => false, 'error' => 'Su sesión expiró. Inicie sesión de nuevo.'], 401);
        }
        header('Location: ' . app_url('login.php'));
        exit;
    }
    return $u;
}

/** Exige rol administrador. Un usuario normal recibe 403. */
function require_admin(bool $json = false): array
{
    $u = require_login($json);
    if ($u['rol'] !== 'administrador') {
        if ($json) {
            json_out(['ok' => false, 'error' => 'No tiene permisos de administrador.'], 403);
        }
        http_response_code(403);
        exit('Acceso denegado: se requiere rol de administrador.');
    }
    return $u;
}

/** URL absoluta (desde la raíz del servidor) de un archivo del proyecto. */
function app_url(string $path = ''): string
{
    $raiz = str_replace('\\', '/', BASE_PATH);
    $doc  = rtrim(str_replace('\\', '/', (string)($_SERVER['DOCUMENT_ROOT'] ?? '')), '/');
    $base = ($doc !== '' && str_starts_with($raiz, $doc)) ? substr($raiz, strlen($doc)) : '';
    return $base . '/' . ltrim($path, '/');
}

// ---- CSRF ---------------------------------------------------------------
function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

/** Valida el token enviado por POST (campo csrf) o cabecera X-CSRF-Token. */
function csrf_ok(): bool
{
    $enviado = $_POST['csrf'] ?? ($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
    return is_string($enviado) && $enviado !== '' && hash_equals($_SESSION['csrf'] ?? '', $enviado);
}
