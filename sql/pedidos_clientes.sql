-- ============================================================================
-- Pedidos por cliente (ultimas 2 semanas por fecha de estado)
-- Operacion: idtipo_operacion = 1
-- ----------------------------------------------------------------------------
-- Historial:
--   * Version original: lista fija de idempresa IN (45,46,47,48).
--   * Se agrega el cliente TIGO y se elimina la dependencia de IDs hardcodeados.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0) PASO PREVIO: averiguar el/los idempresa de TIGO y confirmar los actuales.
--    TIGO suele tener mas de una empresa dada de alta (por unidad/pais), asi
--    que conviene verificar antes de fijar la lista.
-- ----------------------------------------------------------------------------
-- SHOW COLUMNS FROM empresa;   -- para ver que columnas descriptivas existen

SELECT idempresa,
       codigo_empresa
FROM empresa
WHERE idempresa IN (45, 46, 47, 48)
   OR codigo_empresa LIKE '%TIGO%'
ORDER BY codigo_empresa;


-- ----------------------------------------------------------------------------
-- 1) VERSION RECOMENDADA: se filtra por codigo_empresa, no por ID.
--    Agregar un cliente nuevo = agregar su codigo a la lista IN, sin tener que
--    buscar IDs internos ni tocar la logica.
--    >>> Reemplazar 'COD45'..'COD48' por los codigos reales del paso 0. <<<
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
  AND em.codigo_empresa IN ('COD45', 'COD48', 'COD46', 'COD47', 'TIGO')
  AND p.fecha_status >= DATE_SUB(CURDATE(), INTERVAL 2 WEEK)
  AND p.fecha_status <  CURDATE() + INTERVAL 1 DAY   -- descarta fechas futuras/basura
ORDER BY em.codigo_empresa,
         p.fecha_status DESC;


-- ----------------------------------------------------------------------------
-- 2) VERSION MINIMA: si preferis no tocar el filtro actual, solo sumar el ID
--    de TIGO (reemplazar 99 por el idempresa real del paso 0).
-- ----------------------------------------------------------------------------
-- SELECT ... (mismo SELECT que arriba)
-- WHERE p.idtipo_operacion = 1
--   AND p.idempresa IN (45, 46, 47, 48, 99)
--   AND p.fecha_status >= DATE_SUB(CURDATE(), INTERVAL 2 WEEK);


-- ----------------------------------------------------------------------------
-- 3) VERSION MIXTA: mantiene los IDs actuales y suma TIGO por prefijo de codigo
--    (util si TIGO tiene varias empresas: TIGO_PY, TIGO_BO, etc.).
-- ----------------------------------------------------------------------------
-- WHERE p.idtipo_operacion = 1
--   AND ( p.idempresa IN (45, 46, 47, 48)
--         OR em.codigo_empresa LIKE 'TIGO%' )       -- LIKE con prefijo usa indice
--   AND p.fecha_status >= DATE_SUB(CURDATE(), INTERVAL 2 WEEK);


-- ----------------------------------------------------------------------------
-- 4) INDICE SUGERIDO para que el filtro no haga full scan de pedido.
-- ----------------------------------------------------------------------------
-- CREATE INDEX ix_pedido_tipo_emp_status
--     ON pedido (idtipo_operacion, idempresa, fecha_status);
