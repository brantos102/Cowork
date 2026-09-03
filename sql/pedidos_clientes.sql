-- ============================================================================
-- Pedidos por cliente (ultimas 2 semanas por fecha de estado)
-- Operacion: idtipo_operacion = 1
-- ----------------------------------------------------------------------------
-- Clientes incluidos:
--   45, 46, 47, 48  (clientes originales)
--   212             (TIGO)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- CONSULTA PRINCIPAL
-- ----------------------------------------------------------------------------
SELECT
    CONCAT_WS('_', em.codigo_empresa, p.idreferencia)  AS Cadena,
    DATE(p.fecha_alta)                                 AS Fecha_Alta,
    em.codigo_empresa                                  AS Cliente,
    p.idpedido                                         AS idpedido,
    p.idreferencia                                     AS Nro_Referencia,
    p.idstatus                                         AS Estado,
    DATE(p.fecha_status)                               AS Fecha_Estado
FROM pedido p
JOIN empresa em
  ON em.idempresa = p.idempresa
WHERE p.idtipo_operacion = 1
  AND p.idempresa IN (45, 46, 47, 48, 212)          -- 212 = TIGO
  AND p.fecha_status >= DATE_SUB(CURDATE(), INTERVAL 2 WEEK)
  AND p.fecha_status <  CURDATE() + INTERVAL 1 DAY  -- descarta fechas futuras/basura
ORDER BY em.codigo_empresa,
         p.fecha_status DESC;


-- ============================================================================
-- CHEQUEOS (correr solo si TIGO no aparece o aparece incompleto)
-- ============================================================================

-- A) Confirmar el codigo de la empresa 212 y ver si TIGO tiene mas de una
--    empresa dada de alta (TIGO_PY, TIGO_BO, etc.). Si devuelve varias filas,
--    hay que sumar esos idempresa a la lista IN de arriba.
-- SELECT idempresa, codigo_empresa
-- FROM empresa
-- WHERE idempresa = 212
--    OR codigo_empresa LIKE '%TIGO%'
-- ORDER BY codigo_empresa;

-- B) Si la consulta principal no trae nada de TIGO: verificar que sus pedidos
--    sean realmente idtipo_operacion = 1 y que tengan movimiento reciente.
-- SELECT p.idtipo_operacion,
--        COUNT(*)              AS pedidos,
--        MAX(p.fecha_status)   AS ultimo_estado
-- FROM pedido p
-- WHERE p.idempresa = 212
-- GROUP BY p.idtipo_operacion;


-- ============================================================================
-- VARIANTES / MANTENIMIENTO
-- ============================================================================

-- Variante por codigo de empresa (no depende de IDs internos; agregar un
-- cliente nuevo = agregar su codigo). Reemplazar los COD4x por los reales.
-- WHERE p.idtipo_operacion = 1
--   AND em.codigo_empresa IN ('COD45','COD46','COD47','COD48','TIGO')
--   AND p.fecha_status >= DATE_SUB(CURDATE(), INTERVAL 2 WEEK);

-- Variante mixta: IDs actuales + todas las empresas de TIGO por prefijo.
-- WHERE p.idtipo_operacion = 1
--   AND ( p.idempresa IN (45, 46, 47, 48)
--         OR em.codigo_empresa LIKE 'TIGO%' )   -- LIKE con prefijo usa indice
--   AND p.fecha_status >= DATE_SUB(CURDATE(), INTERVAL 2 WEEK);

-- Indice sugerido para evitar full scan de pedido.
-- CREATE INDEX ix_pedido_tipo_emp_status
--     ON pedido (idtipo_operacion, idempresa, fecha_status);
