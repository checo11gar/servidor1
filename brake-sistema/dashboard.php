<?php
/**
 * dashboard.php — Panel de mantenimiento (administradores y técnicos).
 * Diseño tipo «Admindek»: menú lateral oscuro, barra superior con buscador (Ctrl+K), modo claro/oscuro,
 * idioma, accesos rápidos, notificaciones y menú de usuario; tarjetas de color con mini-gráficas.
 */
declare(strict_types=1);
require_once __DIR__ . '/includes/mtto.php';

$yo = require_panel();
$admin = $yo['rol'] === 'administrador';
$v = fn(string $f) => filemtime(__DIR__ . '/' . $f);
$iniciales = implode('', array_map(fn($p) => mb_substr($p, 0, 1), array_slice(preg_split('/\s+/', trim($yo['nombre'])), 0, 2)));

$I = [
  'menu'      => '<path d="M4 6h16M4 12h16M4 18h16"/>',
  'buscar'    => '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  'sol'       => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  'luna'      => '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
  'idioma'    => '<path d="M4 5h8M8 3v2M6 5c0 4 2.5 7 6 8M10 5c-.5 3.5-3 7-6.5 8.5"/><path d="m12 21 4.5-10 4.5 10M13.5 18h6"/>',
  'apps'      => '<path d="m12 2.5 3 3-3 3-3-3zM18.5 9l3 3-3 3-3-3zM5.5 9l3 3-3 3-3-3zM12 15.5l3 3-3 3-3-3z"/>',
  'campana'   => '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.9 1.9 0 0 0 3.4 0"/>',
  'usuario'   => '<circle cx="12" cy="12" r="9.5"/><circle cx="12" cy="10" r="3"/><path d="M6.2 18.4a6.5 6.5 0 0 1 11.6 0"/>',
  'chev'      => '<path d="m9 6 6 6-6 6"/>',
  'resumen'   => '<path d="M3 11 12 4l9 7"/><path d="M5 10v10h5v-6h4v6h5V10"/>',
  'ordenes'   => '<path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z"/>',
  'calendario'=> '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
  'equipos'   => '<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>',
  'usuarios'  => '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6 6 0 0 1 3.5 6"/>',
  'reportar'  => '<path d="M12 3 2 20h20L12 3zM12 10v4M12 17h.01"/>',
  'imprimir'  => '<path d="M6 9V3h12v6"/><rect x="3" y="9" width="18" height="8" rx="1.5"/><path d="M6 14h12v7H6z"/>',
  'descargar' => '<path d="M12 3v12M7 10l5 5 5-5M4 21h16"/>',
  'salir'     => '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h11"/>',
  'llave'     => '<circle cx="8" cy="15" r="4"/><path d="m11 12 9-9M17 6l3 3M14 9l2 2"/>',
  'paleta'    => '<path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.6-.8 1.6-1.6 0-.9-.6-1.3-.6-2.2 0-1 .8-1.7 1.8-1.7H17a4 4 0 0 0 4-4C21 6.6 17 3 12 3z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="15" cy="7" r="1"/>',
  'mensaje'   => '<path d="M4 5h16v11H9l-5 4z"/><path d="M8 10h.01M12 10h.01M16 10h.01"/>',
  'cerrar'    => '<path d="M6 6l12 12M18 6 6 18"/>',
];
$ico = fn(string $k, string $cls = 'ico') => '<svg class="' . $cls . '" viewBox="0 0 24 24" aria-hidden="true">' . $I[$k] . '</svg>';
?>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Panel | CoreFix Pro  · Auto Manufacturas Brake</title>
  <link rel="icon" href="assets/logo/logo-brake-nuevo.png">
  <script>
    // Aplica tema y preferencias antes de pintar (evita parpadeo)
    (function () { try {
      var p = JSON.parse(localStorage.getItem('brake_panel_pref') || '{}'), h = document.documentElement;
      h.dataset.tema = p.tema || 'claro'; h.dataset.lateral = p.lateral || 'marino';
      h.dataset.ancho = p.ancho || 'completo'; if (p.compacto) h.classList.add('sb-mini');
    } catch (e) {} })();
  </script>
  <link rel="stylesheet" href="assets/css/mtto.css?v=<?= $v('assets/css/mtto.css') ?>">
  <link rel="stylesheet" href="assets/css/panel.css?v=<?= $v('assets/css/panel.css') ?>">
