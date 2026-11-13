<?php
/**
 * login.php — Acceso al panel de reportes.
 * Solo entran administradores y técnicos de mantenimiento.
 * Los demás trabajadores no necesitan contraseña: reportan con su tarjeta en index.php.
 */
declare(strict_types=1);
require_once __DIR__ . '/includes/mtto.php';

if (es_personal_mtto()) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
$usuarioIngresado = '';
$MAX_INTENTOS = 5;
$BLOQUEO_SEG  = 300;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $usuarioIngresado = trim((string)($_POST['usuario'] ?? ''));
    $password = (string)($_POST['password'] ?? '');

    $bloqueadoHasta = (int)($_SESSION['login_bloqueo'] ?? 0);
    if ($bloqueadoHasta > time()) {
        $error = 'Demasiados intentos. Espere unos minutos e intente de nuevo.';
    } elseif (!csrf_ok()) {
        $error = 'La página expiró. Intente de nuevo.';
    } else {
        $st = db()->prepare('SELECT id, password, activo, rol FROM usuarios WHERE usuario = ? LIMIT 1');
        $st->execute([$usuarioIngresado]);
        $u = $st->fetch();

        // Se verifica siempre un hash para que el tiempo de respuesta no revele si el usuario existe.
        $hash = $u['password'] ?? '$2y$10$abcdefghijklmnopqrstuuabcdefghijklmnopqrstuvwxyz01234';
        $valido = password_verify($password, $hash) && $u && (int)$u['activo'] === 1;

        if ($valido && !in_array($u['rol'], ['administrador', 'tecnico'], true)) {
            $error = 'Esta cuenta no tiene acceso al panel. Para reportar una falla use su número de tarjeta en la página de inicio.';
        } elseif ($valido) {
            session_regenerate_id(true);
            $_SESSION['uid'] = (int)$u['id'];
            $_SESSION['login_fallos'] = 0;
            unset($_SESSION['login_bloqueo']);
            if (password_needs_rehash($u['password'], PASSWORD_DEFAULT)) {
                db()->prepare('UPDATE usuarios SET password = ? WHERE id = ?')
                    ->execute([password_hash($password, PASSWORD_DEFAULT), $u['id']]);
            }
            header('Location: dashboard.php');
            exit;
        } else {
            $_SESSION['login_fallos'] = (int)($_SESSION['login_fallos'] ?? 0) + 1;
            if ($_SESSION['login_fallos'] >= $MAX_INTENTOS) {
                $_SESSION['login_bloqueo'] = time() + $BLOQUEO_SEG;
                $_SESSION['login_fallos'] = 0;
            }
            $error = 'Usuario o contraseña incorrectos.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Iniciar sesión | CoreFix Pro · Auto Manufacturas Brake</title>
  <link rel="icon" href="assets/logo/logo-brake-nuevo.png">
  <link rel="stylesheet" href="assets/css/mtto.css?v=<?= filemtime(__DIR__ . '/assets/css/mtto.css') ?>">
</head>
<body>
<header class="pub-barra">
  <div class="pub-barra-in">
    <a class="marca" href="index.php">
      <img src="assets/logo/logo-brake-nuevo.png" alt="">
      <span><strong>Auto Manufacturas Brake</strong><small>CoreFix Pro</small></span>
    </a>
    <a class="btn" href="index.php">Reportar una falla</a>
  </div>
</header>
<div class="franja" aria-hidden="true"></div>

<main class="login-wrap">
  <div class="tarjeta-card">
    <form method="post" autocomplete="on" class="tarjeta-cuerpo">
      <h2>Panel de mantenimiento</h2>
      <p class="muted" style="margin:0">Acceso para administradores y técnicos.</p>
      <?php if ($error !== ''): ?>
        <div class="mensaje mensaje-error" role="alert"><?= e($error) ?></div>
      <?php endif; ?>
      <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
      <label class="campo">
        <span>Usuario</span>
        <input type="text" name="usuario" value="<?= e($usuarioIngresado) ?>" required autofocus autocomplete="username" maxlength="50">
      </label>
      <label class="campo">
        <span>Contraseña</span>
        <input type="password" name="password" required autocomplete="current-password" maxlength="200">
      </label>
      <button type="submit" class="btn btn-primario btn-grande">Entrar</button>
    </form>
  </div>
</main>
</body>
</html>
