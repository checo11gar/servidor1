<?php
/**
 * config/database.php
 * Conexión PDO a MySQL y constantes generales del sistema.
 * Si cambia la contraseña de MySQL en XAMPP, edítela aquí.
 */
declare(strict_types=1);

// ---- Conexión MySQL (valores por defecto de XAMPP) -------------------
const DB_HOST = 'localhost';
const DB_NAME = 'brake_sistema';
const DB_USER = 'root';
const DB_PASS = '';          // XAMPP trae root sin contraseña por defecto
const DB_CHARSET = 'utf8mb4';

// ---- Rutas -----------------------------------------------------------
define('BASE_PATH', dirname(__DIR__));

const SESSION_IDLE_SECONDS = 7200; // 2 horas sin actividad cierran la sesión

/** Devuelve una conexión PDO única (consultas preparadas, sin emulación). */
function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET;
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
        } catch (PDOException $e) {
            error_log('BRAKE DB: ' . $e->getMessage());
            http_response_code(500);
            exit('No se pudo conectar con la base de datos. Revise config/database.php y que MySQL esté iniciado.');
        }
    }
    return $pdo;
}