</head>
<body class="panel-body">
<div class="app">

  <!-- ===================== MENÚ LATERAL ===================== -->
  <aside class="sb" id="side">
    <a class="sb-marca" href="dashboard.php#resumen">
      <span class="sb-logo"><img src="assets/logo/logo-brake-nuevo.png" alt=""></span>
      <span class="sb-nombre">Brake CoreFix Pro</span>
    </a>
    <div class="franja" aria-hidden="true"></div>
    <nav class="sb-nav" aria-label="Secciones">
      <div class="sb-grupo" data-i18n="navegacion">Navegación</div>
      <a href="#resumen" data-vista="resumen"><?= $ico('resumen') ?><span class="sb-txt" data-i18n="resumen">Resumen</span><span class="sb-badge" id="b-nuevas" hidden></span><?= $ico('chev', 'ico chev') ?></a>
      <a href="#ordenes" data-vista="ordenes"><?= $ico('ordenes') ?><span class="sb-txt" data-i18n="nav_ordenes">Correctivas</span><span class="sb-badge" id="b-abiertas" hidden></span><?= $ico('chev', 'ico chev') ?></a>
      <a href="#calendario" data-vista="calendario"><?= $ico('calendario') ?><span class="sb-txt" data-i18n="nav_calendario">Preventivos</span><span class="sb-badge rojo" id="b-vencidos" hidden></span><?= $ico('chev', 'ico chev') ?></a>

      <div class="sb-grupo" data-i18n="administracion">Panel de administración</div>
      <a href="#equipos" data-vista="equipos"><?= $ico('equipos') ?><span class="sb-txt" data-i18n="equipos">Equipos</span><span class="sb-badge gris" id="b-equipos" hidden></span><?= $ico('chev', 'ico chev') ?></a>
      <a href="#usuarios" data-vista="usuarios"><?= $ico('usuarios') ?><span class="sb-txt" data-i18n="usuarios">Usuarios</span><?php if ($admin): ?><span class="sb-pill">Admin</span><?php endif; ?><?= $ico('chev', 'ico chev') ?></a>

      <div class="sb-grupo" data-i18n="reportar_g">Reportar</div>
      <a href="index.php" target="_blank" rel="noopener"><?= $ico('reportar') ?><span class="sb-txt" data-i18n="levantar">Levantar una orden</span><?= $ico('chev', 'ico chev') ?></a>
      <a href="imprimir.php?blanco=1" target="_blank" rel="noopener"><?= $ico('imprimir') ?><span class="sb-txt" data-i18n="formato_blanco">Formato en blanco</span><?= $ico('chev', 'ico chev') ?></a>
    </nav>
    <div class="sb-pie">
      <span class="avatar"><?= e($iniciales) ?></span>
      <span class="sb-txt"><strong><?= e($yo['nombre']) ?></strong><small><?= $admin ? 'Administrador' : 'Técnico' ?> · <?= e($yo['usuario']) ?></small></span>
    </div>
  </aside>
  <div class="sb-velo" id="sb-velo"></div>

  <div class="col-main">
    <!-- ===================== BARRA SUPERIOR ===================== -->
    <header class="topbar">
      <button class="tb-btn" type="button" id="btn-menu" aria-label="Mostrar u ocultar menú" title="Menú"><?= $ico('menu') ?></button>
      <button class="tb-buscar" type="button" id="btn-buscar" aria-label="Buscar (Ctrl + K)">
        <?= $ico('buscar') ?><span class="tb-buscar-txt" data-i18n="buscar_ph">Buscar folio, equipo, persona…</span><kbd id="kbd-k">Ctrl K</kbd>
      </button>
      <div class="tb-der">
        <button class="tb-btn" type="button" id="btn-tema" aria-label="Modo claro / oscuro" title="Modo claro / oscuro"><?= $ico('sol', 'ico i-sol') ?><?= $ico('luna', 'ico i-luna') ?></button>

        <div class="tb-drop">
          <button class="tb-btn" type="button" data-drop="dd-idioma" aria-label="Idioma" title="Idioma"><?= $ico('idioma') ?></button>
          <div class="dd" id="dd-idioma" hidden>
            <button type="button" data-lang="es"><span class="bandera">ES</span> Español</button>
            <button type="button" data-lang="en"><span class="bandera">EN</span> English</button>
          </div>
        </div>

        <div class="tb-drop">
          <button class="tb-btn" type="button" data-drop="dd-apps" aria-label="Accesos rápidos" title="Accesos rápidos"><?= $ico('apps') ?></button>
          <div class="dd dd-apps" id="dd-apps" hidden>
            <div class="dd-tit" data-i18n="accesos">Accesos rápidos</div>
            <div class="apps-grid">
              <a href="index.php" target="_blank" rel="noopener"><span class="app-ic a-rojo"><?= $ico('reportar') ?></span><span data-i18n="reportar_falla">Reportar falla</span></a>
              <a href="imprimir.php?blanco=1" target="_blank" rel="noopener"><span class="app-ic a-azul"><?= $ico('imprimir') ?></span><span data-i18n="formato_blanco">Formato en blanco</span></a>
              <a href="#calendario"><span class="app-ic a-amarillo"><?= $ico('calendario') ?></span><span data-i18n="calendario">Calendario</span></a>
              <a href="#equipos"><span class="app-ic a-marino"><?= $ico('equipos') ?></span><span data-i18n="equipos">Equipos</span></a>
              <a href="#usuarios"><span class="app-ic a-azul"><?= $ico('usuarios') ?></span><span data-i18n="usuarios">Usuarios</span></a>
              <button type="button" id="app-exportar"><span class="app-ic a-marino"><?= $ico('descargar') ?></span><span data-i18n="exportar">Exportar órdenes</span></button>
            </div>
          </div>
        </div>

        <div class="tb-drop">
          <button class="tb-btn" type="button" data-drop="dd-notif" aria-label="Notificaciones" title="Notificaciones"><?= $ico('campana') ?><span class="tb-badge" id="notif-n" hidden></span></button>
          <div class="dd dd-notif" id="dd-notif" hidden>
            <div class="dd-tit"><span data-i18n="notificaciones">Notificaciones</span><a href="#ordenes" data-i18n="ver_todas">Ver órdenes</a></div>
            <div id="notif-lista" class="notif-lista"><p class="muted" style="padding:1rem">…</p></div>
          </div>
        </div>

        <div class="tb-drop">
          <button class="tb-btn tb-user" type="button" data-drop="dd-user" aria-label="Mi cuenta" title="Mi cuenta"><?= $ico('usuario') ?></button>
          <div class="dd dd-user" id="dd-user" hidden>
            <div class="dd-perfil"><span class="avatar grande"><?= e($iniciales) ?></span><div><strong><?= e($yo['nombre']) ?></strong><small><?= $admin ? 'Administrador' : 'Técnico' ?> · <?= e($yo['usuario']) ?></small></div></div>
            <button type="button" id="btn-mi-pass"><?= $ico('llave') ?><span data-i18n="cambiar_pass">Cambiar contraseña</span></button>
            <a href="index.php" target="_blank" rel="noopener"><?= $ico('reportar') ?><span data-i18n="reportar_falla">Reportar falla</span></a>
            <a href="logout.php" class="peligro"><?= $ico('salir') ?><span data-i18n="cerrar_sesion">Cerrar sesión</span></a>
          </div>
        </div>
      </div>
    </header>

    <main class="contenido">

      <!-- ================= RESUMEN ================= -->
      <section class="vista" data-vista="resumen" hidden>
        <div class="page-head">
          <h1 data-i18n="resumen">Resumen</h1>
          <ol class="migas"><li><a href="index.php" data-i18n="inicio">Inicio</a></li><li><a href="#resumen" data-i18n="panel">Panel</a></li><li data-i18n="resumen">Resumen</li></ol>
        </div>

        <div class="kpis-c">
          <div class="kc kc-azul">
            <div class="kc-txt"><span data-i18n="k_abiertas">Órdenes abiertas</span><b id="k-abiertas">–</b><small id="k-abiertas-t"></small></div>
            <div class="kc-graf" id="s-abiertas"></div>
          </div>
          <div class="kc kc-rojo">
            <div class="kc-txt"><span data-i18n="k_urgentes">Críticas y altas</span><b id="k-urgentes">–</b><small id="k-urgentes-t"></small></div>
            <div class="kc-graf" id="s-urgentes"></div>
          </div>
          <div class="kc kc-amarillo">
            <div class="kc-txt"><span data-i18n="k_cerradas">Finalizadas (30 días)</span><b id="k-cerradas">–</b><small id="k-cerradas-t"></small></div>
            <div class="kc-graf" id="s-cerradas"></div>
          </div>
          <div class="kc kc-marino">
            <div class="kc-txt"><span data-i18n="k_cierre">Tiempo medio de cierre</span><b id="k-cierre">–</b><small id="k-cierre-t"></small></div>
            <div class="kc-graf" id="s-cierre"></div>
          </div>
        </div>

        <div class="estado-tira" id="estado-tira"></div>

        <div class="rejilla-12">
          <div class="card c-8">
            <div class="card-cab">
              <h3 data-i18n="g_tiempo">Órdenes en el tiempo</h3>
              <div class="seg" role="group" aria-label="Periodo">
                <button type="button" data-rango="7">7D</button><button type="button" data-rango="30" class="activo">30D</button><button type="button" data-rango="90">90D</button>
              </div>
            </div>
            <div class="card-cuerpo">
              <div class="g-totales" id="g-totales"></div>
              <div class="g-area" id="g-area"></div>
              <div class="leyenda"><span class="l-azul" data-i18n="creadas">Creadas</span><span class="l-amarillo" data-i18n="finalizadas">Finalizadas</span></div>
            </div>
          </div>
          <div class="card c-4">
            <div class="card-cab"><h3 data-i18n="g_tipo">Fallas por tipo (90 días)</h3></div>
            <div class="card-cuerpo">
              <div class="dona-env"><div id="g-dona"></div><div class="dona-ley" id="g-dona-ley"></div></div>
              <h4 class="sub-tit" data-i18n="por_tipo_equipo">Por tipo de equipo</h4>
              <div class="barras" id="g-tipo-equipo"></div>
            </div>
          </div>

          <div class="card c-8">
            <div class="card-cab"><h3 data-i18n="recientes">Órdenes recientes</h3><a class="btn btn-sm" href="#ordenes" data-i18n="ver_todas">Ver todas</a></div>
            <div class="tabla-env sin-borde">
              <table class="tabla">
                <thead><tr><th data-i18n="folio">Folio</th><th data-i18n="equipo">Equipo</th><th data-i18n="reporto">Reportó</th><th data-i18n="prioridad">Prioridad</th><th data-i18n="estado">Estado</th><th data-i18n="tiempo_muerto">Tiempo muerto</th></tr></thead>
                <tbody id="g-recientes"></tbody>
              </table>
            </div>
          </div>
          <div class="card c-4">
            <div class="card-cab"><h3 data-i18n="abiertas_prioridad">Abiertas por prioridad</h3></div>
            <div class="card-cuerpo"><div class="barras" id="g-prioridad"></div></div>
          </div>

          <div class="card c-6">
            <div class="card-cab"><h3 data-i18n="top_equipos">Equipos con más fallas (90 días)</h3></div>
            <div class="card-cuerpo"><div class="barras" id="g-equipos"></div></div>
          </div>
          <div class="card c-6">
            <div class="card-cab"><h3 data-i18n="proximos">Próximos mantenimientos preventivos</h3><a class="btn btn-sm" href="#calendario" data-i18n="calendario">Calendario</a></div>
            <div class="card-cuerpo"><ul class="proximos" id="g-proximos"></ul></div>
          </div>

          <div class="card c-12">
            <div class="card-cab"><h3 data-i18n="inventario">Inventario de equipos por área</h3><a class="btn btn-sm" href="#equipos" data-i18n="equipos">Equipos</a></div>
            <div class="card-cuerpo inv">
              <div class="inv-nums" id="g-inv"></div>
              <div class="barras" id="g-area-eq"></div>
            </div>
          </div>
        </div>
      </section>

      <!-- ================= ÓRDENES ================= -->
      <section class="vista" data-vista="ordenes" hidden>
        <div class="page-head">
          <div><h1 data-i18n="ordenes">Órdenes correctivas</h1>
          <ol class="migas"><li><a href="#resumen" data-i18n="panel">Panel</a></li><li data-i18n="ordenes">Órdenes correctivas</li></ol></div>
          <div class="acciones"><button class="btn" type="button" id="o-exportar"><?= $ico('descargar') ?><span data-i18n="exportar_csv">Exportar CSV</span></button>
          <a class="btn btn-primario" href="index.php" target="_blank" rel="noopener" data-i18n="reportar_falla">Reportar falla</a></div>
        </div>
        <div class="card">
          <div class="card-cuerpo">
            <div class="filtros">
              <label class="campo crece"><span data-i18n="buscar">Buscar</span><input type="search" id="o-q" placeholder="Folio, persona, tarjeta, equipo, área…"></label>
              <label class="campo"><span data-i18n="estado">Estado</span><select id="o-estado">
                <option value="abiertas">Abiertas</option><option value="">Todas</option>
                <?php foreach (ESTADOS as $k => $t): ?><option value="<?= $k ?>"><?= $t ?></option><?php endforeach; ?>
              </select></label>
              <label class="campo"><span data-i18n="tipo">Tipo</span><select id="o-tipo"><option value="">Todos</option><option value="hardware">Hardware</option><option value="software">Software</option></select></label>
              <label class="campo"><span data-i18n="prioridad">Prioridad</span><select id="o-prioridad"><option value="">Todas</option>
                <?php foreach (PRIORIDADES as $k => $t): ?><option value="<?= $k ?>"><?= $t ?></option><?php endforeach; ?>
              </select></label>
              <label class="campo"><span data-i18n="desde">Desde</span><input type="date" id="o-desde"></label>
              <label class="campo"><span data-i18n="hasta">Hasta</span><input type="date" id="o-hasta"></label>
            </div>
          </div>
          <div class="tabla-env sin-borde">
            <table class="tabla">
              <thead><tr><th data-i18n="folio">Folio</th><th data-i18n="estado">Estado</th><th data-i18n="prioridad">Prioridad</th><th data-i18n="tipo">Tipo</th><th data-i18n="equipo">Equipo</th><th data-i18n="reporto">Reportó</th><th data-i18n="falla">Falla</th><th data-i18n="paro">Paro</th><th data-i18n="tiempo_muerto">Tiempo muerto</th></tr></thead>
              <tbody id="o-filas"></tbody>
            </table>
            <div class="vacio" id="o-vacio" hidden>No hay órdenes con estos filtros.</div>
          </div>
        </div>
      </section>

      <!-- ================= CALENDARIO ================= -->
      <section class="vista" data-vista="calendario" hidden>
        <div class="page-head">
          <div><h1 data-i18n="calendario">Calendario preventivo</h1>
          <ol class="migas"><li><a href="#resumen" data-i18n="panel">Panel</a></li><li data-i18n="calendario">Calendario preventivo</li></ol></div>
          <div class="acciones"><button class="btn btn-primario" type="button" id="c-nuevo" data-i18n="programar">Programar preventivo</button></div>
        </div>
        <div class="card">
          <div class="card-cab">
            <div class="cal-cab">
              <button class="btn btn-sm" type="button" id="c-ant" aria-label="Mes anterior">‹</button>
              <h2 id="c-mes"></h2>
              <button class="btn btn-sm" type="button" id="c-sig" aria-label="Mes siguiente">›</button>
              <button class="btn btn-sm" type="button" id="c-hoy" data-i18n="hoy">Hoy</button>
            </div>
            <div class="leyenda cal-ley"><span class="l-azul" data-i18n="programado">Programado</span><span class="l-rojo" data-i18n="vencido">Vencido</span><span class="l-gris" data-i18n="realizado">Realizado</span></div>
          </div>
          <div class="card-cuerpo"><div class="cal" id="c-grid"></div></div>
        </div>
      </section>

      <!-- ================= EQUIPOS ================= -->
      <section class="vista" data-vista="equipos" hidden>
        <div class="page-head">
          <div><h1 data-i18n="equipos">Equipos</h1>
          <ol class="migas"><li><a href="#resumen" data-i18n="panel">Panel</a></li><li data-i18n="administracion">Panel de administración</li><li data-i18n="equipos">Equipos</li></ol></div>
          <div class="acciones"><button class="btn btn-primario" type="button" id="e-nuevo" data-i18n="agregar_equipo">Agregar equipo</button></div>
        </div>
        <div class="card">
          <div class="card-cuerpo">
            <div class="filtros">
              <label class="campo crece"><span data-i18n="buscar">Buscar</span><input type="search" id="e-q" placeholder="Identificador, nombre, IP, responsable, serie…"></label>
              <label class="campo"><span data-i18n="area">Área</span><select id="e-area"><option value="">Todas</option></select></label>
              <label class="campo"><span data-i18n="tipo">Tipo</span><select id="e-tipo"><option value="">Todos</option></select></label>
            </div>
          </div>
          <div class="tabla-env sin-borde">
            <table class="tabla">
              <thead><tr><th data-i18n="identificador">Identificador</th><th data-i18n="equipo">Equipo</th><th data-i18n="area">Área</th><th data-i18n="responsable">Responsable</th><th>IP / Red</th><th data-i18n="fallas">Fallas</th><th data-i18n="mtto">Mantenimiento</th><th></th></tr></thead>
              <tbody id="e-filas"></tbody>
            </table>
            <div class="vacio" id="e-vacio" hidden>No hay equipos con estos filtros.</div>
          </div>
        </div>
      </section>

      <!-- ================= USUARIOS ================= -->
      <section class="vista" data-vista="usuarios" hidden>
        <div class="page-head">
          <div><h1 data-i18n="usuarios">Usuarios</h1>
          <ol class="migas"><li><a href="#resumen" data-i18n="panel">Panel</a></li><li data-i18n="administracion">Panel de administración</li><li data-i18n="usuarios">Usuarios</li></ol></div>
          <?php if ($admin): ?>
          <div class="acciones">
            <label class="btn" for="u-excel" data-i18n="importar_excel">Importar Excel</label>
            <input type="file" id="u-excel" accept=".xlsx,.xls,.csv" hidden>
            <button class="btn btn-primario" type="button" id="u-nuevo" data-i18n="agregar_trabajador">Agregar trabajador</button>
          </div>
          <?php endif; ?>
        </div>
        <div class="rejilla-12" style="margin-bottom:1.25rem">
          <div class="card c-6"><div class="card-cab"><h3 data-i18n="u_equipos">Equipos que más fallan y su responsable (90 días)</h3></div><div class="card-cuerpo"><div class="barras" id="u-por-equipo"></div></div></div>
          <div class="card c-6"><div class="card-cab"><h3 data-i18n="u_personas">Quién reporta más (90 días)</h3></div><div class="card-cuerpo"><div class="barras" id="u-por-persona"></div></div></div>
        </div>
        <div class="card">
          <div class="card-cuerpo"><div class="filtros"><label class="campo crece"><span data-i18n="buscar">Buscar</span><input type="search" id="u-q" placeholder="Tarjeta, nombre, área…"></label></div></div>
          <div class="tabla-env sin-borde">
            <table class="tabla">
              <thead><tr><th data-i18n="tarjeta">Tarjeta</th><th data-i18n="nombre">Nombre</th><th data-i18n="area">Área</th><th data-i18n="puesto">Puesto</th><th data-i18n="acceso">Acceso al panel</th><th data-i18n="equipos">Equipos</th><th data-i18n="reportes">Reportes</th><th data-i18n="estado">Estado</th><th></th></tr></thead>
              <tbody id="u-filas"></tbody>
            </table>
            <div class="vacio" id="u-vacio" hidden>Todavía no hay trabajadores. Agréguelos o importe el Excel de personal.</div>
          </div>
        </div>
        <div id="u-sin-tarjeta-env" hidden>
          <h3 style="margin:1.6rem 0 .4rem" data-i18n="sin_tarjeta">Cuentas del panel sin tarjeta</h3>
          <p class="muted">Para que estas personas también puedan levantar órdenes, vincule su cuenta a su número de tarjeta.</p>
          <div class="card"><div class="tabla-env sin-borde"><table class="tabla">
            <thead><tr><th>Usuario</th><th>Nombre</th><th>Rol</th><th>Estado</th><th></th></tr></thead>
            <tbody id="u-cuentas"></tbody>
          </table></div></div>
        </div>
      </section>
    </main>
  </div>
