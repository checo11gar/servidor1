<?php
/**
 * index.php — Página de entrada: el formato de Orden de Mantenimiento Correctivo
 * aparece directamente. En «Responsable» se escribe el número de tarjeta y el sistema
 * busca a la persona en la base de datos. «Iniciar sesión» es solo para administradores
 * y técnicos (panel de reportes).
 */
declare(strict_types=1);
require_once __DIR__ . '/includes/mtto.php';

$u = usuario_actual();
$enPanel = $u !== null && es_personal_mtto($u);
$v = fn(string $f) => filemtime(__DIR__ . '/' . $f);
?>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Reportar falla | Mantenimiento · Auto Manufacturas Brake</title>
  <link rel="icon" href="assets/logo/logo-brake-nuevo.png">
  <link rel="stylesheet" href="assets/css/mtto.css?v=<?= $v('assets/css/mtto.css') ?>">
</head>
<body>
<header class="pub-barra">
  <div class="pub-barra-in">
    <a class="marca" href="index.php">
      <img src="assets/logo/logo-brake-nuevo.png" alt="">
      <span><strong>Auto Manufacturas Brake</strong><small>CoreFix Pro</small></span>
    </a>
    <?php if ($enPanel): ?>
      <a class="btn" href="dashboard.php">Ir al panel</a>
    <?php else: ?>
      <a class="btn" href="login.php">Iniciar sesión</a>
    <?php endif; ?>
  </div>
</header>
<div class="franja" aria-hidden="true"></div>

<main class="pub-main">

  <!-- Formato (visible al entrar) -->
  <section id="paso-formato">
    <div class="quien">
      <div>
        <h1>Reportar una falla</h1>
        <p class="muted">Escriba su número de tarjeta en <b>Responsable</b>, elija el equipo y describa la falla (hardware o software).</p>
      </div>
    </div>
    <div class="reporte-layout">
      <div>
        <div id="msg-formato"></div>
        <div id="formato"></div>
        <div class="fmt-acciones">
          <button class="btn" type="button" id="btn-cancelar">Limpiar</button>
          <button class="btn btn-primario btn-grande" type="button" id="btn-guardar">Guardar orden</button>
        </div>
      </div>
      <aside class="lateral">
        <div class="caja" id="caja-equipo">
          <h3>Información del equipo</h3>
          <div id="ficha-equipo"><p class="muted">Escriba su número de tarjeta para ver sus equipos.</p></div>
        </div>
        <div class="caja">
          <h3>Mis equipos</h3>
          <div id="mis-equipos"><p class="muted">—</p></div>
        </div>
        <div class="caja">
          <h3>Mis reportes recientes</h3>
          <ul class="mis-ordenes" id="mis-ordenes"><li class="muted">—</li></ul>
        </div>
      </aside>
    </div>
  </section>

  <!-- Orden guardada -->
  <section id="paso-listo" class="listo" hidden>
    <h1>Orden guardada</h1>
    <p class="muted">Mantenimiento ya la puede ver. Anote su folio para darle seguimiento:</p>
    <div class="folio-grande" id="folio-listo"></div>
    <div class="acciones">
      <a class="btn btn-amarillo" id="btn-imprimir" target="_blank" rel="noopener">Imprimir o guardar en PDF</a>
      <button class="btn" type="button" id="btn-otra">Reportar otra falla</button>
      <button class="btn" type="button" id="btn-terminar">Terminar</button>
    </div>
  </section>
</main>

<div class="toast" id="toast" role="status" aria-live="polite"></div>
<script>window.MTTO = { csrf: <?= json_encode(csrf_token()) ?>, panel: false };</script>
<script src="assets/js/mtto-comun.js?v=<?= $v('assets/js/mtto-comun.js') ?>"></script>
<script src="assets/js/publico.js?v=<?= $v('assets/js/publico.js') ?>"></script>
</body>
</html>
