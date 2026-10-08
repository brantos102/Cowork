-- ============================================================================
-- Formato de carga TMS - clientes DEGSO / DPW   (SQL Server)
-- VARIANTE CABECERA: 1 renglon por documento. El detalle de producto va en
-- blanco y VALOR_TOTAL_FACTURA se totaliza por documento con SUM() OVER().
-- ----------------------------------------------------------------------------
-- CAMBIO: el transporte externo SANTIAGO GALEAS debe salir como
-- 'RETIRA CLIENTE' en la columna OPERACION (AH), no como 'DESPACHO'.
--
-- Mismo criterio que en sql/carga_tms_deg_dpw.sql:
--   - la clase de pedido se normaliza UNA vez con CROSS APPLY (VALUES ...)
--   - se reutiliza en T_AUX_1 (columna AM) y en OPERACION (columna AH)
--   - el LIKE '%GALEAS%' tolera variantes de tipeo en la carga manual
--
-- El CROSS APPLY devuelve exactamente 1 fila, por lo que NO altera el
-- SELECT DISTINCT ni la particion de la funcion de ventana.
-- ============================================================================

SELECT
    EMPRESA,
    FECHA_INTERFAZ,
    REMITENTE,
    DIRECCION_RTTE,
    PISO_RTTE,
    DEPTO_RTTE,
    CP_RTTE,
    LOCALIDAD_RTTE,
    PROVINCIA_RTTE,
    DESTINATARIO,
    DIRECCION_DEST,
    PISO_DEST,
    DEPTO_DEST,
    CP_DEST,
    LOCALIDAD_DEST,
    PROVINCIA_DEST,
    NRO_REFERENCIA,
    NULL AS NRO_FACTURA,
    VALOR_TOTAL_FACTURA, -- Total del documento completo
    MONEDA_FACTURA,
    NRO_REMITO,
    DNI,
    TELEFONO_MOVIL,
    Telefono_FIJO,
    Email,
    FECHA_COMPRA,
    CODIGO_PRODUCTO,
    DESCRIPCION,
    CANTIDAD,
    PESO_KG,
    VOLUMEN_M3,
    OBSERVACIONES_INT,
    OBSERVACIONES_DESTINATARIO,
    OPERACION,
    TIPO_SERVICIO,
    TS_AD,
    HF,
    HF_OBS,
    T_AUX_1,
    T_AUX_2,
    F_AUX_1,
    F_AUX_2,
    '' AS NRO_TRACKING_EX,
    '' AS NRO_TRACKING_RE,
    CADENA_CRUCE_TMS,
    documento_id,
    STATUS,
    sucursal_id,
    transporte_id,
    Cantidad_Confirmada