</div>

<!-- Botón lateral de personalización (como el de la plantilla) -->
<button class="fab-paleta" type="button" id="btn-paleta" aria-label="Personalizar panel" title="Personalizar"><?= $ico('paleta') ?></button>
<aside class="custom" id="custom" hidden>
  <div class="custom-cab"><h3 data-i18n="personalizar">Personalizar</h3><button class="tb-btn" type="button" id="custom-cerrar" aria-label="Cerrar"><?= $ico('cerrar') ?></button></div>
  <div class="custom-cuerpo">
    <h4 data-i18n="modo">Modo</h4>
    <div class="opc-2" data-pref="tema"><button type="button" data-val="claro" data-i18n="claro">Claro</button><button type="button" data-val="oscuro" data-i18n="oscuro">Oscuro</button></div>
    <h4 data-i18n="menu_lateral">Menú lateral</h4>
    <div class="opc-3" data-pref="lateral">
      <button type="button" data-val="marino"><i class="mues m-marino"></i><span data-i18n="marino">Marino</span></button>
      <button type="button" data-val="azul"><i class="mues m-azul"></i><span data-i18n="azul">Azul</span></button>
      <button type="button" data-val="claro"><i class="mues m-claro"></i><span data-i18n="claro">Claro</span></button>
    </div>
    <h4 data-i18n="ancho">Ancho del contenido</h4>
    <div class="opc-2" data-pref="ancho"><button type="button" data-val="completo" data-i18n="completo">Completo</button><button type="button" data-val="encuadrado" data-i18n="encuadrado">Encuadrado</button></div>
    <h4 data-i18n="menu_compacto">Menú compacto</h4>
    <div class="opc-2" data-pref="compacto"><button type="button" data-val="0" data-i18n="no">No</button><button type="button" data-val="1" data-i18n="si">Sí</button></div>
    <button class="btn" type="button" id="custom-reset" style="width:100%;margin-top:1.4rem" data-i18n="restablecer">Restablecer</button>
  </div>
