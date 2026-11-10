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
  }

  /* ---------- Formato de Orden de Mantenimiento Correctivo ----------
   * modo 'reporte': lo llena quien reporta (página pública).
   * modo 'admin'  : lo completa Mantenimiento (panel).
   * o = datos de la orden; opc = { equipos, misEquipos, tecnicos, logo }
   */
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
              '<div class="dato" id="f-resp-nombre">' + esc(o.reporta_nombre || '') + '</div><small class="muted" id="f-resp-sub"></small></div>'
          : '<div class="fmt-c"><span class="et">Responsable (quien reporta)</span><div class="dato">' + esc(o.reporta_nombre || '') +
              '</div><small class="muted">Tarjeta ' + esc(o.reporta_tarjeta || '') + '</small></div>') +
        '<div class="fmt-c"><label for="f-equipo">Identificador equipo</label>' +
          '<select id="f-equipo">' + opcionesEquipo(opc, o.equipo_id, o.equipo_ident) + '</select>' +
          '<input id="f-equipo-libre" maxlength="60" placeholder="Ej. PC-CAL-03" value="' + esc(!o.equipo_id ? (o.equipo_ident || '') : '') + '" hidden>' +
        '</div>' +
      '</div>' +
      '<div class="fmt-fila f-3i">' +
        '<div class="fmt-c"><span class="et">Tipo de falla</span>' + radios('f-tipo', { hardware: 'Hardware (equipo físico)', software: 'Software (programas, sistema, red)' }, o.tipo_falla || '', false) + '</div>' +
        '<div class="fmt-c"><span class="et">Prioridad</span>' + radios('f-prioridad', PRIORIDADES, o.prioridad || 'media', false) + '</div>' +
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
        '<div class="fmt-c"><span class="et">Reportó nombre y firma</span><div class="firma-nombre" id="f-firma-nombre">' + esc(o.reporta_nombre || '') + '</div>' +
          '<div class="firma-caja" id="firma-reporto"></div>' +
          '<small>Fecha: ' + esc(o.fecha_firma_reporto || (adm ? '' : 'hoy')) + '</small></div>' +
        '<div class="fmt-c' + mttoCls + '"><span class="et">Ejecutó mantenimiento nombre y firma</span>' +
          (adm ? '<select id="f-ejecuto"><option value="">Seleccione técnico…</option>' + tecOpts + '</select>' : '<div class="firma-nombre">' + esc(o.ejecuto_nombre || '') + '</div>') +
          '<div class="firma-caja" id="firma-ejecuto"></div>' +
          '<label class="muted">Fecha: <input type="date" id="f-fecha-ejecuto" value="' + esc(o.fecha_firma_ejecuto || '') + '"' + dis + ' style="width:auto"></label></div>' +
        '<div class="fmt-c' + mttoCls + '"><span class="et">Recibió nombre y firma (líder)</span>' +
          '<input id="f-recibio" maxlength="120" placeholder="Nombre de quien recibe" value="' + esc(o.recibio_nombre || '') + '"' + dis + '>' +
          '<div class="firma-caja" id="firma-recibio"></div>' +
          '<label class="muted">Fecha: <input type="date" id="f-fecha-recibio" value="' + esc(o.fecha_firma_recibio || '') + '"' + dis + ' style="width:auto"></label></div>' +
      '</div>' +
    '</div>';

    const firmas = {
      reporto: new Firma($('#firma-reporto', host), o.firma_reporto, !adm || !o.firma_reporto),
      ejecuto: new Firma($('#firma-ejecuto', host), o.firma_ejecuto, adm),
      recibio: new Firma($('#firma-recibio', host), o.firma_recibio, adm)
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

    /** Devuelve los datos capturados en el formato. */
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
        firma_reporto: firmas.reporto.obtener()
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
          firma_ejecuto: firmas.ejecuto.obtener(),
          firma_recibio: firmas.recibio.obtener()
        });
      }
      return d;
    }
    /** Recarga la lista de equipos (página pública, después de buscar la tarjeta). */
    leer.setEquipos = (equipos, misEquipos, seleccionado) => {
      opc.equipos = equipos || []; opc.misEquipos = misEquipos || [];
      sel.innerHTML = opcionesEquipo(opc, seleccionado || null, '');
      libre.hidden = sel.value !== 'otro';
      if (opc.onEquipo) opc.onEquipo(sel.value);
    };
    /** Muestra a la persona encontrada por su tarjeta (o la limpia con null). */
    leer.setResponsable = t => {
      $('#f-resp-nombre', host).textContent = t ? t.nombre : '';
      $('#f-resp-sub', host).textContent = t ? [t.area, t.puesto].filter(Boolean).join(' · ') : '';
      $('#f-firma-nombre', host).textContent = t ? t.nombre : '';
      const area = $('#f-area', host);
      if (t && t.area && !area.value.trim()) area.value = t.area;
    };
    leer.equipoSeleccionado = () => sel.value;
    return leer;
  }

  window.Mtto = { $, $$, esc, toast, api, ahoraLocal, hoy, aInput, fechaCorta, minutos, duracion, Firma, renderFormato, ESTADOS, PRIORIDADES };
})();
