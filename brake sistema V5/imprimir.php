<?php
/**
 * imprimir.php?id=N[&t=token] — Formato imprimible de la Orden de Mantenimiento Correctivo.
 * Lo abre el personal del panel, o quien reportó usando el enlace con su token.
 * «Guardar en PDF»: en la ventana de impresión elija «Guardar como PDF» / «Microsoft Print to PDF».
 */
declare(strict_types=1);
require_once __DIR__ . '/includes/mtto.php';

$id = (int)($_GET['id'] ?? 0);
$st = db()->prepare('SELECT * FROM ordenes_correctivas WHERE id = ?');
$st->execute([$id]);
$o = $st->fetch();

// ?blanco=1 → formato vacío para llenarlo a mano (solo personal del panel).
if (!empty($_GET['blanco']) && es_personal_mtto()) {
    $o = array_fill_keys(['folio', 'token', 'estado', 'tipo_falla', 'prioridad', 'area', 'reporta_nombre', 'reporta_tarjeta', 'equipo_ident',
        'fecha_paro', 'fecha_ejecucion', 'fecha_entrega', 'reporte', 'descripcion', 'ejecuto_nombre', 'recibio_nombre', 'firma_reporto',
        'firma_ejecuto', 'firma_recibio', 'fecha_firma_reporto', 'fecha_firma_ejecuto', 'fecha_firma_recibio', 'creado'], null);
    $o['id'] = 0; $o['estado'] = $o['prioridad'] = $o['tipo_falla'] = '';
    $o['token'] = 'x';
    $_GET['t'] = 'x';
}