</aside>

<!-- Botón flotante (en la plantilla es «Feedback»): reportar una falla -->
<a class="fab-reportar" href="index.php" target="_blank" rel="noopener"><?= $ico('mensaje') ?><span data-i18n="reportar_falla">Reportar falla</span></a>

<!-- Buscador rápido (Ctrl + K) -->
<dialog class="cmd" id="dlg-buscar">
  <div class="cmd-in"><?= $ico('buscar') ?><input id="cmd-q" type="search" autocomplete="off" placeholder="Buscar folio, equipo, IP, persona o tarjeta…"><kbd>Esc</kbd></div>
  <div class="cmd-res" id="cmd-res"></div>
</dialog>

<!-- ================= Ventanas ================= -->
<dialog class="ventana" id="dlg-orden">
  <div class="ventana-cab"><h2 id="do-titulo">Orden</h2><button class="cerrar-x" type="button" data-cerrar aria-label="Cerrar">×</button></div>
  <div class="ventana-cuerpo">
    <div class="estados-linea" id="do-estados"></div>
    <div id="do-msg"></div>
    <div id="do-formato"></div>
    <ul class="historial" id="do-historial"></ul>
  </div>
  <div class="ventana-pie">
    <?php if ($admin): ?><button class="btn btn-rojo" type="button" id="do-eliminar">Eliminar</button><?php endif; ?>
    <div class="der">
      <a class="btn btn-amarillo" id="do-imprimir" target="_blank" rel="noopener">Imprimir / PDF</a>
      <button class="btn" type="button" data-cerrar>Cerrar</button>
      <button class="btn btn-primario" type="button" id="do-guardar">Guardar cambios</button>
    </div>
  </div>
