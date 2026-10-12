-- ============================================================================
-- HYCITE2 - Picking / empaquetado desde el viernes anterior   (SQL Server)
-- ----------------------------------------------------------------------------
-- CAMBIO: la ventana pasa de "solo hoy" a "desde el viernes anterior 00:00
-- hasta el final del dia de hoy". El borde superior no se toca: sigue
-- excluyendo fechas futuras.
--
-- El viernes se calcula con DATEDIFF(day, 0, fecha) % 7 (0 = lunes, porque el
-- dia 0 de SQL Server fue lunes). No depende de SET DATEFIRST ni del idioma
-- de la sesion, a diferencia de DATEPART(weekday).
-- ============================================================================

DECLARE @DESDE datetime =
    CAST(
        DATEADD(day,
                -(( DATEDIFF(day, 0, GETDATE()) + 3) % 7),
                CAST(GETDATE() AS date)
        ) AS datetime);

DECLARE @HASTA datetime = DATEADD(DAY, 1, CAST(GETDATE() AS DATE));

-- VARIANTE FECHA FIJA: para una corrida puntual desde un viernes concreto,
-- reemplazar la asignacion de @DESDE por esta linea:
-- DECLARE @DESDE datetime = '20261009';   -- viernes 09/10/2026 00:00

-- Control previo:
-- SELECT @DESDE AS desde, DATENAME(weekday, @DESDE) AS dia_semana, @HASTA AS hasta;


SELECT DISTINCT
    CAST(syd_AD.FECHA_CREACION AS DATE) AS FECHA_ALTA,
    DOC.STATUS,
    CAST(SYD.DOC_EXT AS VARCHAR(50)) AS DOC_EXT,
    p_aux.PRODUCTO_ID,
    ISNULL(p_aux.qty_proc, 0) AS Cantidad_Procesada,
    ISNULL(p_aux.qty_conf, 0) AS Cantidad_Confirmada,
    ISNULL(p_aux.NRO_UC,
          (SELECT CASE WHEN COUNT(DISTINCT V1.NRO_CONTENEDORA_EMPAQUE) = 1
                       THEN MIN(CAST(V1.NRO_CONTENEDORA_EMPAQUE AS VARCHAR(50))) END
             FROM VIEW_TIEMPO_EMPAQUETADO V1 (NOLOCK)
            WHERE V1.PEDIDO = SYD.DOC_EXT
              AND V1.CLIENTE_ID = SYD.CLIENTE_ID
              AND V1.NRO_CONTENEDORA_EMPAQUE IS NOT NULL)) AS NRO_CONTENEDORA_EMPAQUE
FROM SYS_INT_DOCUMENTO syd (NOLOCK)
LEFT JOIN SYS_INT_DET_DOCUMENTO syded (NOLOCK)
    ON (syd.doc_ext = syded.doc_ext AND syd.cliente_id = syded.cliente_id)
LEFT JOIN SYS_INT_DOCUMENTO_ADICIONAL syd_ad (NOLOCK)
    ON (syd.doc_ext = syd_ad.doc_ext AND syd.cliente_id = syd_ad.cliente_id)
LEFT JOIN TIPO_COMPROBANTE tc (NOLOCK)
    ON (tc.TIPO_COMPROBANTE_ID = syd.TIPO_DOCUMENTO_ID)
LEFT JOIN DOCUMENTO doc (NOLOCK)
    ON (doc.DOCUMENTO_ID = syded.DOCUMENTO_ID)
LEFT JOIN (
    SELECT
        p.DOCUMENTO_ID,
        p.PRODUCTO_ID,
        CAST(p.NRO_UCEMPAQUETADO AS VARCHAR(50)) AS NRO_UC,
        SUM(p.CANTIDAD) AS qty_proc,
        SUM(ISNULL(p.CANT_CONFIRMADA, 0)) AS qty_conf
    FROM picking p (NOLOCK)
    GROUP BY
        p.DOCUMENTO_ID,
        p.PRODUCTO_ID,
        CAST(p.NRO_UCEMPAQUETADO AS VARCHAR(50))
) p_aux ON (p_aux.DOCUMENTO_ID = doc.DOCUMENTO_ID)
WHERE (UPPER(tc.TIPO_OPERACION_ID) = 'EGR' OR UPPER(doc.TIPO_OPERACION_ID) = 'EGR')
  AND SYD.cliente_id IN ('HYCITE2')
  AND syd_AD.FECHA_CREACION >= @DESDE
  AND syd_AD.FECHA_CREACION <  @HASTA;


-- ============================================================================
-- CONTROL: documentos por dia dentro de la ventana
-- ----------------------------------------------------------------------------
-- SELECT  CAST(syd_ad.FECHA_CREACION AS date)            AS dia,
--         DATENAME(weekday, syd_ad.FECHA_CREACION)       AS dia_semana,
--         COUNT(DISTINCT syd.DOC_EXT)                    AS documentos
-- FROM    SYS_INT_DOCUMENTO syd (NOLOCK)
--         LEFT JOIN SYS_INT_DOCUMENTO_ADICIONAL syd_ad (NOLOCK)
--               ON syd.doc_ext = syd_ad.doc_ext AND syd.cliente_id = syd_ad.cliente_id
-- WHERE   syd.cliente_id = 'HYCITE2'
--   AND   syd_ad.FECHA_CREACION >= @DESDE
--   AND   syd_ad.FECHA_CREACION <  @HASTA
-- GROUP BY CAST(syd_ad.FECHA_CREACION AS date), DATENAME(weekday, syd_ad.FECHA_CREACION)
-- ORDER BY dia;
--
-- ----------------------------------------------------------------------------
-- NOTA DE RENDIMIENTO (no se modifico, excede el alcance del pedido)
-- ----------------------------------------------------------------------------
-- p_aux se une SOLO por DOCUMENTO_ID, pero esta agrupado por DOCUMENTO_ID +
-- PRODUCTO_ID + NRO_UC. Cada linea de syded se cruza entonces con TODOS los
-- productos del picking de ese documento, y recien el SELECT DISTINCT colapsa
-- el resultado. Con la ventana de un dia el costo pasaba desapercibido; al
-- abrirla a varios dias ese producto cartesiano crece bastante.
--
-- Si la intencion es ver el picking de los productos del detalle, la union
-- correcta seria agregando: AND p_aux.PRODUCTO_ID = syded.PRODUCTO_ID
-- (ojo: eso CAMBIA el resultado, deja fuera productos pickeados que no esten
-- en el detalle, asi que conviene comparar los conteos antes de aplicarlo).
--
-- Tambien la subconsulta correlacionada de NRO_CONTENEDORA_EMPAQUE se evalua
-- una vez por fila: a mas dias, mas ejecuciones.
-- ============================================================================
