-- ============================================================================
-- [INGRESO_DETALLADO]  -- SQL Server (DEPOT Ecuador Varios)
-- ----------------------------------------------------------------------------
-- Correccion de la duplicacion de filas. Causas detectadas en la version
-- anterior:
--
-- 1) AHG (auditoria TIPO_AUDITORIA_ID='1') devuelve N filas por
--    DOCUMENTO_ID + NRO_LINEA_DOC: una por cada guardado. Al unirla y poner
--    AHG.FECHA_AUDITORIA en el GROUP BY, cada guardado genera una fila de
--    salida identica salvo por la hora. Ademas cada copia arrastra su propia
--    CANTIDAD, por lo que SUM(DD.CANTIDAD) queda MULTIPLICADO.
--
-- 2) El GROUP BY conservaba columnas que ya no se proyectan
--    (SF.DESCRIPCION, ISNULL(SU.NOMBRE,AHI.USUARIO_ID), SU2.NOMBRE,
--    DD.PROP2). Una columna en el GROUP BY separa grupos aunque no se
--    muestre: filas visualmente iguales que en realidad difieren en un campo
--    invisible.
--
-- 3) El INNER JOIN a AHI (TIPO_AUDITORIA_ID='4') era redundante: DD ya esta
--    filtrado por TIPO_AUDITORIA_ID = 4 sobre la MISMA tabla y con la misma
--    clave, asi que USUARIO_ID sale de DD. Encima, sin DISTINCT, multiplicaba
--    de nuevo si habia varias auditorias tipo 4 para la linea.
--
-- Solucion: pre-colapsar la auditoria de guardado a 1 fila por documento con
-- MAX(FECHA_AUDITORIA), y dejar en el GROUP BY unicamente lo proyectado.
-- ============================================================================

WITH FIN_INGRESO AS (
    -- Ultimo guardado por documento: 1 sola fila, no puede multiplicar
    SELECT  DOCUMENTO_ID,
            MAX(FECHA_AUDITORIA) AS FECHA_FIN_INGRESO
    FROM    AUDITORIA_HISTORICOS (NOLOCK)
    WHERE   TIPO_AUDITORIA_ID = '1'
      AND   CANTIDAD > 0
    GROUP BY DOCUMENTO_ID
    -- Variante por LINEA (descomentar y comentar la de arriba si se quiere el
    -- fin de ingreso de cada linea en vez del documento completo):
    -- SELECT DOCUMENTO_ID, NRO_LINEA_DOC, MAX(FECHA_AUDITORIA) AS FECHA_FIN_INGRESO
    -- FROM AUDITORIA_HISTORICOS (NOLOCK)
    -- WHERE TIPO_AUDITORIA_ID = '1' AND CANTIDAD > 0
    -- GROUP BY DOCUMENTO_ID, NRO_LINEA_DOC
)
SELECT
        D.CLIENTE_ID                        AS CLIENTE_ID,
        DATENAME(YEAR,  D.FECHA_ALTA_GTW)   AS AÑO,
        DATENAME(MONTH, D.FECHA_ALTA_GTW)   AS MES,
        DATENAME(DAY,   D.FECHA_ALTA_GTW)   AS DIA,
        D.FECHA_ALTA_GTW                    AS FECHA_INGRESO,
        FI.FECHA_FIN_INGRESO                AS FECHA_FIN_INGRESO,
        D.TIPO_COMPROBANTE_ID               AS TIPO_DE_INGRESO,
        D.OBSERVACIONES                     AS OBSERVACIONES,
        D.ORDEN_DE_COMPRA                   AS ORDEN_COMPRA,
        D.CPTE_PREFIJO                      AS CPTE_PREFIJO,
        D.CPTE_NUMERO                       AS CPTE_NUMERO,
        D.DOCUMENTO_ID                      AS DOCUMENTO_ID,
        S.NOMBRE                            AS ORIGEN,
        DD.PRODUCTO_ID                      AS COD_PRODUCTO,
        P.DESCRIPCION                       AS DESCRIPCION,
        SUM(DD.CANTIDAD)                    AS CANTIDAD_INGRESADA,
        DD.NRO_LOTE                         AS NRO_LOTE,
        DD.FECHA_VENCIMIENTO                AS FECHA_VENCIMIENTO,
        DD.NRO_PARTIDA                      AS PARTIDA,
        DD.PROP3                            AS PROP3,
        (SUM(DD.CANTIDAD) * ISNULL(P.PESO,0)) AS PESO,
        (SUM(DD.CANTIDAD) * (ISNULL(P.ALTO,0) * ISNULL(P.ANCHO,0) * ISNULL(P.LARGO,0)) / 1000000) AS VOLUMEN,
        F.DESCRIPCION                       AS FAMILIA,
        D.NRO_REMITO                        AS NUMERO_REMITO