</dialog>

<dialog class="ventana" id="dlg-equipo">
  <form method="dialog" id="fe">
    <div class="ventana-cab"><h2 id="de-titulo">Equipo</h2><button class="cerrar-x" type="button" data-cerrar aria-label="Cerrar">×</button></div>
    <div class="ventana-cuerpo">
      <div id="de-msg"></div>
      <h4 class="sub-tit">Datos generales</h4>
      <div class="rejilla">
        <label class="campo"><span>Identificador *</span><input name="identificador" maxlength="40" required placeholder="PC-001"></label>
        <label class="campo"><span>Nombre *</span><input name="nombre" maxlength="120" required placeholder="Escritorio Dell Vostro"></label>
        <label class="campo"><span>Tipo de equipo</span><input name="tipo" maxlength="60" list="tipos-equipo" placeholder="Escritorio Dell"></label>
        <label class="campo"><span>Área / depto.</span><input name="area" maxlength="80" list="areas-equipo"></label>
        <label class="campo"><span>Marca</span><input name="marca" maxlength="60"></label>
        <label class="campo"><span>Modelo</span><input name="modelo" maxlength="60"></label>
        <label class="campo"><span>Número de serie (o MAC)</span><input name="serie" maxlength="80"></label>
        <label class="campo"><span>Estatus</span><input name="estatus" maxlength="30" list="estatus-equipo" placeholder="Activo"></label>
      </div>
      <h4 class="sub-tit">Responsable</h4>
      <div class="rejilla">
        <label class="campo"><span>Tarjeta del responsable</span><input name="tarjeta" maxlength="20" inputmode="numeric" placeholder="Opcional"><small class="muted" id="de-resp"></small></label>
        <label class="campo"><span>Responsable (como aparece en la lista)</span><input name="responsable" maxlength="120" placeholder="Se llena con la tarjeta si se deja vacío"></label>
      </div>
      <h4 class="sub-tit">Red y hardware</h4>
      <div class="rejilla">
        <label class="campo"><span>Nombre en la red</span><input name="nombre_red" maxlength="80" placeholder="DESKTOP-XXXX"></label>
        <label class="campo"><span>IP</span><input name="ip" maxlength="60" placeholder="10.10.10.0"></label>
        <label class="campo"><span>Monitor asignado</span><input name="monitor" maxlength="255"></label>
        <label class="campo"><span>Nivel de exposición</span><select name="nivel_exposicion"><option value=""></option><option>Bajo</option><option>Medio</option><option>Alto</option></select></label>
      </div>
      <div class="rejilla" style="margin-top:1rem">
        <label class="campo"><span>Hardware base</span><textarea name="hardware" maxlength="2000" placeholder="Procesador, RAM, almacenamiento, tarjeta gráfica…"></textarea></label>
        <label class="campo"><span>Periféricos básicos</span><textarea name="perifericos" maxlength="2000" placeholder="Teclado, mouse, no-break…"></textarea></label>
      </div>
      <h4 class="sub-tit">Mantenimiento</h4>
      <div class="rejilla">
        <label class="campo"><span>Frecuencia</span><select name="frecuencia_mtto"><option value=""></option><option>Semanal</option><option>Mensual</option><option>Bimestral</option><option>Trimestral</option><option>Semestral</option><option>Anual</option></select></label>
        <label class="campo"><span>Último mantenimiento</span><input type="date" name="ultimo_mtto"></label>
        <label class="campo"><span>Próximo</span><input type="date" name="proximo_mtto"></label>
      </div>
      <label class="campo" style="margin-top:1rem"><span>Notas</span><textarea name="notas" maxlength="2000"></textarea></label>
      <label style="display:flex;gap:.5rem;align-items:center;margin-top:.8rem"><input type="checkbox" name="activo" style="width:auto" checked> Equipo activo</label>
    </div>
    <div class="ventana-pie"><span></span><div class="der"><button class="btn" type="button" data-cerrar>Cancelar</button><button class="btn btn-primario" type="submit" value="ok">Guardar equipo</button></div></div>
  </form>
  <datalist id="tipos-equipo"></datalist>
  <datalist id="areas-equipo"></datalist>
  <datalist id="estatus-equipo"><option>Activo</option><option>En reparación</option><option>Baja</option></datalist>
