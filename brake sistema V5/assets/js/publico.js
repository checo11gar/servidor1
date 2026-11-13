/**
 * assets/js/publico.js — Página de entrada.
 * El formato aparece de inmediato; en «Responsable» se escribe la tarjeta y se busca
 * a la persona en la base de datos. Luego se elige el equipo, se describe la falla y se guarda.
 */
(function () {
  'use strict';
  const { $, esc, toast, api, renderFormato, fechaCorta } = window.Mtto;

  let datos = null;     // respuesta de "buscar" (persona encontrada)
  let leer = null;      // función que lee el formato
  let ultimaTarjeta = '';
  let ultimoIntento = '';

  function mensaje(texto, tipo) {
    $('#msg-formato').innerHTML = texto ? '<div class="mensaje mensaje-' + (tipo || 'error') + '" role="alert">' + esc(texto) + '</div>' : '';
  }
  const fecha = v => v ? v.split('-').reverse().join('/') : '';

  /* ---------- Panel lateral ---------- */
  function fila(et, val) {
    return val ? '<div class="ficha-fila"><span>' + esc(et) + '</span><b>' + esc(val) + '</b></div>' : '';
  }
  function fichaEquipo(idSel) {
    const host = $('#ficha-equipo');
    if (!datos) { host.innerHTML = '<p class="muted">Escriba su número de tarjeta para ver sus equipos.</p>'; return; }
    const id = Number(idSel);
    const mio = datos.mis_equipos.find(e => Number(e.id) === id);
    const otro = !mio && datos.equipos.find(e => Number(e.id) === id);
    if (mio) {
      host.innerHTML = '<div class="ficha-cab"><strong>' + esc(mio.identificador) + '</strong><span>' + esc(mio.nombre) + '</span></div>' +
        fila('Área', mio.area) + fila('Marca / modelo', [mio.marca, mio.modelo].filter(Boolean).join(' ')) +
        fila('Serie / MAC', mio.serie) + fila('Nombre en red', mio.nombre_red) + fila('IP', mio.ip) +
        (mio.hardware ? '<div class="ficha-bloque"><span>Hardware</span><p>' + esc(mio.hardware) + '</p></div>' : '') +
        fila('Monitor', mio.monitor) +
        (mio.perifericos ? '<div class="ficha-bloque"><span>Periféricos</span><p>' + esc(mio.perifericos) + '</p></div>' : '') +
        fila('Último mantenimiento', fecha(mio.ultimo_mtto)) +
        fila('Próximo preventivo', fecha(mio.prox_preventivo || mio.proximo_mtto)) +
        (Number(mio.abiertas) ? '<p class="mensaje mensaje-aviso" style="margin:.6rem 0 0">Este equipo ya tiene ' + mio.abiertas + ' orden(es) abierta(s).</p>' : '');
    } else if (otro) {
      host.innerHTML = '<div class="ficha-cab"><strong>' + esc(otro.identificador) + '</strong><span>' + esc(otro.nombre) + '</span></div>' +
        fila('Área', otro.area) + fila('Responsable', otro.responsable) +
        '<p class="muted" style="margin-top:.5rem">No está asignado a su tarjeta; se muestra solo la información básica.</p>';
    } else {
      host.innerHTML = '<p class="muted">Elija un equipo en <b>Identificador equipo</b> para ver su información.</p>';
    }
  }

  function pintarLateral() {
    if (!datos) {
      $('#mis-equipos').innerHTML = '<p class="muted">—</p>';
      $('#mis-ordenes').innerHTML = '<li class="muted">—</li>';
      fichaEquipo(null);
      return;
    }
    const mis = datos.mis_equipos;
    $('#mis-equipos').innerHTML = mis.length ? mis.map(e =>
      '<div class="equipo-mini"><strong>' + esc(e.identificador) + '</strong> · ' + esc(e.nombre) + '<br>' +
      '<span class="muted">' + esc([e.area, e.ip].filter(Boolean).join(' · ')) + '</span>' +
      '<br><button type="button" class="btn btn-sm" data-usar="' + e.id + '">Reportar este equipo</button></div>'
    ).join('') : '<p class="muted">No tiene equipos asignados. Elija el equipo de la lista o escriba su identificador.</p>';

    $('#mis-ordenes').innerHTML = datos.ordenes.length ? datos.ordenes.map(o =>
      '<li><span><b>' + esc(o.folio) + '</b> <span class="chip est-' + o.estado + '">' + esc(o.estado_texto) + '</span></span>' +
      '<span class="muted">' + esc(o.equipo_ident || '') + ' · ' + esc(fechaCorta(o.creado)) + '</span>' +
      '<a href="imprimir.php?id=' + o.id + '&t=' + o.token + '" target="_blank" rel="noopener">Ver / imprimir</a></li>'
    ).join('') : '<li class="muted">Aún no ha reportado fallas.</li>';
  }

  /* ---------- Formato ---------- */
  function nuevoFormato(tarjeta) {
    datos = null; ultimaTarjeta = ''; ultimoIntento = '';
    mensaje('');
    leer = renderFormato($('#formato'), { estado: 'pendiente', prioridad: 'media', reporta_tarjeta: tarjeta || '' }, 'reporte', {
      tarjetaEditable: true, equipos: [], misEquipos: [], onEquipo: id => fichaEquipo(id),
      // El NIP se valida en el servidor; solo el dueño de la tarjeta puede firmar «Reportó».
      firmaNip: (bloque, nip) => {
        if (!datos || $('#f-tarjeta').value.trim() !== ultimaTarjeta) return Promise.reject(new Error('Primero escriba su número de tarjeta en «Responsable» y pulse Buscar.'));
        return api('api/publico.php', { accion: 'firma_nip', tarjeta: ultimaTarjeta, nip });
      }
    });
    const inp = $('#f-tarjeta');
    $('#f-buscar').addEventListener('click', buscar);
    inp.addEventListener('keydown', ev => { if (ev.key === 'Enter') { ev.preventDefault(); buscar(); } });
    inp.addEventListener('blur', () => { const t = inp.value.trim(); if (t && t !== ultimaTarjeta && t !== ultimoIntento) buscar(); });
    inp.addEventListener('input', () => {
      if (datos && inp.value.trim() !== ultimaTarjeta) { datos = null; leer.setResponsable(null); leer.setEquipos([], [], null); pintarLateral(); }
    });
    pintarLateral();
    $('#paso-formato').hidden = false; $('#paso-listo').hidden = true;
    if (tarjeta) buscar(); else inp.focus();
  }

  let buscando = false;
  async function buscar() {
    const inp = $('#f-tarjeta');
    const tarjeta = inp.value.trim();
    if (!tarjeta || buscando) return;
    buscando = true; ultimoIntento = tarjeta; $('#f-buscar').disabled = true;
    try {
      datos = await api('api/publico.php', { accion: 'buscar', tarjeta });
      ultimaTarjeta = tarjeta;
      inp.classList.remove('invalido');
      mensaje('');
      leer.setResponsable(datos.trabajador);
      leer.setEquipos(datos.equipos, datos.mis_equipos, datos.mis_equipos.length === 1 ? datos.mis_equipos[0].id : null);
      pintarLateral();
      fichaEquipo(leer.equipoSeleccionado());
    } catch (e) {
      datos = null; ultimaTarjeta = '';
      inp.classList.add('invalido');
      leer.setResponsable(null);
      leer.setEquipos([], [], null);
      pintarLateral();
      mensaje(e.message);
    } finally { buscando = false; $('#f-buscar').disabled = false; }
  }

  document.addEventListener('click', ev => {
    const b = ev.target.closest('[data-usar]');
    if (!b) return;
    const sel = $('#f-equipo');
    sel.value = b.dataset.usar;
    sel.dispatchEvent(new Event('change'));
    $('#f-reporte').focus();
  });

  $('#btn-guardar').addEventListener('click', async () => {
    if (!datos || $('#f-tarjeta').value.trim() !== ultimaTarjeta) {
      $('#f-tarjeta').focus();
      return mensaje('Escriba su número de tarjeta en «Responsable» y pulse Buscar.');
    }
    const d = leer();
    if (!d.equipo_id && !d.equipo_ident) return mensaje('Elija el equipo o escriba su identificador.');
    if (!d.tipo_falla) return mensaje('Indique si la falla es de hardware o de software.');
    if (d.reporte.length < 5) return mensaje('Describa la falla en «Reporte del mantenimiento».');
    const btn = $('#btn-guardar');
    btn.disabled = true;
    try {
      const r = await api('api/publico.php', Object.assign({ accion: 'reportar', tarjeta: ultimaTarjeta }, d));
      $('#folio-listo').textContent = r.folio;
      $('#btn-imprimir').href = 'imprimir.php?id=' + r.id + '&t=' + r.token;
      $('#paso-formato').hidden = true; $('#paso-listo').hidden = false;
      window.scrollTo({ top: 0 });
    } catch (e) {
      mensaje(e.message);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } finally { btn.disabled = false; }
  });

  $('#btn-cancelar').addEventListener('click', () => { if (confirm('¿Limpiar el formato?')) nuevoFormato(''); });
  $('#btn-terminar').addEventListener('click', () => nuevoFormato(''));
  $('#btn-otra').addEventListener('click', () => nuevoFormato(ultimaTarjeta));

  nuevoFormato('');
})();