FROM    VDOCUMENTO D (NOLOCK)
        INNER JOIN AUDITORIA_HISTORICOS DD (NOLOCK)
               ON (D.DOCUMENTO_ID = DD.DOCUMENTO_ID)
        LEFT  JOIN SUCURSAL S (NOLOCK)
               ON (D.CLIENTE_ID = S.CLIENTE_ID AND D.SUCURSAL_ORIGEN = S.SUCURSAL_ID)
        INNER JOIN PRODUCTO P (NOLOCK)
               ON (DD.CLIENTE_ID = P.CLIENTE_ID AND DD.PRODUCTO_ID = P.PRODUCTO_ID)
        LEFT  JOIN FAMILIA_PRODUCTO F (NOLOCK)
               ON (P.FAMILIA_ID = F.FAMILIA_ID)
        LEFT  JOIN FIN_INGRESO FI
               ON (FI.DOCUMENTO_ID = D.DOCUMENTO_ID)
            -- variante por linea: AND FI.NRO_LINEA_DOC = DD.NRO_LINEA_DOC
WHERE   D.CLIENTE_ID        = 'SG'
  AND   D.TIPO_OPERACION_ID = 'ING'
  AND   D.STATUS            = 'D40'
  AND   DD.TIPO_AUDITORIA_ID = 4
  AND   CONVERT(date, D.FECHA_CPTE) > '20240101'
GROUP BY
        D.CLIENTE_ID,           D.FECHA_ALTA_GTW,       FI.FECHA_FIN_INGRESO,
        D.TIPO_COMPROBANTE_ID,  D.OBSERVACIONES,        D.ORDEN_DE_COMPRA,
        D.CPTE_PREFIJO,         D.CPTE_NUMERO,          D.DOCUMENTO_ID,
        S.NOMBRE,               DD.PRODUCTO_ID,         P.DESCRIPCION,
        DD.NRO_LOTE,            DD.FECHA_VENCIMIENTO,   DD.NRO_PARTIDA,
        DD.PROP3,               P.PESO,                 P.ALTO,
        P.ANCHO,                P.LARGO,                F.DESCRIPCION,
        D.NRO_REMITO;


-- ============================================================================
-- DIAGNOSTICO: comprobar que la causa era la auditoria de guardado
-- ----------------------------------------------------------------------------
-- Cada fila devuelta es un documento/linea con varios guardados. El COUNT es
-- exactamente el factor por el que se multiplicaban las filas del reporte.
--
-- SELECT  DOCUMENTO_ID,
--         NRO_LINEA_DOC,
--         COUNT(*)              AS guardados,
--         MIN(FECHA_AUDITORIA)  AS primero,
--         MAX(FECHA_AUDITORIA)  AS ultimo
-- FROM    AUDITORIA_HISTORICOS (NOLOCK)
-- WHERE   TIPO_AUDITORIA_ID = '1' AND CANTIDAD > 0
-- GROUP BY DOCUMENTO_ID, NRO_LINEA_DOC
-- HAVING  COUNT(*) > 1
-- ORDER BY guardados DESC;
--
-- ----------------------------------------------------------------------------
-- VERIFICACION: la cantidad total ya no debe venir inflada
-- ----------------------------------------------------------------------------
-- Comparar contra la fuente cruda, sin ningun join de auditoria:
--
-- SELECT  SUM(DD.CANTIDAD) AS cantidad_real
-- FROM    VDOCUMENTO D (NOLOCK)
--         INNER JOIN AUDITORIA_HISTORICOS DD (NOLOCK) ON D.DOCUMENTO_ID = DD.DOCUMENTO_ID
-- WHERE   D.CLIENTE_ID = 'SG' AND D.TIPO_OPERACION_ID = 'ING'
--   AND   D.STATUS = 'D40' AND DD.TIPO_AUDITORIA_ID = 4
--   AND   CONVERT(date, D.FECHA_CPTE) > '20240101';
--
-- El total del reporte corregido tiene que coincidir con este numero.
-- La version anterior daba mas.
-- ============================================================================