$token = (string)($_GET['t'] ?? '');
$permitido = $o && (es_personal_mtto() || ($token !== '' && hash_equals((string)$o['token'], $token)));
if (!$permitido) {
    http_response_code(404);
    exit('Orden no encontrada.');
}
$o = orden_para_json($o);
$fh = fn(?string $v) => $v ? date('d/m/Y H:i', strtotime($v)) : '';
$fd = fn(?string $v) => $v ? date('d/m/Y', strtotime($v)) : '';
$firma = fn(?string $v) => $v ? '<img src="' . e($v) . '" alt="Firma">' : '';
$logo = 'data:image/png;base64,' . base64_encode((string)file_get_contents(__DIR__ . '/assets/logo/logo-brake-nuevo.png'));
?>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title><?= e($o['folio'] ?: 'Formato') ?> · Orden de mantenimiento correctivo</title>
  <style>
    @page { size: letter landscape; margin: 10mm; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: Arial, Helvetica, sans-serif; color: #000; background: #e9edf3; }
    .barra { display: flex; justify-content: center; gap: .6rem; padding: .8rem; }
    .barra button { font: 600 15px "Bahnschrift", "Segoe UI", Arial; padding: .6rem 1.1rem; border-radius: 6px; border: 1px solid #0b63b6; background: #0b63b6; color: #fff; cursor: pointer; }
    .barra button.sec { background: #fff; color: #0a2a57; border-color: #c9d4e3; }
    .hoja { width: 257mm; margin: 0 auto 2rem; background: #fff; padding: 6mm; box-shadow: 0 4px 20px rgba(0,0,0,.12); }
    table { width: 100%; border-collapse: collapse; table-layout: fixed; }
    td { border: 1px solid #000; padding: 3px 5px; vertical-align: top; font-size: 11px; }
    .gris { background: #d9d9d9; text-align: center; font-size: 12px; }
    .et { display: block; font-size: 10px; text-align: center; }
    .val { display: block; font-size: 12px; min-height: 16px; padding-top: 2px; }
    .centro { text-align: center; }
    .titulo { font-size: 22px; font-weight: bold; text-align: center; vertical-align: middle; }
    .marca { display: flex; align-items: center; gap: 6px; border: 2px solid #000; padding: 2px 6px; width: max-content; }
    .marca img { width: 34px; height: 34px; }
    .marca span { color: #a1101a; font: bold 14px "Times New Roman", serif; }
    .texto { min-height: 70px; white-space: pre-wrap; font-size: 12px; }
    .firma { height: 58px; text-align: center; }
    .firma img { max-height: 48px; max-width: 100%; }
    .nombre-firma { font-size: 11px; text-align: center; }
    .meta { font-size: 10px; color: #333; margin-top: 4px; display: flex; justify-content: space-between; }
    @media print {
      body { background: #fff; }
      .barra { display: none; }
      .hoja { width: auto; margin: 0; padding: 0; box-shadow: none; }
    }
  </style>
</head>
<body>
<div class="barra">
  <button type="button" onclick="window.print()">Imprimir o guardar en PDF</button>
  <button type="button" class="sec" onclick="window.close()">Cerrar</button>
</div>
<div class="hoja">
  <table>
    <colgroup><col style="width:20%"><col style="width:20%"><col style="width:20%"><col style="width:20%"><col style="width:20%"></colgroup>
    <tr>
      <td colspan="2" style="border-bottom:0"><div class="marca"><img src="<?= $logo ?>" alt=""><span>AUTO MANUFACTURAS BRAKE, S.A. DE C.V.</span></div></td>
      <td colspan="2" style="vertical-align:bottom;border-bottom:0">Nombre del Documento</td>
      <td>Folio: <b style="font-size:14px;color:#a1101a"><?= e($o['folio']) ?></b></td>
    </tr>
    <tr><td colspan="5" class="titulo">ORDEN DE MANTENIMIENTO CORRECTIVO</td></tr>
    <tr>
      <td colspan="2"><span class="et">ÁREA / DEPARTAMENTO</span><span class="val centro"><?= e($o['area']) ?></span></td>
      <td colspan="2"><span class="et">RESPONSABLE</span><span class="val centro"><?= e($o['reporta_nombre']) ?><?= $o['reporta_tarjeta'] ? ' (Tarjeta ' . e($o['reporta_tarjeta']) . ')' : '' ?></span></td>
      <td><span class="et">IDENTIFICADOR EQUIPO</span><span class="val centro"><?= e($o['equipo_ident']) ?></span></td>
    </tr>
    <tr>
      <td><span class="et">TIPO DE FALLA</span><span class="val centro"><?= e($o['tipo_texto']) ?></span></td>
      <td><span class="et">PRIORIDAD</span><span class="val centro"><?= e($o['prioridad_texto']) ?></span></td>
      <td colspan="2"><span class="et">ESTADO</span><span class="val centro"><?= e($o['estado_texto']) ?></span></td>
      <td><span class="et">FECHA DE REPORTE</span><span class="val centro"><?= e($fh($o['creado'])) ?></span></td>
    </tr>
    <tr>
      <td><span class="et">FECHA Y HORA DE PARO:</span><span class="val centro"><?= e($fh($o['fecha_paro'])) ?></span></td>
      <td><span class="et">FECHA Y HORA DE EJECUCIÓN:</span><span class="val centro"><?= e($fh($o['fecha_ejecucion'])) ?></span></td>
      <td><span class="et">FECHA Y HORA DE ENTREGA:</span><span class="val centro"><?= e($fh($o['fecha_entrega'])) ?></span></td>
      <td><span class="et">TIEMPO DE MANTENIMIENTO:</span><span class="val centro"><?= e($o['tiempo_mtto']) ?></span></td>
      <td><span class="et">TIEMPO MUERTO:</span><span class="val centro"><?= e($o['tiempo_muerto']) ?></span></td>
    </tr>
    <tr><td colspan="5" class="gris">REPORTE DEL MANTENIMIENTO</td></tr>
    <tr><td colspan="5"><div class="texto"><?= e($o['reporte']) ?></div></td></tr>
    <tr><td colspan="5" class="gris">DESCRIPCIÓN DEL MANTENIMIENTO Y OBSERVACIONES</td></tr>
    <tr><td colspan="5"><div class="texto" style="min-height:100px"><?= e($o['descripcion']) ?></div></td></tr>
    <tr>
      <td colspan="2" class="centro">REPORTÓ NOMBRE Y FIRMA</td>
      <td colspan="2" class="centro">EJECUTÓ MANTENIMIENTO NOMBRE Y FIRMA</td>
      <td class="centro">RECIBIÓ NOMBRE Y FIRMA (LÍDER)</td>
    </tr>
    <tr>
      <td colspan="2"><div class="firma"><?= $firma($o['firma_reporto']) ?></div><div class="nombre-firma"><?= e($o['reporta_nombre']) ?></div></td>
      <td colspan="2"><div class="firma"><?= $firma($o['firma_ejecuto']) ?></div><div class="nombre-firma"><?= e($o['ejecuto_nombre']) ?></div></td>
      <td><div class="firma"><?= $firma($o['firma_recibio']) ?></div><div class="nombre-firma"><?= e($o['recibio_nombre']) ?></div></td>
    </tr>
    <tr>
      <td colspan="2">FECHA: <?= e($fd($o['fecha_firma_reporto'])) ?></td>
      <td colspan="2">FECHA: <?= e($fd($o['fecha_firma_ejecuto'])) ?></td>
      <td>FECHA: <?= e($fd($o['fecha_firma_recibio'])) ?></td>
    </tr>
  </table>
  <div class="meta"><span>Generado por el sistema de mantenimiento</span><span>Impreso el <?= date('d/m/Y H:i') ?></span></div>
</div>
</body>
</html>