</dialog>

<dialog class="ventana angosta" id="dlg-prev">
  <form method="dialog" id="fp">
    <div class="ventana-cab"><h2 id="dp-titulo">Mantenimiento preventivo</h2><button class="cerrar-x" type="button" data-cerrar aria-label="Cerrar">×</button></div>
    <div class="ventana-cuerpo">
      <div id="dp-msg"></div>
      <div class="rejilla">
        <label class="campo" style="grid-column:1/-1"><span>¿Qué se va a hacer? *</span><input name="titulo" maxlength="150" required placeholder="Limpieza y revisión general"></label>
        <label class="campo"><span>Fecha *</span><input type="date" name="fecha" required></label>
        <label class="campo"><span>Se repite</span><select name="frecuencia">
          <?php foreach (FRECUENCIAS as $k => $t): ?><option value="<?= $k ?>"><?= $t ?></option><?php endforeach; ?>
        </select></label>
        <label class="campo"><span>Equipo</span><select name="equipo_id" id="dp-equipo"></select></label>
        <label class="campo"><span>Responsable</span><select name="responsable_id" id="dp-resp"></select></label>
      </div>
      <label class="campo" style="margin-top:1rem"><span>Notas</span><textarea name="notas" maxlength="2000"></textarea></label>
      <p class="muted" id="dp-estado" style="margin-top:.8rem"></p>
    </div>
    <div class="ventana-pie">
      <button class="btn btn-rojo" type="button" id="dp-eliminar">Eliminar</button>
      <div class="der">
        <button class="btn" type="button" id="dp-cancelar-ev">Cancelar mantenimiento</button>
        <button class="btn btn-amarillo" type="button" id="dp-realizado">Marcar realizado</button>
        <button class="btn btn-primario" type="submit" value="ok">Guardar</button>
      </div>
    </div>
  </form>