FROM (
    SELECT DISTINCT
        syd.cliente_id AS EMPRESA,
        ROUND(CONVERT (FLOAT, syd_ad.fecha_creacion) + 2,0,9) AS FECHA_INTERFAZ,
        ('FLEXNET ECUADOR - ' + syd.cliente_id) AS REMITENTE,
        'CALLE 28 DE JUNIO S/N Y GARCIA MORENO ENTRADA LLANO GRANDE' AS DIRECCION_RTTE,
        NULL PISO_RTTE,
        NULL AS DEPTO_RTTE,
        'CALDERON (QUI)' AS CP_RTTE,
        'QUITO' AS LOCALIDAD_RTTE,
        'PICHINCHA' AS PROVINCIA_RTTE,
        syd.info_adicional_3 AS DESTINATARIO,
        CASE
            WHEN CP.CLASE_PEDIDO_NORM = 'CONTRAENTREGA' THEN 'COBRAR ($'+ CAST(syd.IMPORTE_FLETE+2.50 AS VARCHAR) + ') DIR. '+SYD.CUSTOMS_1
            ELSE SYD.CUSTOMS_1
        END AS DIRECCION_DEST,
        NULL AS PISO_DEST,
        NULL AS DEPTO_DEST,
        syd.CUSTOMS_2 AS CP_DEST,
        syd.CUSTOMS_2 AS LOCALIDAD_DEST,
        syd.info_adicional_6 AS PROVINCIA_DEST,
        syd.doc_ext AS NRO_REFERENCIA,

        -- Total del documento: suma todas las lineas de detalle antes del DISTINCT
        SUM(ISNULL(syded.CANTIDAD_SOLICITADA, 0) * ISNULL(pr.COSTO, 0)) OVER(PARTITION BY syd.cliente_id, syd.doc_ext) AS VALOR_TOTAL_FACTURA,
        --(ISNULL(syded.CANTIDAD_SOLICITADA, 0) * ISNULL(pr.COSTO, 0)) AS VALOR_TOTAL_FACTURA,

        SYD.IMPORTE_FLETE AS IMPORTEFLETE,
        NULL AS MONEDA_FACTURA,
        NULL AS NRO_REMITO,
        syd.info_adicional_4 AS DNI,
        syd.info_adicional_5 AS TELEFONO_MOVIL,
        '' AS Telefono_FIJO,
        'karine.arteaga@degso.com' AS Email,
        ROUND(CONVERT (FLOAT,syd.FECHA_SOLICITUD_CPTE) + 2, 0,9 ) AS FECHA_COMPRA,
        '' AS CODIGO_PRODUCTO,
        -- syded.PRODUCTO_ID AS CODIGO_PRODUCTO,
        '' AS DESCRIPCION,
        '' AS CANTIDAD,
        '' AS PESO_KG,
        '' AS VOLUMEN_M3,
        --NULL AS VOLUMEN_M3,
        syd.OBSERVACIONES AS OBSERVACIONES_INT,
        '' AS OBSERVACIONES_DESTINATARIO,

        -- ------------------------------------------------------------------
        -- OPERACION (columna AH del formato de carga)
        -- Se agrega SANTIAGO GALEAS: transporte externo que opera como retiro
        -- del cliente, no como despacho propio.
        -- ------------------------------------------------------------------
        CASE
            WHEN CP.CLASE_PEDIDO_NORM IN ('RETIRA CLIENTE',
                                          'RETIRO DE BODEGA',
                                          'CLIENTE RETIRA DE SUS BODEGAS',
                                          'SANTIAGO GALEAS')
                 OR CP.CLASE_PEDIDO_NORM LIKE '%GALEAS%'   -- tolera variantes de tipeo
            THEN 'RETIRA CLIENTE'
            ELSE 'DESPACHO'
        END AS OPERACION,
        -- Variante restringida al cliente DEGSO (hoy GALEAS solo existe ahi):
        -- CASE
        --     WHEN CP.CLASE_PEDIDO_NORM IN ('RETIRA CLIENTE','RETIRO DE BODEGA','CLIENTE RETIRA DE SUS BODEGAS')
        --          OR (syd.cliente_id = 'DEGSO' AND CP.CLASE_PEDIDO_NORM LIKE '%GALEAS%')
        --     THEN 'RETIRA CLIENTE'
        --     ELSE 'DESPACHO'
        -- END AS OPERACION,

        'NORMAL' AS TIPO_SERVICIO,
        NULL AS TS_AD,
        'NO' AS HF,
        NULL AS HF_OBS,
        CP.CLASE_PEDIDO_NORM AS T_AUX_1,   -- columna AM: sigue mostrando SANTIAGO GALEAS
        NULL AS T_AUX_2,
        ROUND(CONVERT (FLOAT,syd.FECHA_SOLICITUD_CPTE) + 2, 0,9 ) AS F_AUX_1,
        NULL AS F_AUX_2,
        (syd.cliente_id + '_' + syd.DOC_EXT) AS CADENA_CRUCE_TMS,
        doc.documento_id,
        doc.STATUS,
        suc.sucursal_id,
        tra.transporte_id,
        ISNULL((SELECT SUM(picking.cant_confirmada) FROM picking WHERE PICKING.DOCUMENTO_ID = doc.documento_id), 0) AS Cantidad_Confirmada
    FROM sys_int_documento syd
    INNER JOIN cliente cl ON syd.cliente_id = cl.cliente_id
    LEFT JOIN sys_int_det_documento syded ON syd.doc_ext = syded.doc_ext AND syd.cliente_id = syded.cliente_id
    LEFT JOIN sys_int_documento_adicional syd_ad ON syd.doc_ext = syd_ad.doc_ext AND syd.cliente_id = syd_ad.cliente_id
    LEFT JOIN documento doc ON syded.documento_id = doc.documento_id
    LEFT JOIN PRODUCTO pr ON syded.PRODUCTO_ID = pr.PRODUCTO_ID AND syd.cliente_id = pr.CLIENTE_ID
    LEFT JOIN sucursal suc ON syd.agente_id = suc.sucursal_id AND syd.cliente_id = suc.cliente_id
    LEFT JOIN transporte tra ON syd.transporte_id = tra.transporte_id
    -- Normaliza la clase de pedido UNA sola vez y la reutiliza en T_AUX_1,
    -- OPERACION y DIRECCION_DEST. Devuelve 1 fila: no afecta al DISTINCT ni
    -- a la particion de la funcion de ventana.
    CROSS APPLY (VALUES (UPPER(LTRIM(RTRIM(syd.CLASE_PEDIDO))))) AS CP(CLASE_PEDIDO_NORM)
    WHERE syd.tipo_documento_id ='E04'
      AND syd_ad.fecha_creacion >= DATEADD(day, -60, GETDATE())
      AND syd.CLIENTE_ID IN ('DEGSO','DPW')
      --AND SYDED.DOC_EXT = 'UIO-SAL-015571'
) TBX;


