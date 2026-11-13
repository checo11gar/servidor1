/**
 * assets/js/mtto-comun.js
 * Utilidades compartidas por la página pública y el panel:
 * peticiones, avisos, firma digital y el formato de Orden de Mantenimiento Correctivo.
 */
(function () {
  'use strict';

  const $  = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  function esc(t) {
    const d = document.createElement('div');
    d.textContent = t == null ? '' : String(t);
    return d.innerHTML;
  }

  let tt = null;
  function toast(msg, tipo) {
    const el = $('#toast');
    if (!el) return alert(msg);
    el.textContent = msg;
    el.className = 'toast visible' + (tipo === 'error' ? ' error' : '');
    clearTimeout(tt);
    tt = setTimeout(() => { el.className = 'toast'; }, 4200);
  }

  /** POST JSON con token CSRF; lanza Error con el mensaje del servidor. */
  async function api(url, datos, metodo) {
    const opciones = {
      method: metodo || 'POST',
      credentials: 'same-origin',
      headers: { Accept: 'application/json', 'X-CSRF-Token': window.MTTO.csrf }
    };
    if (opciones.method !== 'GET') {
      opciones.headers['Content-Type'] = 'application/json';
      opciones.body = JSON.stringify(datos || {});
    }
    const r = await fetch(url, opciones);
    let data = null;
    try { data = await r.json(); } catch (_) { /* respuesta no JSON */ }
    if (r.status === 401 && window.MTTO.panel) { location.href = 'login.php'; throw new Error('Sesión expirada'); }
    if (!r.ok || !data || data.ok === false) {
      throw new Error((data && data.error) || 'Error del servidor (' + r.status + ').');
    }
    return data;
  }

  /* ---------- Fechas ---------- */
  const pad = n => String(n).padStart(2, '0');
  function ahoraLocal() {
    const d = new Date();
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + 'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  }
  function hoy() { return ahoraLocal().slice(0, 10); }
  /** "2026-10-21 08:30:00" → "2026-10-21T08:30" (para <input type=datetime-local>) */
  function aInput(v) { return v ? String(v).replace(' ', 'T').slice(0, 16) : ''; }
  function fechaCorta(v) {
    if (!v) return '';
    const d = new Date(String(v).replace(' ', 'T'));
    if (isNaN(d)) return v;
    return pad(d.getDate()) + '/' + pad(d.getMonth() + 1) + '/' + d.getFullYear() + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  }
  function minutos(a, b) {
    if (!a || !b) return null;
    const m = Math.round((new Date(b) - new Date(a)) / 60000);
    return isNaN(m) || m < 0 ? null : m;
  }
  function duracion(min) {
    if (min == null) return '';
    let h = Math.floor(min / 60); const m = min % 60;
    if (h >= 24) { const d = Math.floor(h / 24); h %= 24; return d + ' d ' + h + ' h ' + m + ' min'; }
    return (h ? h + ' h ' : '') + m + ' min';
  }

  /* ---------- Firma digital ---------- */
  class Firma {
    constructor(host, valorInicial, editable) {
      this.host = host;
      this.valor = valorInicial || '';
      this.editable = !!editable;
      this.tocada = false;
      this.pintar();
    }
    pintar() {
      this.host.innerHTML = '';
      if (!this.editable) {
        this.host.innerHTML = this.valor ? '<img alt="Firma" src="' + this.valor + '">' : '<span class="firma-hint">Sin firma</span>';
        return;
      }
      const c = document.createElement('canvas');
      this.host.appendChild(c);
      const hint = document.createElement('span');
      hint.className = 'firma-hint';
      hint.textContent = 'Firme aquí con el mouse o el dedo';
      this.host.appendChild(hint);
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'btn btn-sm firma-borrar'; b.textContent = 'Borrar';
      this.host.appendChild(b);
      this.canvas = c;
      requestAnimationFrame(() => this.preparar(hint));
      b.addEventListener('click', () => {
        this.ctx.clearRect(0, 0, c.width, c.height);
        this.valor = ''; this.tocada = true; hint.hidden = false;
      });
    }
    preparar(hint) {
      const c = this.canvas;
      const r = c.getBoundingClientRect();
      const esc = window.devicePixelRatio || 1;
      c.width = Math.max(1, r.width * esc); c.height = Math.max(1, r.height * esc);
      const ctx = this.ctx = c.getContext('2d');
      ctx.scale(esc, esc);
      ctx.lineWidth = 2.2; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.strokeStyle = '#0a2a57';
      if (this.valor) {
        const im = new Image();
        im.onload = () => ctx.drawImage(im, 0, 0, r.width, r.height);
        im.src = this.valor; hint.hidden = true;
      }
      let dibujando = false;
      const pos = e => { const b = c.getBoundingClientRect(); return [e.clientX - b.left, e.clientY - b.top]; };
      c.addEventListener('pointerdown', e => {
        dibujando = true; c.setPointerCapture(e.pointerId);
        const [x, y] = pos(e); ctx.beginPath(); ctx.moveTo(x, y); hint.hidden = true; this.tocada = true;
      });
      c.addEventListener('pointermove', e => { if (!dibujando) return; const [x, y] = pos(e); ctx.lineTo(x, y); ctx.stroke(); });
      const fin = () => { if (dibujando) { dibujando = false; this.valor = c.toDataURL('image/png'); } };
      c.addEventListener('pointerup', fin); c.addEventListener('pointerleave', fin); c.addEventListener('pointercancel', fin);
    }
    obtener() { return this.valor || ''; }
    /* Añadido: muestra la firma guardada que devolvió el servidor al validar el NIP (solo lectura). */
    poner(v) { this.valor = v || ''; this.editable = false; this.pintar(); }
  }

  /* ---------- Formato de Orden de Mantenimiento Correctivo ---------- */
  const ESTADOS = { pendiente: 'Pendiente', verificada: 'Verificada', en_proceso: 'En proceso', finalizada: 'Finalizada' };
  const PRIORIDADES = { baja: 'Baja', media: 'Media', alta: 'Alta', critica: 'Crítica' };

  function opcionesEquipo(opc, seleccionado, textoLibre) {
    let h = '<option value="">Seleccione…</option>';
    const mis = opc.misEquipos || [];
    const misIds = new Set(mis.map(e => Number(e.id)));
    if (mis.length) {
      h += '<optgroup label="Mis equipos">' + mis.map(e =>
        '<option value="' + e.id + '"' + (Number(seleccionado) === Number(e.id) ? ' selected' : '') + '>' + esc(e.identificador + ' · ' + e.nombre) + '</option>').join('') + '</optgroup>';
    }
    const otros = (opc.equipos || []).filter(e => !misIds.has(Number(e.id)));
    if (otros.length) {
      h += '<optgroup label="' + (mis.length ? 'Otros equipos' : 'Equipos') + '">' + otros.map(e =>
        '<option value="' + e.id + '"' + (Number(seleccionado) === Number(e.id) ? ' selected' : '') + '>' +
        esc(e.identificador + ' · ' + e.nombre + (e.area || e.responsable ? ' (' + [e.area, e.responsable].filter(Boolean).join(' — ') + ')' : '')) + '</option>').join('') + '</optgroup>';
    }
    h += '<option value="otro"' + (!seleccionado && textoLibre ? ' selected' : '') + '>Otro: escribir identificador</option>';
    return h;
  }

  function radios(nombre, mapa, valor, deshabilitado) {
    return '<div class="radios">' + Object.keys(mapa).map(k =>
      '<label><input type="radio" name="' + nombre + '" value="' + k + '"' + (valor === k ? ' checked' : '') + (deshabilitado ? ' disabled' : '') + '> ' + esc(mapa[k]) + '</label>'
    ).join('') + '</div>';
  }

  function renderFormato(host, o, modo, opc) {
    o = o || {}; opc = opc || {};
    const adm = modo === 'admin';
    const dis = adm ? '' : ' disabled';
    const mttoCls = adm ? '' : ' solo-mtto';
    const tecOpts = (opc.tecnicos || []).map(t =>
      '<option value="' + t.id + '"' + (Number(o.ejecuto_id) === Number(t.id) ? ' selected' : '') + '>' + esc(t.nombre) + '</option>').join('');

    // Bloques que se pueden firmar aquí: en la página pública solo «Reportó»; en el panel los tres.
    const puede = { reporto: true, ejecuto: adm, recibio: adm };

    host.innerHTML =
    '<div class="fmt">' +
      '<div class="fmt-cab">' +
        '<div class="fmt-logo"><img src="' + (opc.logo || 'assets/logo/logo-brake-nuevo.png') + '" alt=""><span>AUTO MANUFACTURAS<br>BRAKE, S.A. DE C.V.</span></div>' +
        '<div class="fmt-titulo"><h2>Orden de mantenimiento correctivo</h2></div>' +
        '<div class="fmt-folio"><small>Folio</small>' + (o.folio ? '<b>' + esc(o.folio) + '</b>' : '<span class="muted">Se asigna al guardar</span>') + '</div>' +
      '</div>' +
      '<div class="fmt-fila f-3">' +
        '<div class="fmt-c"><label for="f-area">Área / departamento</label><input id="f-area" maxlength="80" readonly tabindex="-1" title="Campo bloqueado: se llena automáticamente" value="' + esc(o.area || '') + '"></div>' +
        (opc.tarjetaEditable
          ? '<div class="fmt-c c-resp"><label for="f-tarjeta">Responsable · número de tarjeta</label>' +
              '<div class="tarjeta-linea"><input id="f-tarjeta" inputmode="numeric" maxlength="20" autocomplete="off" placeholder="Ej. 837" value="' + esc(o.reporta_tarjeta || '') + '">' +
              '<button type="button" class="btn btn-primario btn-sm" id="f-buscar">Buscar</button></div>' +
              '<div class="resp-nombre" id="f-resp-nombre">' + esc(o.reporta_nombre || '') + '</div></div>'
          : '<div class="fmt-c"><span class="et">Responsable (quien reporta)</span><div class="dato">' + esc(o.reporta_nombre || '') +
              '</div><small class="muted">Tarjeta ' + esc(o.reporta_tarjeta || '') + '</small></div>') +
        '<div class="fmt-c"><label for="f-equipo">Identificador equipo</label>' +
          '<select id="f-equipo">' + opcionesEquipo(opc, o.equipo_id, o.equipo_ident) + '</select>' +
          '<input id="f-equipo-libre" maxlength="60" placeholder="Ej. PC-CAL-03" value="' + esc(!o.equipo_id ? (o.equipo_ident || '') : '') + '" hidden>' +
        '</div>' +
      '</div>' +
      '<div class="fmt-fila f-3i">' +
        '<div class="fmt-c"><span class="et">Tipo de falla</span>' + radios('f-tipo', { hardware: 'Hardware (equipo físico)', software: 'Software (programas, sistema, red)' }, o.tipo_falla || '', false) + '</div>' +
        '<div class="fmt-c"><span class="et">Prioridad</span>' + radios('f-prioridad', PRIORIDADES, o.prioridad || '', false) + '</div>' +
        '<div class="fmt-c"><span class="et">Estado</span><div class="dato"><span class="chip est-' + (o.estado || 'pendiente') + '">' +
          esc(ESTADOS[o.estado || 'pendiente']) + '</span></div></div>' +
      '</div>' +
      '<div class="fmt-fila f-5">' +
        '<div class="fmt-c"><label for="f-paro">Fecha y hora de paro</label><input type="datetime-local" id="f-paro" value="' + esc(aInput(o.fecha_paro) || (adm ? '' : ahoraLocal())) + '"></div>' +
        '<div class="fmt-c' + mttoCls + '"><label class="et" for="f-ejec">Fecha y hora de ejecución</label><input type="datetime-local" id="f-ejec" value="' + esc(aInput(o.fecha_ejecucion)) + '"' + dis + '></div>' +
        '<div class="fmt-c' + mttoCls + '"><label class="et" for="f-entr">Fecha y hora de entrega</label><input type="datetime-local" id="f-entr" value="' + esc(aInput(o.fecha_entrega)) + '"' + dis + '></div>' +
        '<div class="fmt-c' + mttoCls + '"><span class="et">Tiempo de mantenimiento</span><div class="calc" id="f-tmtto"></div></div>' +
        '<div class="fmt-c' + mttoCls + '"><span class="et">Tiempo muerto</span><div class="calc" id="f-tmuerto"></div></div>' +
      '</div>' +
      '<div class="fmt-seccion">Reporte del mantenimiento</div>' +
      '<div class="fmt-area"><label class="sr-only" for="f-reporte">Reporte del mantenimiento</label>' +
        '<textarea id="f-reporte" maxlength="5000" placeholder="¿Qué falla tiene el equipo? ¿Desde cuándo? ¿Aparece algún mensaje de error?">' + esc(o.reporte || '') + '</textarea></div>' +
      '<div class="fmt-seccion">Descripción del mantenimiento y observaciones</div>' +
      '<div class="fmt-area' + mttoCls + '"><label class="sr-only" for="f-desc">Descripción del mantenimiento</label>' +
        '<textarea id="f-desc" maxlength="5000"' + dis + ' placeholder="' + (adm ? 'Trabajo realizado, refacciones, observaciones…' : 'Lo llena Mantenimiento') + '">' + esc(o.descripcion || '') + '</textarea></div>' +
      '<div class="fmt-fila f-3i">' +
        '<div class="fmt-c"><span class="et">Firma de quien reportó</span>' +
          '<div class="firma-caja" id="firma-reporto"></div><div class="firma-acc" id="acc-reporto"></div>' +
          '<small>Fecha: ' + esc(o.fecha_firma_reporto || (adm ? '' : 'hoy')) + '</small></div>' +
        '<div class="fmt-c' + mttoCls + '"><span class="et">Firma de quien ejecutó</span>' +
          (adm ? '<select id="f-ejecuto"><option value="">Seleccione técnico…</option>' + tecOpts + '</select>' : '') +
          '<div class="firma-caja" id="firma-ejecuto"></div><div class="firma-acc" id="acc-ejecuto"></div>' +
          '<label class="muted">Fecha: <input type="date" id="f-fecha-ejecuto" value="' + esc(o.fecha_firma_ejecuto || '') + '"' + dis + ' style="width:auto"></label></div>' +
        '<div class="fmt-c' + mttoCls + '"><span class="et">Firma de quien recibió (líder)</span>' +
          '<input id="f-recibio" maxlength="120" placeholder="Nombre de quien recibe" value="' + esc(o.recibio_nombre || '') + '"' + dis + '>' +
          '<div class="firma-caja" id="firma-recibio"></div><div class="firma-acc" id="acc-recibio"></div>' +
          '<label class="muted">Fecha: <input type="date" id="f-fecha-recibio" value="' + esc(o.fecha_firma_recibio || '') + '"' + dis + ' style="width:auto"></label></div>' +
      '</div>' +
    '</div>';

    const firmas = {
      reporto: new Firma($('#firma-reporto', host), o.firma_reporto, false),
      ejecuto: new Firma($('#firma-ejecuto', host), o.firma_ejecuto, false),
      recibio: new Firma($('#firma-recibio', host), o.firma_recibio, false)
    };
    // Estado de cada firma: «cargar» = se validó un NIP (el servidor pondrá la imagen al guardar); «quitar» = borrar la existente.
    const orig = { reporto: !!o.firma_reporto, ejecuto: !!o.firma_ejecuto, recibio: !!o.firma_recibio };
    const est = { reporto: { cargar: false, quitar: false }, ejecuto: { cargar: false, quitar: false }, recibio: { cargar: false, quitar: false } };
    const botonesFirma = b => {
      const tiene = !!firmas[b].obtener();
      let h = '';
      if (!tiene && puede[b]) h = '<button type="button" class="btn btn-sm btn-nip" data-bloque="' + b + '">Cargar firma</button>';
      else if (tiene && (adm || est[b].cargar)) h = '<button type="button" class="btn btn-sm" data-quitar="' + b + '">Quitar firma</button>';
      $('#acc-' + b, host).innerHTML = h;
      const caja = $('#firma-' + b, host);
      caja.style.pointerEvents = 'none';
      caja.style.opacity = tiene || !puede[b] ? '1' : '0.35';
    };
    BLOQUES.forEach(botonesFirma);
    host.onclick = ev => {
      const bn = ev.target.closest('.btn-nip');
      if (bn) {
        const b = bn.dataset.bloque;
        if (!opc.firmaNip) return toast('La firma por NIP no está disponible aquí.', 'error');
        abrirNip(nip => opc.firmaNip(b, nip), r => {
          firmas[b].poner(r.imagen); est[b].cargar = true; botonesFirma(b);
          if (b === 'ejecuto' && adm && r.usuario_id && $('#f-ejecuto option[value="' + r.usuario_id + '"]', host)) $('#f-ejecuto', host).value = String(r.usuario_id);
          if (b === 'recibio' && adm && !$('#f-recibio', host).value.trim()) $('#f-recibio', host).value = r.nombre;
        });
        return;
      }
      const bq = ev.target.closest('[data-quitar]');
      if (bq) {
        const b = bq.dataset.quitar;
        firmas[b].poner(''); est[b].cargar = false; est[b].quitar = orig[b]; botonesFirma(b);
      }
    };

    const sel = $('#f-equipo', host), libre = $('#f-equipo-libre', host);
    const verLibre = () => { libre.hidden = sel.value !== 'otro'; if (!libre.hidden) libre.focus(); };
    sel.addEventListener('change', () => { verLibre(); if (opc.onEquipo) opc.onEquipo(sel.value); });
    libre.hidden = sel.value !== 'otro';

    const calcular = () => {
      const p = $('#f-paro', host).value, ej = $('#f-ejec', host).value, en = $('#f-entr', host).value;
      $('#f-tmtto', host).textContent = duracion(minutos(ej, en)) || '—';
      $('#f-tmuerto', host).textContent = duracion(minutos(p, en)) || '—';
    };
    ['#f-paro', '#f-ejec', '#f-entr'].forEach(s => $(s, host).addEventListener('input', calcular));
    calcular();

    function leer() {
      const tipo = $('input[name="f-tipo"]:checked', host);
      const pri = $('input[name="f-prioridad"]:checked', host);
      const d = {
        area: $('#f-area', host).value.trim(),
        equipo_id: sel.value && sel.value !== 'otro' ? Number(sel.value) : null,
        equipo_ident: sel.value === 'otro' ? libre.value.trim() : '',
        tipo_falla: tipo ? tipo.value : '',
        prioridad: pri ? pri.value : 'media',
        fecha_paro: $('#f-paro', host).value,
        reporte: $('#f-reporte', host).value.trim(),
        firma_reporto_cargar: est.reporto.cargar
      };
      if (adm) {
        Object.assign(d, {
          fecha_ejecucion: $('#f-ejec', host).value,
          fecha_entrega: $('#f-entr', host).value,
          descripcion: $('#f-desc', host).value.trim(),
          ejecuto_id: $('#f-ejecuto', host).value ? Number($('#f-ejecuto', host).value) : null,
          recibio_nombre: $('#f-recibio', host).value.trim(),
          fecha_firma_ejecuto: $('#f-fecha-ejecuto', host).value,
          fecha_firma_recibio: $('#f-fecha-recibio', host).value,
          firma_reporto_quitar: est.reporto.quitar,
          firma_ejecuto_cargar: est.ejecuto.cargar, firma_ejecuto_quitar: est.ejecuto.quitar,
          firma_recibio_cargar: est.recibio.cargar, firma_recibio_quitar: est.recibio.quitar
        });
      }
      return d;
    }
    leer.setEquipos = (equipos, misEquipos, seleccionado) => {
      opc.equipos = equipos || []; opc.misEquipos = misEquipos || [];
      sel.innerHTML = opcionesEquipo(opc, seleccionado || null, '');
      libre.hidden = sel.value !== 'otro';
      if (opc.onEquipo) opc.onEquipo(sel.value);
    };
    leer.setResponsable = t => {
      const nom = $('#f-resp-nombre', host);
      if (nom) nom.textContent = t ? (t.nombre || '') : '';
      const area = $('#f-area', host);
      if (t && t.area && !area.value.trim()) area.value = t.area;
    };
    leer.equipoSeleccionado = () => sel.value;
    return leer;
  }

  /* ---------- Ventana de NIP (validación real en el servidor) ---------- */
  const BLOQUES = ['reporto', 'ejecuto', 'recibio'];
  let nipValidar = null, nipListo = null, nipOcupado = false;
  const NIP_CUERPO =
    '<p class="muted" style="margin-bottom:1rem; text-align:center;">Ingrese su NIP de 4 dígitos para cargar su firma.</p>' +
    '<div id="nip-err"></div>' +
    '<div style="display:flex; justify-content:center; margin: 1rem 0;">' +
      '<input type="password" id="nip-val" maxlength="4" required inputmode="numeric" pattern="[0-9]{4}" placeholder="••••" autocomplete="off" style="font-size: 2.2rem; letter-spacing: .4em; text-align: center; width: 160px; padding: .6rem; border-radius: 8px;">' +
    '</div>';

  (function estilosNip() {
  const style = document.createElement('style');
  style.textContent = `
    .nip-success-icon { width: 72px; height: 72px; margin: 0 auto 1.2rem; display: block; animation: nip-pop 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275) both; }
    .nip-success-circle { stroke-dasharray: 166; stroke-dashoffset: 166; stroke-width: 2.5; stroke: #108a46; fill: none; animation: nip-stroke 0.5s cubic-bezier(0.65, 0, 0.45, 1) forwards; }
    .nip-success-check { stroke-dasharray: 48; stroke-dashoffset: 48; stroke-width: 3.5; stroke: #108a46; fill: none; transform-origin: 50% 50%; animation: nip-stroke 0.3s cubic-bezier(0.65, 0, 0.45, 1) 0.4s forwards; }
    @keyframes nip-stroke { 100% { stroke-dashoffset: 0; } }
    @keyframes nip-pop { 0% { transform: scale(0.8); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }
    .nip-text-fade { animation: nip-pop 0.4s ease-out 0.3s both; }
    .firma-acc { margin: .4rem 0 .2rem; } .firma-acc .btn { width: 100%; }
  `;
  document.head.appendChild(style);
  })();

  function prepararModalNip() {
    if ($('#dlg-nip')) return;

    const dlg = document.createElement('dialog');
    dlg.id = 'dlg-nip';
    dlg.className = 'ventana angosta';
    dlg.innerHTML =
      '<form method="dialog" id="f-nip">' +
        '<div class="ventana-cab"><h2>Autorización de firma</h2><button class="cerrar-x" type="button" data-cerrar aria-label="Cerrar">×</button></div>' +
        '<div class="ventana-cuerpo" id="nip-cuerpo" style="min-height: 180px; display: flex; flex-direction: column; justify-content: center;">' + NIP_CUERPO + '</div>' +
        '<div class="ventana-pie" id="nip-pie"><span></span><div class="der"><button class="btn" type="button" data-cerrar>Cancelar</button><button class="btn btn-primario" type="submit" id="nip-ok">Validar NIP</button></div></div>' +
      '</form>';
    document.body.appendChild(dlg);
    dlg.addEventListener('click', e => { if (e.target.closest('[data-cerrar]')) dlg.close(); });

    $('#f-nip').addEventListener('submit', async e => {
      e.preventDefault();
      if (nipOcupado || !nipValidar) return;
      const inp = $('#nip-val');
      const nip = inp.value.trim();
      const err = t => { $('#nip-err').innerHTML = '<div class="mensaje mensaje-error" role="alert">' + esc(t) + '</div>'; inp.value = ''; inp.focus(); };
      if (!/^\d{4}$/.test(nip)) return err('El NIP debe ser de 4 dígitos.');
      nipOcupado = true; $('#nip-ok').disabled = true;
      let r;
      try { r = await nipValidar(nip); }
      catch (ex) { nipOcupado = false; $('#nip-ok').disabled = false; return err(ex.message); }
      nipOcupado = false; $('#nip-ok').disabled = false;

      $('#nip-pie').style.display = 'none';
      $('#nip-cuerpo').innerHTML =
        '<div style="text-align:center; padding: 1rem 0;">' +
          '<svg class="nip-success-icon" viewBox="0 0 52 52"><circle class="nip-success-circle" cx="26" cy="26" r="25"/>' +
          '<path class="nip-success-check" d="M14.1 27.2l7.1 7.2 16.7-16.8" stroke-linecap="round" stroke-linejoin="round"/></svg>' +
          '<h3 class="nip-text-fade" style="color: var(--marino); margin-bottom: .4rem; font-size: 1.4rem;">NIP Válido</h3>' +
          '<p class="muted nip-text-fade" style="font-size: 1rem; margin: 0;">' + 'Autorización concedida.' + '</p>' +
        '</div>';
      const alTerminar = nipListo;
      setTimeout(() => {
        dlg.close();
        if (alTerminar) alTerminar(r);
        setTimeout(() => { $('#nip-cuerpo').innerHTML = NIP_CUERPO; $('#nip-pie').style.display = 'flex'; }, 300);
      }, 1800);
    });
  }

  /** Abre la ventana: validar(nip) → Promise con la respuesta del servidor; listo(respuesta) se llama al validarse. */
  function abrirNip(validar, listo) {
    prepararModalNip();
    nipValidar = validar; nipListo = listo;
    $('#nip-err').innerHTML = '';
    $('#nip-val').value = '';
    $('#dlg-nip').showModal();
    setTimeout(() => $('#nip-val').focus(), 100);
  }

  window.Mtto = { abrirNip, $, $$, esc, toast, api, ahoraLocal, hoy, aInput, fechaCorta, minutos, duracion, Firma, renderFormato, ESTADOS, PRIORIDADES };
})();