</dialog>

<dialog class="ventana angosta" id="dlg-trab">
  <form method="dialog" id="ft">
    <div class="ventana-cab"><h2 id="dt-titulo">Trabajador</h2><button class="cerrar-x" type="button" data-cerrar aria-label="Cerrar">×</button></div>
    <div class="ventana-cuerpo">
      <div id="dt-msg"></div>
      <div class="rejilla">
        <label class="campo"><span>No. de tarjeta *</span><input name="tarjeta" maxlength="20" required inputmode="numeric"></label>
        <label class="campo"><span>Nombre completo *</span><input name="nombre" maxlength="120" required></label>
        <label class="campo"><span>Área</span><input name="area" maxlength="80" list="areas-equipo"></label>
        <label class="campo"><span>Puesto</span><input name="puesto" maxlength="80"></label>
      </div>
      <label style="display:flex;gap:.5rem;align-items:center;margin-top:.8rem"><input type="checkbox" name="activo" style="width:auto" checked> Activo (puede reportar con su tarjeta)</label>
      <h3 style="margin:1.4rem 0 .6rem;font-size:1.05rem">Acceso al panel</h3>
      <div class="rejilla">
        <label class="campo"><span>Rol</span><select name="rol">
          <option value="">Sin acceso (solo reporta)</option><option value="tecnico">Técnico de mantenimiento</option><option value="administrador">Administrador</option>
        </select></label>
        <label class="campo"><span>Usuario</span><input name="usuario" maxlength="50" autocomplete="off"></label>
        <label class="campo"><span>Contraseña</span><input type="password" name="password" maxlength="200" autocomplete="new-password" placeholder="Mínimo 8 caracteres"><small class="muted" id="dt-pass-nota"></small></label>
      </div>
    </div>
    <div class="ventana-pie"><span></span><div class="der"><button class="btn" type="button" data-cerrar>Cancelar</button><button class="btn btn-primario" type="submit" value="ok">Guardar</button></div></div>
  </form>