-- ============================================================================
-- CONTROL 1: que clases de pedido existen y como quedan clasificadas
-- ----------------------------------------------------------------------------
-- SELECT  syd.CLIENTE_ID,
--         UPPER(LTRIM(RTRIM(syd.CLASE_PEDIDO))) AS CLASE_PEDIDO_NORM,
--         COUNT(*) AS documentos,
--         CASE
--             WHEN UPPER(LTRIM(RTRIM(syd.CLASE_PEDIDO))) IN ('RETIRA CLIENTE','RETIRO DE BODEGA','CLIENTE RETIRA DE SUS BODEGAS','SANTIAGO GALEAS')
--                  OR UPPER(LTRIM(RTRIM(syd.CLASE_PEDIDO))) LIKE '%GALEAS%'
--             THEN 'RETIRA CLIENTE' ELSE 'DESPACHO'
--         END AS OPERACION_RESULTANTE
-- FROM    sys_int_documento syd
-- WHERE   syd.tipo_documento_id = 'E04'
--   AND   syd.CLIENTE_ID IN ('DEGSO','DPW')
-- GROUP BY syd.CLIENTE_ID, UPPER(LTRIM(RTRIM(syd.CLASE_PEDIDO)))
-- ORDER BY syd.CLIENTE_ID, documentos DESC;
--
-- ----------------------------------------------------------------------------
-- CONTROL 2: esta consulta deberia dar 1 renglon por documento
-- ----------------------------------------------------------------------------
-- Si algun doc_ext aparece mas de una vez, es porque sus lineas de detalle
-- apuntan a DOCUMENTO_ID distintos (syded.documento_id) y el DISTINCT no las
-- colapsa. No lo cambio porque excede el alcance de este pedido, pero conviene
-- revisarlo: el formato de carga espera una cabecera unica por documento.
--
-- SELECT  syd.CLIENTE_ID, syded.DOC_EXT,
--         COUNT(DISTINCT syded.DOCUMENTO_ID) AS documento_ids_distintos,
--         COUNT(*) AS lineas_detalle
-- FROM    sys_int_documento syd
--         LEFT JOIN sys_int_det_documento syded
--               ON syd.doc_ext = syded.doc_ext AND syd.cliente_id = syded.cliente_id
-- WHERE   syd.tipo_documento_id = 'E04'
--   AND   syd.CLIENTE_ID IN ('DEGSO','DPW')
-- GROUP BY syd.CLIENTE_ID, syded.DOC_EXT
-- HAVING  COUNT(DISTINCT syded.DOCUMENTO_ID) > 1
-- ORDER BY documento_ids_distintos DESC;
-- ============================================================================
