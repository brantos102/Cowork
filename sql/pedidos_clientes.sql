-- ============================================================================
-- Pedidos por cliente - ultimas 2 semanas segun fecha de estado
-- Operacion: idtipo_operacion = 1
-- ----------------------------------------------------------------------------
-- Clientes incluidos:
--   45, 46, 47, 48  clientes originales
--   212             TIGO  (verificado: empresa unica, pedidos idtipo_operacion = 1)
-- ============================================================================

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


-- ----------------------------------------------------------------------------
-- Mantenimiento
-- ----------------------------------------------------------------------------
-- Indice sugerido si pedido es grande (evita full scan del filtro de arriba):
-- CREATE INDEX ix_pedido_tipo_emp_status
--     ON pedido (idtipo_operacion, idempresa, fecha_status);

-- Para sumar un cliente nuevo: buscar su idempresa y agregarlo al IN.
-- SELECT idempresa, codigo_empresa FROM empresa WHERE codigo_empresa LIKE '%XXX%';