</dialog>

<dialog class="ventana angosta" id="dlg-cuenta">
  <form method="dialog" id="fc">
    <div class="ventana-cab"><h2 id="dc-titulo">Cuenta</h2><button class="cerrar-x" type="button" data-cerrar aria-label="Cerrar">×</button></div>
    <div class="ventana-cuerpo">
      <div id="dc-msg"></div>
      <div class="rejilla">
        <label class="campo"><span>Rol</span><select name="rol"><option value="administrador">Administrador</option><option value="tecnico">Técnico</option><option value="usuario">Sin acceso al panel</option></select></label>
        <label class="campo"><span>Nueva contraseña</span><input type="password" name="password" maxlength="200" autocomplete="new-password" placeholder="Dejar vacío para no cambiar"></label>
        <label class="campo"><span>Vincular a tarjeta</span><input name="tarjeta" maxlength="20" inputmode="numeric" placeholder="Opcional"></label>
      </div>
      <label style="display:flex;gap:.5rem;align-items:center;margin-top:.8rem"><input type="checkbox" name="activo" style="width:auto"> Cuenta activa</label>
    </div>
    <div class="ventana-pie"><button class="btn btn-rojo" type="button" id="dc-eliminar">Eliminar cuenta</button><div class="der"><button class="btn" type="button" data-cerrar>Cancelar</button><button class="btn btn-primario" type="submit" value="ok">Guardar</button></div></div>
  </form>
</dialog>

<dialog class="ventana angosta" id="dlg-pass">
  <form method="dialog" id="fpass">
    <div class="ventana-cab"><h2>Cambiar mi contraseña</h2><button class="cerrar-x" type="button" data-cerrar aria-label="Cerrar">×</button></div>
    <div class="ventana-cuerpo">
      <div id="dpass-msg"></div>
      <div class="rejilla">
        <label class="campo"><span>Contraseña actual</span><input type="password" name="actual" required autocomplete="current-password" maxlength="200"></label>
        <label class="campo"><span>Nueva contraseña</span><input type="password" name="nueva" required autocomplete="new-password" minlength="8" maxlength="200" placeholder="Mínimo 8 caracteres"></label>
      </div>
    </div>
    <div class="ventana-pie"><span></span><div class="der"><button class="btn" type="button" data-cerrar>Cancelar</button><button class="btn btn-primario" type="submit" value="ok">Guardar</button></div></div>
  </form>
</dialog>

<div class="toast" id="toast" role="status" aria-live="polite"></div>
<script>window.MTTO = { csrf: <?= json_encode(csrf_token()) ?>, panel: true, admin: <?= $admin ? 'true' : 'false' ?>, yo: <?= (int)$yo['id'] ?> };</script>
<script src="assets/js/mtto-comun.js?v=<?= $v('assets/js/mtto-comun.js') ?>"></script>
<?php if ($admin): ?><script src="assets/vendor/xlsx.full.min.js"></script><?php endif; ?>
<script src="assets/js/panel.js?v=<?= $v('assets/js/panel.js') ?>"></script>
</body>
</html>
