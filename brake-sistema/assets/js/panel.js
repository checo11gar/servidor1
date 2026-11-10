/**
 * assets/js/panel.js — Panel de mantenimiento (diseño tipo Admindek).
 * Barra superior: menú, buscador (Ctrl+K), modo claro/oscuro, idioma, accesos rápidos,
 * notificaciones y cuenta. Resumen con tarjetas de color, gráficas 7D/30D/90D y dona.
 */
(function () {
  'use strict';
  const { $, $$, esc, toast, api, renderFormato, fechaCorta, hoy, ESTADOS, PRIORIDADES } = window.Mtto;
  const API = 'api/panel.php';
  const ADMIN = !!window.MTTO.admin;
  const html = document.documentElement;
  const llamar = (accion, datos) => api(API, Object.assign({ accion }, datos || {}));
  const pad = n => String(n).padStart(2, '0');
  const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  const MESES_L = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  const FREC = { unica: 'Única vez', semanal: 'Semanal', mensual: 'Mensual', bimestral: 'Bimestral', trimestral: 'Trimestral', semestral: 'Semestral', anual: 'Anual' };
  const chipE = (e, t) => '<span class="chip est-' + e + '">' + esc(t || ESTADOS[e]) + '</span>';
  const chipP = p => '<span class="chip pri-' + p + '">' + esc(PRIORIDADES[p]) + '</span>';
  const debounce = (fn, ms) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; };
  const msg = (sel, texto) => { $(sel).innerHTML = texto ? '<div class="mensaje mensaje-error" role="alert">' + esc(texto) + '</div>' : ''; };
  const fechaD = v => v ? String(v).slice(0, 10).split('-').reverse().join('/') : '';
  const color = v => getComputedStyle(html).getPropertyValue(v).trim();
  const guardarLS = (k, v) => { try { localStorage.setItem(k, v); } catch (_) { /* sin almacenamiento */ } };
  const leerLS = k => { try { return localStorage.getItem(k); } catch (_) { return null; } };

  /* =====================================================================
     IDIOMA (español / inglés) — textos fijos del panel
     ===================================================================== */
  const EN = {
    navegacion: 'Navigation', nav_ordenes: 'Corrective', nav_calendario: 'Preventive', resumen: 'Dashboard', ordenes: 'Corrective orders', calendario: 'Preventive calendar',
    administracion: 'Admin panel', equipos: 'Equipment', usuarios: 'Users', reportar_g: 'Report', levantar: 'Raise an order',
    formato_blanco: 'Blank form', buscar_ph: 'Search…', accesos: 'Quick access', reportar_falla: 'Report a failure',
    exportar: 'Export orders', notificaciones: 'Notifications', ver_todas: 'View all', cambiar_pass: 'Change password',
    cerrar_sesion: 'Log out', inicio: 'Home', panel: 'Panel', k_abiertas: 'Open orders', k_urgentes: 'Critical & high',
    k_cerradas: 'Closed (30 days)', k_cierre: 'Average closing time', g_tiempo: 'Orders over time', creadas: 'Created',
    finalizadas: 'Closed', g_tipo: 'Failures by type (90 days)', por_tipo_equipo: 'By equipment type', recientes: 'Recent orders',
    folio: 'Folio', equipo: 'Equipment', reporto: 'Reported by', prioridad: 'Priority', estado: 'Status', tiempo_muerto: 'Downtime',
    abiertas_prioridad: 'Open by priority', top_equipos: 'Equipment with most failures (90 days)', proximos: 'Upcoming preventive maintenance',
    inventario: 'Equipment inventory by area', exportar_csv: 'Export CSV', buscar: 'Search', tipo: 'Type', desde: 'From', hasta: 'To',
    falla: 'Failure', paro: 'Stop', programar: 'Schedule preventive', hoy: 'Today', programado: 'Scheduled', vencido: 'Overdue',
    realizado: 'Done', agregar_equipo: 'Add equipment', area: 'Area', identificador: 'ID', responsable: 'Owner', fallas: 'Failures',
    mtto: 'Maintenance', importar_excel: 'Import Excel', agregar_trabajador: 'Add worker', u_equipos: 'Equipment that fails most and its owner (90 days)',
    u_personas: 'Who reports most (90 days)', tarjeta: 'Card', nombre: 'Name', puesto: 'Position', acceso: 'Panel access', reportes: 'Reports',
    sin_tarjeta: 'Panel accounts without card', personalizar: 'Customize', modo: 'Mode', claro: 'Light', oscuro: 'Dark',
    menu_lateral: 'Sidebar', marino: 'Navy', azul: 'Blue', ancho: 'Content width', completo: 'Full', encuadrado: 'Boxed',
    menu_compacto: 'Compact menu', no: 'No', si: 'Yes', restablecer: 'Reset',
    // textos generados
    t_semana: 'vs. last week', t_mes: 'vs. previous 30 days', t_sin: 'no previous data', e_pend: 'New (not verified)',
    e_verif: 'Verified', e_proc: 'In progress', e_fin: 'Closed in 30 days', total: 'Total', sin_datos: 'No data yet.',
    nuevas: 'New, not verified', venc: 'Overdue preventive', semana: 'Due this week', nada: 'Nothing pending. All good!',
    inv_total: 'Active equipment', inv_tarjeta: 'Without card owner', inv_prev: 'Without preventive', inv_falla: 'With open order'
  };
  const ES_GEN = {
    t_semana: 'vs. semana anterior', t_mes: 'vs. 30 días anteriores', t_sin: 'sin datos previos', e_pend: 'Nuevas (sin verificar)',
    e_verif: 'Verificadas', e_proc: 'En proceso', e_fin: 'Finalizadas en 30 días', total: 'Total', sin_datos: 'Sin datos todavía.',
    nuevas: 'Nuevas sin verificar', venc: 'Preventivos vencidos', semana: 'Preventivos esta semana', nada: 'Nada pendiente. ¡Todo en orden!',
    inv_total: 'Equipos activos', inv_tarjeta: 'Sin responsable con tarjeta', inv_prev: 'Sin preventivo programado', inv_falla: 'Con orden abierta'
  };
  let idioma = leerLS('brake_idioma') || 'es';
  let datosGrafica = null, ultimoResumen = null;
  const t = k => (idioma === 'en' ? EN[k] : ES_GEN[k]) || ES_GEN[k] || k;
  function aplicarIdioma(l) {
    idioma = l; guardarLS('brake_idioma', l); html.lang = l;
    $$('[data-i18n]').forEach(el => {
      if (el.dataset.es === undefined) el.dataset.es = el.textContent;
      el.textContent = l === 'en' ? (EN[el.dataset.i18n] || el.dataset.es) : el.dataset.es;
    });
    $$('[data-lang]').forEach(b => b.classList.toggle('activo', b.dataset.lang === l));
    if (ultimoResumen) pintarResumen(ultimoResumen);
    if (datosGrafica) graficaArea(datosGrafica);
  }

  /* =====================================================================
     PREFERENCIAS (modo oscuro, color del menú, ancho, menú compacto)
     ===================================================================== */
  const PREF_DEF = { tema: 'claro', lateral: 'marino', ancho: 'completo', compacto: 0 };
  let pref = Object.assign({}, PREF_DEF, JSON.parse(leerLS('brake_panel_pref') || '{}'));
  function aplicarPref() {
    html.dataset.tema = pref.tema; html.dataset.lateral = pref.lateral; html.dataset.ancho = pref.ancho;
    html.classList.toggle('sb-mini', !!Number(pref.compacto));
    guardarLS('brake_panel_pref', JSON.stringify(pref));
    $$('[data-pref]').forEach(g => $$('button', g).forEach(b => b.classList.toggle('activo', String(pref[g.dataset.pref]) === b.dataset.val)));
    if (ultimoResumen) requestAnimationFrame(() => pintarResumen(ultimoResumen));
  }
  $('#btn-tema').addEventListener('click', () => { pref.tema = pref.tema === 'oscuro' ? 'claro' : 'oscuro'; aplicarPref(); });
  $('#btn-paleta').addEventListener('click', () => { $('#custom').hidden = !$('#custom').hidden; });
  $('#custom-cerrar').addEventListener('click', () => { $('#custom').hidden = true; });
  $('#custom').addEventListener('click', ev => {
    const b = ev.target.closest('[data-val]');
    if (!b) return;
    pref[b.closest('[data-pref]').dataset.pref] = b.dataset.val;
    aplicarPref();
  });
  $('#custom-reset').addEventListener('click', () => { pref = Object.assign({}, PREF_DEF); aplicarPref(); });

  /* Menú lateral: compacto en escritorio, deslizable en celular */
  const esMovil = () => window.matchMedia('(max-width: 992px)').matches;
  $('#btn-menu').addEventListener('click', () => {
    if (esMovil()) html.classList.toggle('sb-abierto');
    else { pref.compacto = Number(pref.compacto) ? 0 : 1; aplicarPref(); }
  });
  $('#sb-velo').addEventListener('click', () => html.classList.remove('sb-abierto'));

  /* Menús desplegables de la barra superior */
  function cerrarDrops(excepto) {
    $$('.dd').forEach(d => { if (d.id !== excepto) d.hidden = true; });
    $$('[data-drop]').forEach(b => b.setAttribute('aria-expanded', String(b.dataset.drop === excepto && !$('#' + excepto).hidden)));
  }
  document.addEventListener('click', ev => {
    const b = ev.target.closest('[data-drop]');
    if (b) {
      const dd = $('#' + b.dataset.drop);
      dd.hidden = !dd.hidden;
      cerrarDrops(b.dataset.drop);
      if (!dd.hidden && b.dataset.drop === 'dd-notif') cargarNotif();
      return;
    }
    if (!ev.target.closest('.dd')) cerrarDrops(null);
    else if (ev.target.closest('.dd a, .dd button')) setTimeout(() => cerrarDrops(null), 0);
    const c = ev.target.closest('[data-cerrar]');
    if (c) c.closest('dialog').close();
  });
  document.addEventListener('keydown', ev => {
    if (ev.key === 'Escape') { cerrarDrops(null); $('#custom').hidden = true; }
    if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === 'k') { ev.preventDefault(); abrirBuscador(); }
  });
  $$('[data-lang]').forEach(b => b.addEventListener('click', () => aplicarIdioma(b.dataset.lang)));
  if (/Mac|iPhone|iPad/.test(navigator.platform)) $('#kbd-k').textContent = '⌘K';

  /* ---------------- Ventanas (formularios) ---------------- */
  function formDatos(form) {
    const d = {};
    $$('input, select, textarea', form).forEach(el => {
      if (!el.name) return;
      d[el.name] = el.type === 'checkbox' ? el.checked : el.value;
    });
    return d;
  }
  function formLlenar(form, datos) {
    $$('input, select, textarea', form).forEach(el => {
      if (!el.name) return;
      const v = datos[el.name];
      if (el.type === 'checkbox') el.checked = v === undefined ? true : !!Number(v);
      else el.value = v == null ? '' : v;
    });
  }

  /* =====================================================================
     NAVEGACIÓN
     ===================================================================== */
  const cargadores = {};
  let vistaActual = '';
  function mostrar(nombre) {
    if (!$('.vista[data-vista="' + nombre + '"]')) nombre = 'resumen';
    vistaActual = nombre;
    $$('.vista').forEach(v => { v.hidden = v.dataset.vista !== nombre; });
    $$('.sb-nav a[data-vista]').forEach(a => a.classList.toggle('activo', a.dataset.vista === nombre));
    html.classList.remove('sb-abierto');
    window.scrollTo({ top: 0 });
    if (cargadores[nombre]) cargadores[nombre]();
  }
  window.addEventListener('hashchange', () => mostrar(location.hash.slice(1)));
  function ir(vista) { if (location.hash.slice(1) === vista) mostrar(vista); else location.hash = vista; }

  function badges(b) {
    const pon = (sel, n) => { const el = $(sel); el.textContent = n; el.hidden = !n; };
    pon('#b-nuevas', b.nuevas); pon('#b-abiertas', b.abiertas); pon('#b-vencidos', b.vencidos); pon('#b-equipos', b.equipos);
    $('#b-nuevas').title = 'Órdenes nuevas sin verificar'; $('#b-vencidos').title = 'Preventivos vencidos';
    const n = b.nuevas + b.vencidos;
    $('#notif-n').textContent = n > 99 ? '99+' : n; $('#notif-n').hidden = !n;
  }

  /* =====================================================================
     NOTIFICACIONES (campana)
     ===================================================================== */
  let ultimoId = null;
  async function cargarNotif(silencioso) {
    try {
      const r = await llamar('notificaciones');
      badges(r.badges);
      if (ultimoId !== null && r.ultimo_id > ultimoId) {
        const nueva = r.nuevas.find(o => Number(o.id) === r.ultimo_id);
        toast('Nueva orden ' + (nueva ? nueva.folio + ' · ' + nueva.equipo_ident : 'recibida'));
        if (vistaActual === 'resumen') cargadores.resumen();
        if (vistaActual === 'ordenes') cargarOrdenes();
      }
      ultimoId = r.ultimo_id;
      if (silencioso) return;
      const colP = { critica: 'var(--rojo)', alta: 'var(--amarillo)', media: 'var(--azul)', baja: 'var(--marino)' };
      let h = '';
      if (r.nuevas.length) h += '<div class="notif-sec">' + t('nuevas') + '</div>' + r.nuevas.map(o =>
        '<a class="notif" data-orden="' + o.id + '"><span class="n-ic" style="background:' + colP[o.prioridad] + '">' + esc(PRIORIDADES[o.prioridad].slice(0, 1)) + '</span>' +
        '<span><strong>' + esc(o.folio) + ' · ' + esc(o.equipo_ident || '') + '</strong><small>' + esc(o.reporta_nombre) + ' · ' + esc(fechaCorta(o.creado)) + '</small></span></a>').join('');
      if (r.vencidos.length) h += '<div class="notif-sec">' + t('venc') + '</div>' + r.vencidos.map(p =>
        '<a class="notif" href="#calendario"><span class="n-ic" style="background:var(--rojo)">!</span><span><strong>' + esc(p.titulo) + '</strong><small>' +
        esc([p.identificador, fechaD(p.fecha)].filter(Boolean).join(' · ')) + '</small></span></a>').join('');
      if (r.semana.length) h += '<div class="notif-sec">' + t('semana') + '</div>' + r.semana.map(p =>
        '<a class="notif" href="#calendario"><span class="n-ic" style="background:var(--azul)">' + Number(p.fecha.slice(8)) + '</span><span><strong>' + esc(p.titulo) + '</strong><small>' +
        esc([p.identificador, fechaD(p.fecha)].filter(Boolean).join(' · ')) + '</small></span></a>').join('');
      $('#notif-lista').innerHTML = h || '<p class="muted" style="padding:1rem">' + t('nada') + '</p>';
    } catch (e) { if (!silencioso) toast(e.message, 'error'); }
  }
  $('#notif-lista').addEventListener('click', ev => {
    const a = ev.target.closest('[data-orden]');
    if (a) { cerrarDrops(null); abrirOrden(Number(a.dataset.orden)); }
  });

  /* =====================================================================
     BUSCADOR RÁPIDO (Ctrl + K)
     ===================================================================== */
  const IR_A = [['resumen', 'Resumen'], ['ordenes', 'Órdenes correctivas'], ['calendario', 'Calendario preventivo'], ['equipos', 'Equipos'], ['usuarios', 'Usuarios']];
  let cmdSel = 0;
  function abrirBuscador() {
    const d = $('#dlg-buscar');
    if (!d.open) d.showModal();
    $('#cmd-q').value = ''; pintarCmd(null); $('#cmd-q').focus();
  }
  $('#btn-buscar').addEventListener('click', abrirBuscador);
  $('#dlg-buscar').addEventListener('click', ev => { if (ev.target === ev.currentTarget) ev.currentTarget.close(); });
  function pintarCmd(r) {
    let h = '';
    if (!r) {
      h = '<div class="cmd-sec">Ir a</div>' + IR_A.map(([v, n]) => '<a class="cmd-item" data-ir="' + v + '"><b>' + esc(n) + '</b></a>').join('') +
        '<div class="cmd-sec">Acciones</div><a class="cmd-item" href="index.php" target="_blank" rel="noopener"><b>Reportar una falla</b></a>' +
        '<a class="cmd-item" href="imprimir.php?blanco=1" target="_blank" rel="noopener"><b>Imprimir formato en blanco</b></a>';
    } else {
      if (r.ordenes.length) h += '<div class="cmd-sec">Órdenes</div>' + r.ordenes.map(o =>
        '<a class="cmd-item" data-orden="' + o.id + '"><span><b>' + esc(o.folio) + '</b> ' + chipE(o.estado, o.estado_texto) +
        '<small>' + esc((o.equipo_ident || '') + ' · ' + o.reporta_nombre + ' · ' + o.reporte) + '</small></span></a>').join('');
      if (r.equipos.length) h += '<div class="cmd-sec">Equipos</div>' + r.equipos.map(e =>
        '<a class="cmd-item" data-equipo="' + esc(e.identificador) + '"><span><b>' + esc(e.identificador) + '</b> ' + esc(e.nombre) +
        '<small>' + esc([e.area, e.responsable, e.ip].filter(Boolean).join(' · ')) + '</small></span></a>').join('');
      if (r.trabajadores.length) h += '<div class="cmd-sec">Trabajadores</div>' + r.trabajadores.map(w =>
        '<a class="cmd-item" data-trab="' + esc(w.tarjeta) + '"><span><b>' + esc(w.tarjeta) + '</b> ' + esc(w.nombre) + '<small>' + esc(w.area || '') + '</small></span></a>').join('');
      if (!h) h = '<div class="cmd-vacio">Sin resultados.</div>';
    }
    $('#cmd-res').innerHTML = h;
    cmdSel = 0; marcarCmd();
  }
  function marcarCmd() { $$('.cmd-item', $('#cmd-res')).forEach((el, i) => el.classList.toggle('sel', i === cmdSel)); }
  const buscarCmd = debounce(async q => {
    if (q.length < 2) return pintarCmd(null);
    try { pintarCmd(await llamar('buscar_global', { q })); } catch (e) { toast(e.message, 'error'); }
  }, 220);
  $('#cmd-q').addEventListener('input', ev => buscarCmd(ev.target.value.trim()));
  $('#cmd-q').addEventListener('keydown', ev => {
    if (ev.key === 'Escape') { ev.preventDefault(); $('#dlg-buscar').close(); return; }
    const items = $$('.cmd-item', $('#cmd-res'));
    if (ev.key === 'ArrowDown') { ev.preventDefault(); cmdSel = Math.min(items.length - 1, cmdSel + 1); marcarCmd(); }
    if (ev.key === 'ArrowUp') { ev.preventDefault(); cmdSel = Math.max(0, cmdSel - 1); marcarCmd(); }
    if (ev.key === 'Enter' && items[cmdSel]) { ev.preventDefault(); items[cmdSel].click(); }
  });
  $('#cmd-res').addEventListener('click', ev => {
    const a = ev.target.closest('.cmd-item');
    if (!a) return;
    if (a.getAttribute('href')) { $('#dlg-buscar').close(); return; }
    ev.preventDefault();
    $('#dlg-buscar').close();
    if (a.dataset.ir) ir(a.dataset.ir);
    else if (a.dataset.orden) abrirOrden(Number(a.dataset.orden));
    else if (a.dataset.equipo) { $('#e-q').value = a.dataset.equipo; ir('equipos'); }
    else if (a.dataset.trab) { $('#u-q').value = a.dataset.trab; ir('usuarios'); }
  });

  /* =====================================================================
     GRÁFICAS (SVG, sin librerías)
     ===================================================================== */
  /** Curva suave sin sobrepasar los datos (monótona). */
  function curva(pts) {
    if (pts.length < 2) return pts.length ? 'M' + pts[0][0] + ',' + pts[0][1] : '';
    const n = pts.length, dx = [], m = [], t2 = [];
    for (let i = 0; i < n - 1; i++) { dx[i] = pts[i + 1][0] - pts[i][0]; m[i] = (pts[i + 1][1] - pts[i][1]) / dx[i]; }
    t2[0] = m[0]; t2[n - 1] = m[n - 2];
    for (let i = 1; i < n - 1; i++) t2[i] = m[i - 1] * m[i] <= 0 ? 0 : (m[i - 1] + m[i]) / 2;
    for (let i = 0; i < n - 1; i++) {
      if (m[i] === 0) { t2[i] = t2[i + 1] = 0; continue; }
      const a = t2[i] / m[i], b = t2[i + 1] / m[i], s = a * a + b * b;
      if (s > 9) { const k = 3 / Math.sqrt(s); t2[i] = k * a * m[i]; t2[i + 1] = k * b * m[i]; }
    }
    let d = 'M' + pts[0][0] + ',' + pts[0][1];
    for (let i = 0; i < n - 1; i++) {
      const h = dx[i] / 3;
      d += ' C' + (pts[i][0] + h) + ',' + (pts[i][1] + h * t2[i]) + ' ' + (pts[i + 1][0] - h) + ',' + (pts[i + 1][1] - h * t2[i + 1]) + ' ' + pts[i + 1][0] + ',' + pts[i + 1][1];
    }
    return d;
  }

  /** Mini-gráfica blanca de las tarjetas de color: 'linea', 'area' o 'barras'. */
  function spark(host, valores, tipo, tinta) {
    const el = $(host);
    const w = 120, h = 50, max = Math.max(1, ...valores), n = valores.length;
    const tono = tinta || '#fff';
    let s = '<svg viewBox="0 0 ' + w + ' ' + h + '" preserveAspectRatio="none" aria-hidden="true">';
    if (tipo === 'barras') {
      const bw = w / n;
      valores.forEach((v, i) => {
        const bh = Math.max(2, v / max * (h - 4));
        s += '<rect x="' + (i * bw + bw * .22).toFixed(1) + '" y="' + (h - bh).toFixed(1) + '" width="' + (bw * .56).toFixed(1) + '" height="' + bh.toFixed(1) + '" fill="' + tono + '" opacity=".92"/>';
      });
    } else {
      const pts = valores.map((v, i) => [+(i / (n - 1) * w).toFixed(2), +(h - 3 - v / max * (h - 8)).toFixed(2)]);
      const d = curva(pts);
      if (tipo === 'area') s += '<path d="' + d + ' L' + w + ',' + h + ' L0,' + h + ' Z" fill="' + tono + '" opacity=".38"/>';
      s += '<path d="' + d + '" fill="none" stroke="' + tono + '" stroke-width="2.4" vector-effect="non-scaling-stroke" stroke-linejoin="round" stroke-linecap="round"/>';
    }
    el.innerHTML = s + '</svg>';
  }

  /** Gráfica de área: creadas (azul) vs finalizadas (amarillo). */
  function graficaArea(r) {
    datosGrafica = r;
    const host = $('#g-area');
    const W = Math.max(280, host.clientWidth), H = host.clientHeight || 270;
    const L = 34, R = 12, T = 12, B = 28, iw = W - L - R, ih = H - T - B;
    const p = r.puntos, n = p.length;
    const maxV = Math.max(1, ...p.map(x => Math.max(x.creadas, x.cerradas)));
    const paso = Math.max(1, Math.ceil(maxV / 4)), max = paso * 4;
    const X = i => L + (n === 1 ? iw / 2 : i / (n - 1) * iw), Y = v => T + ih - v / max * ih;
    const azul = color('--azul'), amar = color('--amarillo');
    let s = '<svg viewBox="0 0 ' + W + ' ' + H + '"><defs>' +
      '<linearGradient id="ga1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + azul + '" stop-opacity=".35"/><stop offset="1" stop-color="' + azul + '" stop-opacity="0"/></linearGradient>' +
      '<linearGradient id="ga2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + amar + '" stop-opacity=".28"/><stop offset="1" stop-color="' + amar + '" stop-opacity="0"/></linearGradient></defs>';
    for (let k = 0; k <= 4; k++) {
      const y = Y(k * paso);
      s += '<line class="rejilla-l" x1="' + L + '" x2="' + (W - R) + '" y1="' + y + '" y2="' + y + '"' + (k ? ' stroke-dasharray="3 4"' : '') + '/>' +
        '<text x="' + (L - 8) + '" y="' + (y + 4) + '" text-anchor="end">' + k * paso + '</text>';
    }
    const cada = Math.ceil(n / Math.max(2, Math.floor(iw / 62)));
    p.forEach((x, i) => { if (i % cada === 0 || i === n - 1) s += '<text x="' + X(i) + '" y="' + (H - 8) + '" text-anchor="middle">' + esc(x.etq) + '</text>'; });
    const serie = (k, col, grad) => {
      const pts = p.map((x, i) => [X(i), Y(x[k])]);
      const d = curva(pts);
      return '<path d="' + d + ' L' + X(n - 1) + ',' + Y(0) + ' L' + X(0) + ',' + Y(0) + ' Z" fill="url(#' + grad + ')"/>' +
        '<path d="' + d + '" fill="none" stroke="' + col + '" stroke-width="2.5" stroke-linejoin="round"/>' +
        (n <= 31 ? pts.map(q => '<circle cx="' + q[0] + '" cy="' + q[1] + '" r="3" fill="' + color('--card') + '" stroke="' + col + '" stroke-width="2"/>').join('') : '');
    };
    s += serie('cerradas', amar, 'ga2') + serie('creadas', azul, 'ga1');
    s += '<line id="g-guia" x1="0" x2="0" y1="' + T + '" y2="' + (T + ih) + '" stroke="' + color('--muted') + '" stroke-dasharray="3 3" opacity="0"/>';
    s += '<rect x="' + L + '" y="' + T + '" width="' + iw + '" height="' + ih + '" fill="transparent" id="g-captura"/></svg><div class="g-tip" id="g-tip" hidden></div>';
    host.innerHTML = s;
    const cap = $('#g-captura'), guia = $('#g-guia'), tip = $('#g-tip');
    cap.addEventListener('mousemove', ev => {
      const b = host.getBoundingClientRect();
      const xs = (ev.clientX - b.left) * (W / b.width);
      const i = Math.max(0, Math.min(n - 1, Math.round((xs - L) / (iw / Math.max(1, n - 1)))));
      guia.setAttribute('x1', X(i)); guia.setAttribute('x2', X(i)); guia.setAttribute('opacity', '1');
      tip.hidden = false;
      tip.style.left = (X(i) / W * b.width) + 'px'; tip.style.top = (Y(Math.max(p[i].creadas, p[i].cerradas)) / H * b.height) + 'px';
      tip.innerHTML = '<b>' + (r.por_semana ? 'Semana del ' : '') + esc(p[i].etq) + '</b>' + t('creadas') + ': ' + p[i].creadas + ' · ' + t('finalizadas') + ': ' + p[i].cerradas;
    });
    cap.addEventListener('mouseleave', () => { guia.setAttribute('opacity', '0'); tip.hidden = true; });
    $('#g-totales').innerHTML = '<div><b>' + r.totales.creadas + '</b><span>' + t('creadas') + '</span></div><div><b>' + r.totales.cerradas + '</b><span>' + t('finalizadas') + '</span></div>';
  }
  let rango = Number(leerLS('brake_rango')) || 30;
  async function cargarGrafica() {
    $$('.seg [data-rango]').forEach(b => b.classList.toggle('activo', Number(b.dataset.rango) === rango));
    try { graficaArea(await llamar('grafica', { dias: rango })); } catch (e) { toast(e.message, 'error'); }
  }
  $$('.seg [data-rango]').forEach(b => b.addEventListener('click', () => { rango = Number(b.dataset.rango); guardarLS('brake_rango', rango); cargarGrafica(); }));
  window.addEventListener('resize', debounce(() => { if (datosGrafica && vistaActual === 'resumen') graficaArea(datosGrafica); }, 150));

  function dona(host, partes) {
    const tot = partes.reduce((a, p) => a + p.n, 0);
    let acc = 0, s = '<svg viewBox="0 0 42 42"><circle cx="21" cy="21" r="15.915" fill="none" stroke="' + color('--azul-cl') + '" stroke-width="6"/>';
    if (tot) partes.forEach(p => {
      const v = p.n / tot * 100;
      if (v > 0) s += '<circle cx="21" cy="21" r="15.915" fill="none" stroke="' + p.col + '" stroke-width="6" stroke-dasharray="' + v + ' ' + (100 - v) + '" stroke-dashoffset="' + (-acc) + '"/>';
      acc += v;
    });
    $(host).innerHTML = s + '</svg><div class="dona-centro"><div><b>' + tot + '</b><span>' + t('total') + '</span></div></div>';
  }

  function barras(host, filas, max) {
    max = Math.max(1, max || Math.max(0, ...filas.map(f => f.n)));
    $(host).innerHTML = filas.length ? filas.map(f =>
      '<div class="barra"><span class="nom">' + esc(f.nom) + (f.sub ? '<small>' + esc(f.sub) + '</small>' : '') + '</span>' +
      '<span class="riel"><i class="' + (f.cls || '') + '" style="width:' + Math.round(f.n / max * 100) + '%"></i></span><b>' + f.n + '</b></div>'
    ).join('') : '<p class="muted">' + t('sin_datos') + '</p>';
  }

  /* =====================================================================
     RESUMEN
     ===================================================================== */
  function tendencia(sel, pct, texto, inverso) {
    const el = $(sel);
    if (pct === null || pct === undefined) { el.textContent = t('t_sin'); return; }
    const sube = pct > 0, flecha = pct === 0 ? '→' : sube ? '↑' : '↓';
    el.innerHTML = '<i>' + flecha + ' ' + (sube ? '+' : '') + pct + '%</i> ' + esc(texto);
    el.title = inverso ? 'Menos es mejor' : '';
  }
  function pintarResumen(r) {
    const k = r.kpi;
    $('#k-abiertas').textContent = k.abiertas;
    $('#k-urgentes').textContent = k.urgentes;
    $('#k-cerradas').textContent = k.cerrados30;
    $('#k-cierre').textContent = k.cierre_horas !== null ? k.cierre_horas + ' h' : '—';
    $('#k-cierre').title = k.cierre;
    tendencia('#k-abiertas-t', r.tendencia.creadas, t('t_semana'));
    tendencia('#k-urgentes-t', r.tendencia.urgentes, t('t_semana'));
    tendencia('#k-cerradas-t', r.tendencia.cerradas, t('t_mes'));
    tendencia('#k-cierre-t', r.tendencia.cierre, t('t_mes'), true);
    spark('#s-abiertas', r.spark.creadas, 'linea');
    spark('#s-urgentes', r.spark.urgentes, 'area');
    spark('#s-cerradas', r.spark.cerradas, 'barras', color('--marino'));
    spark('#s-cierre', r.spark.cierre, 'linea');

    const tira = [['pendiente', k.pendientes, t('e_pend'), 'var(--rojo)'], ['verificada', k.verificadas, t('e_verif'), 'var(--amarillo)'],
      ['en_proceso', k.en_proceso, t('e_proc'), 'var(--azul)'], ['finalizada', k.cerrados30, t('e_fin'), 'var(--marino)']];
    $('#estado-tira').innerHTML = tira.map(([e, n, txt, c]) =>
      '<a href="#ordenes" data-filtro="' + e + '"><i class="punto" style="background:' + c + '"></i><b>' + n + '</b><span>' + esc(txt) + '</span></a>').join('');

    dona('#g-dona', [{ n: r.tipo.hardware, col: color('--azul') }, { n: r.tipo.software, col: color('--amarillo') }]);
    const tot = r.tipo.hardware + r.tipo.software;
    const pc = n => tot ? Math.round(n / tot * 100) + '%' : '0%';
    $('#g-dona-ley').innerHTML =
      '<div><i style="background:var(--azul)"></i>Hardware<b>' + r.tipo.hardware + ' · ' + pc(r.tipo.hardware) + '</b></div>' +
      '<div><i style="background:var(--amarillo)"></i>Software<b>' + r.tipo.software + ' · ' + pc(r.tipo.software) + '</b></div>';
    barras('#g-tipo-equipo', r.por_tipo_equipo.map(x => ({ nom: x.tipo, n: Number(x.n), cls: 'r-marino' })));

    $('#g-recientes').innerHTML = r.recientes.length ? r.recientes.map(o =>
      '<tr class="clic" data-orden="' + o.id + '" tabindex="0"><td class="folio">' + esc(o.folio) + '</td><td>' + esc(o.equipo_ident) +
      '<br><small class="muted">' + esc(o.area || '') + '</small></td><td>' + esc(o.reporta_nombre) + '<br><small class="muted">' + esc(fechaCorta(o.creado)) + '</small></td>' +
      '<td>' + chipP(o.prioridad) + '</td><td>' + chipE(o.estado, o.estado_texto) + '</td><td>' + esc(o.tiempo_muerto || '—') + '</td></tr>').join('')
      : '<tr><td colspan="6" class="vacio">Todavía no hay órdenes. Se reportan desde la página de inicio con el número de tarjeta.</td></tr>';

    const cls = { baja: 'r-marino', media: '', alta: 'r-amarillo', critica: 'r-rojo' };
    barras('#g-prioridad', Object.keys(PRIORIDADES).map(p => ({ nom: PRIORIDADES[p], n: r.prioridad[p], cls: cls[p] })));
    barras('#g-equipos', r.top_equipos.map(e => ({
      nom: e.equipo, n: Number(e.n),
      sub: [e.area, e.responsable].filter(Boolean).join(' · ')
    })));
    const h = hoy();
    $('#g-proximos').innerHTML = r.proximos.length ? r.proximos.map(p => {
      const [, m, dd] = p.fecha.split('-');
      const vencido = p.fecha < h;
      return '<li><div class="fecha-cuadro"><span>' + MESES[Number(m) - 1].toUpperCase() + '</span><b>' + Number(dd) + '</b></div>' +
        '<div><strong>' + esc(p.titulo) + '</strong><small>' + esc([p.identificador, p.area, FREC[p.frecuencia], p.responsable].filter(Boolean).join(' · ')) + '</small></div>' +
        (vencido ? '<span class="chip est-pendiente">' + t('vencido') + '</span>' : '<span class="chip est-en_proceso">' + (idioma === 'en' ? 'Scheduled' : 'Programado') + '</span>') + '</li>';
    }).join('') : '<li class="muted">No hay preventivos programados. Agréguelos en el calendario.</li>';

    const inv = r.inventario;
    const conFalla = r.por_area.reduce((a, x) => a + Number(x.con_falla), 0);
    $('#g-inv').innerHTML = [[inv.activos, t('inv_total')], [conFalla, t('inv_falla')], [inv.sin_tarjeta, t('inv_tarjeta')], [inv.sin_preventivo, t('inv_prev')]]
      .map(([n, txt]) => '<div><b>' + n + '</b><span>' + esc(txt) + '</span></div>').join('');
    barras('#g-area-eq', r.por_area.map(a => ({ nom: a.area, n: Number(a.n), sub: Number(a.con_falla) ? a.con_falla + ' con orden abierta' : '' })));
    badges(r.badges);
  }
  cargadores.resumen = async () => {
    try {
      const [r] = await Promise.all([llamar('resumen'), cargarGrafica()]);
      ultimoResumen = r;
      pintarResumen(r);
    } catch (e) { toast(e.message, 'error'); }
  };
  $('#estado-tira').addEventListener('click', ev => {
    const a = ev.target.closest('[data-filtro]');
    if (!a) return;
    ev.preventDefault();
    $('#o-estado').value = a.dataset.filtro;
    ir('ordenes');
  });
  $('#g-recientes').addEventListener('click', ev => { const tr = ev.target.closest('[data-orden]'); if (tr) abrirOrden(Number(tr.dataset.orden)); });

  /* =====================================================================
     ÓRDENES
     ===================================================================== */
  const filtrosOrden = () => ({
    q: $('#o-q').value, estado: $('#o-estado').value, tipo: $('#o-tipo').value,
    prioridad: $('#o-prioridad').value, desde: $('#o-desde').value, hasta: $('#o-hasta').value
  });
  async function cargarOrdenes() {
    try {
      const r = await llamar('ordenes_listar', filtrosOrden());
      $('#o-filas').innerHTML = r.ordenes.map(o =>
        '<tr class="clic" data-orden="' + o.id + '" tabindex="0">' +
        '<td class="folio">' + esc(o.folio) + '</td><td>' + chipE(o.estado, o.estado_texto) + '</td><td>' + chipP(o.prioridad) + '</td>' +
        '<td>' + esc(o.tipo_texto) + '</td><td>' + esc(o.equipo_ident) + '<br><small class="muted">' + esc(o.area || '') + '</small></td>' +
        '<td>' + esc(o.reporta_nombre) + '<br><small class="muted">Tarjeta ' + esc(o.reporta_tarjeta) + '</small></td>' +
        '<td class="corto" title="' + esc(o.reporte) + '">' + esc(o.reporte) + '</td>' +
        '<td>' + esc(fechaCorta(o.fecha_paro)) + '</td><td>' + esc(o.tiempo_muerto || '—') + '</td></tr>'
      ).join('');
      $('#o-vacio').hidden = r.ordenes.length > 0;
    } catch (e) { toast(e.message, 'error'); }
  }
  cargadores.ordenes = cargarOrdenes;
  $('#o-q').addEventListener('input', debounce(cargarOrdenes, 300));
  ['#o-estado', '#o-tipo', '#o-prioridad', '#o-desde', '#o-hasta'].forEach(s => $(s).addEventListener('change', cargarOrdenes));
  $('#o-filas').addEventListener('click', ev => { const tr = ev.target.closest('[data-orden]'); if (tr) abrirOrden(Number(tr.dataset.orden)); });
  document.addEventListener('keydown', ev => {
    const tr = ev.target.closest && ev.target.closest('tr[data-orden]');
    if (tr && ev.key === 'Enter') abrirOrden(Number(tr.dataset.orden));
  });

  async function exportarCSV(todas) {
    try {
      const f = todas ? { estado: '' } : filtrosOrden();
      const r = await llamar('ordenes_listar', Object.assign(f, { completo: 1 }));
      const cols = [['folio', 'Folio'], ['estado_texto', 'Estado'], ['prioridad_texto', 'Prioridad'], ['tipo_texto', 'Tipo de falla'], ['area', 'Área'],
        ['equipo_ident', 'Equipo'], ['reporta_tarjeta', 'Tarjeta'], ['reporta_nombre', 'Reportó'], ['fecha_paro', 'Paro'], ['fecha_ejecucion', 'Ejecución'],
        ['fecha_entrega', 'Entrega'], ['tiempo_mtto', 'Tiempo de mantenimiento'], ['tiempo_muerto', 'Tiempo muerto'], ['ejecuto_nombre', 'Ejecutó'],
        ['reporte', 'Reporte'], ['descripcion', 'Descripción'], ['creado', 'Creada']];
      const celda = v => '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"';
      const csv = '﻿' + [cols.map(c => celda(c[1])).join(',')].concat(r.ordenes.map(o => cols.map(c => celda(o[c[0]])).join(','))).join('\r\n');
      const a = document.createElement('a');
      a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
      a.download = 'ordenes_mantenimiento_' + hoy() + '.csv';
      document.body.appendChild(a); a.click(); a.remove();
      toast(r.ordenes.length + ' órdenes exportadas.');
    } catch (e) { toast(e.message, 'error'); }
  }
  $('#o-exportar').addEventListener('click', () => exportarCSV(false));
  $('#app-exportar').addEventListener('click', () => exportarCSV(true));

  let ordenActual = null, leerOrden = null;
  async function abrirOrden(id) {
    try {
      const r = await llamar('orden_obtener', { id });
      const o = ordenActual = r.orden;
      $('#do-titulo').textContent = 'Orden ' + o.folio;
      msg('#do-msg', '');
      const orden = Object.keys(ESTADOS), pos = orden.indexOf(o.estado);
      $('#do-estados').innerHTML = orden.map((e, i) =>
        (i ? '<span class="sep">›</span>' : '') +
        '<button type="button" data-estado="' + e + '" class="' + (i < pos ? 'hecho' : i === pos ? 'actual' : '') + '">' + ESTADOS[e] + '</button>').join('');
      leerOrden = renderFormato($('#do-formato'), o, 'admin', { equipos: r.equipos, tecnicos: r.tecnicos });
      $('#do-historial').innerHTML = r.historial.map(h =>
        '<li>' + esc(fechaCorta(h.fecha)) + ' · <b>' + esc(h.estado_texto) + '</b>' + (h.nombre ? ' por ' + esc(h.nombre) : '') + (h.nota ? ' — ' + esc(h.nota) : '') + '</li>').join('');
      $('#do-imprimir').href = 'imprimir.php?id=' + o.id;
      const dlg = $('#dlg-orden');
      if (!dlg.open) dlg.showModal();
    } catch (e) { toast(e.message, 'error'); }
  }
  function refrescarVista() { if (cargadores[vistaActual]) cargadores[vistaActual](); }

  async function guardarOrden(silencioso) {
    const d = leerOrden();
    const r = await llamar('orden_guardar', Object.assign({ id: ordenActual.id }, d));
    if (!silencioso) toast(r.mensaje);
  }
  $('#do-guardar').addEventListener('click', async () => {
    try { await guardarOrden(false); msg('#do-msg', ''); await abrirOrden(ordenActual.id); refrescarVista(); }
    catch (e) { msg('#do-msg', e.message); }
  });
  $('#do-estados').addEventListener('click', async ev => {
    const b = ev.target.closest('[data-estado]');
    if (!b || b.dataset.estado === ordenActual.estado) return;
    const nuevo = b.dataset.estado;
    let nota = '';
    if (nuevo === 'finalizada' && !confirm('¿Finalizar la orden ' + ordenActual.folio + '? Si falta la fecha de entrega se tomará la hora actual.')) return;
    if (Object.keys(ESTADOS).indexOf(nuevo) < Object.keys(ESTADOS).indexOf(ordenActual.estado)) {
      nota = prompt('¿Por qué regresa la orden a «' + ESTADOS[nuevo] + '»? (opcional)') || '';
    }
    try {
      await guardarOrden(true);
      const r = await llamar('orden_estado', { id: ordenActual.id, estado: nuevo, nota });
      toast(r.mensaje);
      await abrirOrden(ordenActual.id);
      refrescarVista(); cargarNotif(true);
    } catch (e) { msg('#do-msg', e.message); }
  });
  if ($('#do-eliminar')) $('#do-eliminar').addEventListener('click', async () => {
    if (!confirm('¿Eliminar definitivamente la orden ' + ordenActual.folio + '? No se puede deshacer.')) return;
    try { const r = await llamar('orden_eliminar', { id: ordenActual.id }); toast(r.mensaje); $('#dlg-orden').close(); refrescarVista(); cargarNotif(true); }
    catch (e) { msg('#do-msg', e.message); }
  });

  /* =====================================================================
     CALENDARIO PREVENTIVO
     ===================================================================== */
  let mesVista = new Date(); mesVista.setDate(1);
  let catPrev = { equipos: [], tecnicos: [] }, prevs = [], prevActual = null;
  const iso = d => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());

  async function cargarCalendario() {
    const y = mesVista.getFullYear(), m = mesVista.getMonth();
    const primero = new Date(y, m, 1);
    const inicio = new Date(primero); inicio.setDate(1 - ((primero.getDay() + 6) % 7)); // lunes
    const fin = new Date(inicio); fin.setDate(inicio.getDate() + 41);
    $('#c-mes').textContent = MESES_L[m] + ' ' + y;
    try {
      const r = await llamar('preventivos_listar', { desde: iso(inicio), hasta: iso(fin) });
      prevs = r.preventivos; catPrev = { equipos: r.equipos, tecnicos: r.tecnicos };
      const h = r.hoy;
      let out = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'].map(s => '<div class="cal-sem">' + s + '</div>').join('');
      for (let i = 0; i < 42; i++) {
        const d = new Date(inicio); d.setDate(inicio.getDate() + i);
        const f = iso(d);
        const evs = prevs.filter(p => p.fecha === f);
        out += '<div class="cal-dia' + (d.getMonth() !== m ? ' fuera' : '') + (f === h ? ' hoy' : '') + '" data-dia="' + f + '" tabindex="0" role="button" aria-label="' + d.getDate() + ' de ' + MESES_L[d.getMonth()] + '">' +
          '<span class="num">' + d.getDate() + '</span>' +
          evs.map(p => '<span class="ev ' + p.estado + (p.estado === 'programado' && p.fecha < h ? ' vencido' : '') + '" data-prev="' + p.id + '" title="' +
            esc(p.titulo + (p.identificador ? ' · ' + p.identificador : '') + (p.responsable ? ' · ' + p.responsable : '')) + '">' +
            esc((p.identificador ? p.identificador + ' · ' : '') + p.titulo) + '</span>').join('') + '</div>';
      }
      $('#c-grid').innerHTML = out;
    } catch (e) { toast(e.message, 'error'); }
  }
  cargadores.calendario = cargarCalendario;
  $('#c-ant').addEventListener('click', () => { mesVista.setMonth(mesVista.getMonth() - 1); cargarCalendario(); });
  $('#c-sig').addEventListener('click', () => { mesVista.setMonth(mesVista.getMonth() + 1); cargarCalendario(); });
  $('#c-hoy').addEventListener('click', () => { mesVista = new Date(); mesVista.setDate(1); cargarCalendario(); });
  $('#c-nuevo').addEventListener('click', () => abrirPrev(null, hoy()));
  $('#c-grid').addEventListener('click', ev => {
    const e = ev.target.closest('[data-prev]');
    if (e) return abrirPrev(prevs.find(p => Number(p.id) === Number(e.dataset.prev)));
    const d = ev.target.closest('[data-dia]');
    if (d) abrirPrev(null, d.dataset.dia);
  });
  $('#c-grid').addEventListener('keydown', ev => { const d = ev.target.closest('[data-dia]'); if (d && ev.key === 'Enter') abrirPrev(null, d.dataset.dia); });

  function abrirPrev(p, fecha) {
    prevActual = p;
    $('#dp-equipo').innerHTML = '<option value="">Ninguno en particular</option>' + catPrev.equipos.map(e => '<option value="' + e.id + '">' + esc(e.identificador + ' · ' + e.nombre + (e.area ? ' (' + e.area + ')' : '')) + '</option>').join('');
    $('#dp-resp').innerHTML = '<option value="">Sin asignar</option>' + catPrev.tecnicos.map(x => '<option value="' + x.id + '">' + esc(x.nombre) + '</option>').join('');
    formLlenar($('#fp'), p || { fecha, frecuencia: 'unica' });
    $('#dp-titulo').textContent = p ? 'Editar preventivo' : 'Programar preventivo';
    $('#dp-estado').textContent = p ? 'Estado: ' + p.estado + (p.realizado_en ? ' (' + fechaCorta(p.realizado_en) + ')' : '') : '';
    ['#dp-eliminar', '#dp-realizado', '#dp-cancelar-ev'].forEach(s => { $(s).hidden = !p; });
    if (p) {
      $('#dp-realizado').textContent = p.estado === 'realizado' ? 'Volver a programado' : 'Marcar realizado';
      $('#dp-cancelar-ev').hidden = p.estado !== 'programado';
    }
    msg('#dp-msg', '');
    $('#dlg-prev').showModal();
  }
  $('#fp').addEventListener('submit', async ev => {
    ev.preventDefault();
    try {
      const r = await llamar('preventivo_guardar', Object.assign(formDatos($('#fp')), { id: prevActual ? prevActual.id : 0 }));
      toast(r.mensaje); $('#dlg-prev').close(); cargarCalendario();
    } catch (e) { msg('#dp-msg', e.message); }
  });
  async function estadoPrev(estado) {
    try {
      const r = await llamar('preventivo_estado', { id: prevActual.id, estado });
      toast(r.mensaje); $('#dlg-prev').close(); cargarCalendario(); cargarNotif(true);
    } catch (e) { msg('#dp-msg', e.message); }
  }
  $('#dp-realizado').addEventListener('click', () => estadoPrev(prevActual.estado === 'realizado' ? 'programado' : 'realizado'));
  $('#dp-cancelar-ev').addEventListener('click', () => estadoPrev('cancelado'));
  $('#dp-eliminar').addEventListener('click', async () => {
    if (!confirm('¿Eliminar este mantenimiento del calendario?')) return;
    try { const r = await llamar('preventivo_eliminar', { id: prevActual.id }); toast(r.mensaje); $('#dlg-prev').close(); cargarCalendario(); }
    catch (e) { msg('#dp-msg', e.message); }
  });

  /* =====================================================================
     EQUIPOS
     ===================================================================== */
  let equipos = [], equipoActual = null;
  function opcionesUnicas(sel, valores, primero) {
    const actual = $(sel).value;
    $(sel).innerHTML = '<option value="">' + primero + '</option>' + valores.map(v => '<option>' + esc(v) + '</option>').join('');
    $(sel).value = valores.includes(actual) ? actual : '';
  }
  function pintarEquipos() {
    const q = $('#e-q').value.trim().toLowerCase(), area = $('#e-area').value, tipo = $('#e-tipo').value;
    const lista = equipos.filter(e => (!area || e.area === area) && (!tipo || e.tipo === tipo) &&
      (!q || [e.identificador, e.nombre, e.area, e.asignado, e.responsable, e.tarjeta, e.tipo, e.serie, e.ip, e.nombre_red].join(' ').toLowerCase().includes(q)));
    const h = hoy();
    $('#e-filas').innerHTML = lista.map(e => {
      const prox = e.prox_preventivo || e.proximo_mtto;
      return '<tr' + (Number(e.activo) ? '' : ' class="muted"') + '><td class="folio">' + esc(e.identificador) + '</td>' +
        '<td>' + esc(e.nombre) + '<br><small class="muted">' + esc([e.tipo, e.serie ? 'Serie/MAC ' + e.serie : ''].filter(Boolean).join(' · ')) + '</small></td>' +
        '<td>' + esc(e.area || '') + '</td>' +
        '<td>' + (e.asignado ? esc(e.asignado) + '<br><small class="muted">Tarjeta ' + esc(e.tarjeta) + '</small>'
          : e.responsable ? esc(e.responsable) + '<br><small class="muted">Sin tarjeta ligada</small>' : '<span class="muted">Sin asignar</span>') + '</td>' +
        '<td>' + esc(e.ip || '') + (e.nombre_red ? '<br><small class="muted">' + esc(e.nombre_red) + '</small>' : '') + '</td>' +
        '<td>' + e.fallas + (Number(e.abiertas) ? ' <span class="chip est-pendiente">' + e.abiertas + ' abiertas</span>' : '') + '</td>' +
        '<td>' + (e.frecuencia_mtto ? esc(e.frecuencia_mtto) : '') + (prox ? '<br><small class="' + (prox < h ? 'peligro' : 'muted') + '">Próx. ' + esc(fechaD(prox)) + '</small>' : (e.frecuencia_mtto ? '' : '<span class="muted">—</span>')) + '</td>' +
        '<td class="acc"><button class="btn btn-sm" type="button" data-eq="' + e.id + '">Editar</button>' +
        (ADMIN ? ' <button class="btn btn-sm btn-rojo" type="button" data-eq-del="' + e.id + '">Eliminar</button>' : '') + '</td></tr>';
    }).join('');
    $('#e-vacio').hidden = lista.length > 0;
  }
  cargadores.equipos = async () => {
    try {
      equipos = (await llamar('equipos_listar')).equipos;
      const unicos = k => [...new Set(equipos.map(e => e[k]).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'es'));
      opcionesUnicas('#e-area', unicos('area'), 'Todas');
      opcionesUnicas('#e-tipo', unicos('tipo'), 'Todos');
      $('#tipos-equipo').innerHTML = unicos('tipo').map(v => '<option>' + esc(v) + '</option>').join('');
      $('#areas-equipo').innerHTML = unicos('area').map(v => '<option>' + esc(v) + '</option>').join('');
      pintarEquipos();
    } catch (e) { toast(e.message, 'error'); }
  };
  $('#e-q').addEventListener('input', pintarEquipos);
  $('#e-area').addEventListener('change', pintarEquipos);
  $('#e-tipo').addEventListener('change', pintarEquipos);
  function abrirEquipo(e) {
    equipoActual = e;
    formLlenar($('#fe'), e || { activo: 1 });
    $('#de-titulo').textContent = e ? 'Editar ' + e.identificador : 'Agregar equipo';
    $('#de-resp').textContent = e && e.asignado ? e.asignado : '';
    msg('#de-msg', '');
    $('#dlg-equipo').showModal();
  }
  $('#e-nuevo').addEventListener('click', () => abrirEquipo(null));
  $('#e-filas').addEventListener('click', async ev => {
    const b = ev.target.closest('[data-eq]');
    if (b) return abrirEquipo(equipos.find(e => Number(e.id) === Number(b.dataset.eq)));
    const del = ev.target.closest('[data-eq-del]');
    if (del && confirm('¿Eliminar este equipo? Las órdenes anteriores conservan su identificador.')) {
      try { const r = await llamar('equipo_eliminar', { id: Number(del.dataset.eqDel) }); toast(r.mensaje); cargadores.equipos(); }
      catch (e) { toast(e.message, 'error'); }
    }
  });
  $('#fe').addEventListener('submit', async ev => {
    ev.preventDefault();
    try {
      const r = await llamar('equipo_guardar', Object.assign(formDatos($('#fe')), { id: equipoActual ? equipoActual.id : 0 }));
      toast(r.mensaje); $('#dlg-equipo').close(); cargadores.equipos();
    } catch (e) { msg('#de-msg', e.message); }
  });

  /* =====================================================================
     USUARIOS
     ===================================================================== */
  let usuarios = null, trabActual = null, cuentaActual = null;
  const ROLES = { administrador: 'Administrador', tecnico: 'Técnico', usuario: 'Sin acceso' };
  function pintarUsuarios() {
    const q = $('#u-q').value.trim().toLowerCase();
    const lista = usuarios.trabajadores.filter(x => !q || [x.tarjeta, x.nombre, x.area, x.puesto, x.usuario].join(' ').toLowerCase().includes(q));
    $('#u-filas').innerHTML = lista.map(x =>
      '<tr><td class="folio">' + esc(x.tarjeta) + '</td><td>' + esc(x.nombre) + '</td><td>' + esc(x.area || '') + '</td><td>' + esc(x.puesto || '') + '</td>' +
      '<td>' + (x.rol ? '<span class="chip ' + (x.rol === 'administrador' ? 'est-finalizada' : 'est-en_proceso') + '">' + ROLES[x.rol] + '</span> <small class="muted">' + esc(x.usuario) + '</small>' : '<span class="muted">Solo reporta</span>') + '</td>' +
      '<td>' + x.equipos + '</td><td>' + x.reportes + (Number(x.reportes90) ? ' <small class="muted">(' + x.reportes90 + ' en 90 d)</small>' : '') + '</td>' +
      '<td>' + (Number(x.activo) ? 'Activo' : '<span class="peligro">Baja</span>') + '</td>' +
      '<td class="acc">' + (ADMIN ? '<button class="btn btn-sm" type="button" data-trab="' + x.id + '">Editar</button> <button class="btn btn-sm btn-rojo" type="button" data-trab-del="' + x.id + '">Eliminar</button>' : '') + '</td></tr>'
    ).join('');
    $('#u-vacio').hidden = lista.length > 0;
  }
  cargadores.usuarios = async () => {
    try {
      usuarios = await llamar('usuarios_listar');
      pintarUsuarios();
      barras('#u-por-equipo', usuarios.por_equipo.map(e => ({
        nom: e.equipo, n: Number(e.n),
        sub: (e.responsable ? 'Resp.: ' + e.responsable + ' · ' : 'Sin responsable · ') + e.hardware + ' hardware, ' + e.software + ' software'
      })));
      barras('#u-por-persona', usuarios.por_persona.map(p => ({ nom: p.nombre, n: Number(p.n), sub: 'Tarjeta ' + p.tarjeta + (p.equipos ? ' · ' + p.equipos : ''), cls: 'r-amarillo' })));
      const c = usuarios.cuentas_sin_tarjeta;
      $('#u-sin-tarjeta-env').hidden = !c.length;
      $('#u-cuentas').innerHTML = c.map(u =>
        '<tr><td class="folio">' + esc(u.usuario) + '</td><td>' + esc(u.nombre) + '</td><td>' + esc(ROLES[u.rol] || u.rol) + '</td>' +
        '<td>' + (Number(u.activo) ? 'Activa' : '<span class="peligro">Inactiva</span>') + '</td>' +
        '<td class="acc">' + (ADMIN ? '<button class="btn btn-sm" type="button" data-cuenta="' + u.id + '">Editar</button>' : '') + '</td></tr>').join('');
    } catch (e) { toast(e.message, 'error'); }
  };
  $('#u-q').addEventListener('input', () => usuarios && pintarUsuarios());

  function abrirTrab(x) {
    trabActual = x;
    formLlenar($('#ft'), x ? Object.assign({}, x, { password: '' }) : { activo: 1, rol: '' });
    $('#dt-titulo').textContent = x ? 'Editar trabajador' : 'Agregar trabajador';
    $('#dt-pass-nota').textContent = x && x.usuario_id ? 'Déjela vacía para no cambiarla.' : '';
    msg('#dt-msg', '');
    $('#dlg-trab').showModal();
  }
  if ($('#u-nuevo')) $('#u-nuevo').addEventListener('click', () => abrirTrab(null));
  $('#u-filas').addEventListener('click', async ev => {
    const b = ev.target.closest('[data-trab]');
    if (b) return abrirTrab(usuarios.trabajadores.find(x => Number(x.id) === Number(b.dataset.trab)));
    const del = ev.target.closest('[data-trab-del]');
    if (del && confirm('¿Eliminar a este trabajador? Ya no podrá reportar con su tarjeta. Sus reportes anteriores se conservan.')) {
      try { const r = await llamar('trabajador_eliminar', { id: Number(del.dataset.trabDel) }); toast(r.mensaje); cargadores.usuarios(); }
      catch (e) { toast(e.message, 'error'); }
    }
  });
  $('#ft').addEventListener('submit', async ev => {
    ev.preventDefault();
    try {
      const r = await llamar('trabajador_guardar', Object.assign(formDatos($('#ft')), { id: trabActual ? trabActual.id : 0 }));
      toast(r.mensaje); $('#dlg-trab').close(); cargadores.usuarios();
    } catch (e) { msg('#dt-msg', e.message); }
  });

  $('#u-cuentas').addEventListener('click', ev => {
    const b = ev.target.closest('[data-cuenta]');
    if (!b) return;
    cuentaActual = usuarios.cuentas_sin_tarjeta.find(u => Number(u.id) === Number(b.dataset.cuenta));
    formLlenar($('#fc'), Object.assign({}, cuentaActual, { password: '', tarjeta: '' }));
    $('#dc-titulo').textContent = 'Cuenta «' + cuentaActual.usuario + '»';
    $('#dc-eliminar').hidden = Number(cuentaActual.id) === Number(window.MTTO.yo);
    msg('#dc-msg', '');
    $('#dlg-cuenta').showModal();
  });
  $('#fc').addEventListener('submit', async ev => {
    ev.preventDefault();
    try {
      const r = await llamar('cuenta_guardar', Object.assign(formDatos($('#fc')), { id: cuentaActual.id }));
      toast(r.mensaje); $('#dlg-cuenta').close(); cargadores.usuarios();
    } catch (e) { msg('#dc-msg', e.message); }
  });
  $('#dc-eliminar').addEventListener('click', async () => {
    if (!confirm('¿Eliminar la cuenta «' + cuentaActual.usuario + '»?')) return;
    try { const r = await llamar('cuenta_eliminar', { id: cuentaActual.id }); toast(r.mensaje); $('#dlg-cuenta').close(); cargadores.usuarios(); }
    catch (e) { msg('#dc-msg', e.message); }
  });

  // Importar Excel de personal: columnas No. TARJETA, NOMBRE (y opcionales Área, Puesto, Status)
  if ($('#u-excel')) $('#u-excel').addEventListener('change', async ev => {
    const f = ev.target.files[0];
    ev.target.value = '';
    if (!f) return;
    try {
      const wb = XLSX.read(await f.arrayBuffer(), { type: 'array' });
      const hoja = wb.Sheets[wb.SheetNames[0]];
      const crudas = XLSX.utils.sheet_to_json(hoja, { defval: '', raw: false });
      const norm = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z]/g, '');
      const buscar = (fila, claves) => { for (const k of Object.keys(fila)) if (claves.some(c => norm(k).includes(c))) return fila[k]; return ''; };
      const filas = crudas.map(r => ({
        tarjeta: buscar(r, ['tarjeta', 'notarj', 'numero', 'nomina']),
        nombre: buscar(r, ['nombre']),
        area: buscar(r, ['area', 'departamento']),
        puesto: buscar(r, ['puesto', 'tipo']),
        status: buscar(r, ['status', 'estatus', 'estado'])
      })).filter(r => String(r.tarjeta).trim() && String(r.nombre).trim());
      if (!filas.length) throw new Error('No encontré las columnas «No. TARJETA» y «NOMBRE» en la primera hoja.');
      if (!confirm('Se importarán ' + filas.length + ' trabajadores. Los que ya existen (misma tarjeta) se actualizan. ¿Continuar?')) return;
      const r = await llamar('trabajadores_importar', { filas });
      toast(r.mensaje); cargadores.usuarios();
    } catch (e) { toast(e.message, 'error'); }
  });

  /* ---------------- Mi contraseña ---------------- */
  $('#btn-mi-pass').addEventListener('click', () => { $('#fpass').reset(); msg('#dpass-msg', ''); $('#dlg-pass').showModal(); });
  $('#fpass').addEventListener('submit', async ev => {
    ev.preventDefault();
    try { const r = await llamar('mi_password', formDatos($('#fpass'))); toast(r.mensaje); $('#dlg-pass').close(); }
    catch (e) { msg('#dpass-msg', e.message); }
  });

  /* ---------------- Inicio ---------------- */
  aplicarPref();
  aplicarIdioma(idioma);
  mostrar(location.hash.slice(1) || 'resumen');
  cargarNotif(true);
  setInterval(() => { if (!document.hidden) cargarNotif(true); }, 60000);
})();
