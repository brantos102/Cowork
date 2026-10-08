-- ============================================================================
-- Formato de carga TMS - clientes DEGSO / DPW   (SQL Server)
-- ----------------------------------------------------------------------------
-- CAMBIO: el transporte externo SANTIAGO GALEAS debe salir como
-- 'RETIRA CLIENTE' en la columna OPERACION (AH), no como 'DESPACHO'.
--
-- Verificado contra el archivo de carga (hoja DEPOT, 2.746 filas):
--   ITSANET          2.499 filas -> DESPACHO        (transporte propio, OK)
--   RETIRA CLIENTE     129 filas -> RETIRA CLIENTE  (OK)
--   SANTIAGO GALEAS    117 filas -> DESPACHO        (INCORRECTO, se corrige)
-- SANTIAGO GALEAS aparece unicamente en el cliente DEGSO.
--
-- COMO SE RESOLVIO
-- El valor que se ve en la columna AM (T_AUX_1) es UPPER(syd.clase_pedido),
-- y la columna AH (OPERACION) se decide con un CASE sobre ese MISMO campo.
-- O sea que las dos columnas ya salen del mismo dato: alcanza con sumar el
-- transporte nuevo a la lista de "retira cliente".
--
-- Para no repetir la normalizacion en los dos lugares se calcula una sola vez
-- con CROSS APPLY (VALUES ...) y se reutiliza. Eso ademas arregla un bug
-- latente: el IN original comparaba contra el campo crudo, asi que un valor
-- cargado en minusculas o con espacios de mas ('retira cliente ') caia en
-- DESPACHO por error.
--
-- El LIKE '%GALEAS%' cubre las variantes de tipeo que se vean en la carga
-- manual (SANTIAGO GALEAS, GALEAS SANTIAGO, TRANSPORTE SANTIAGO GALEAS).
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
    VALOR_TOTAL_FACTURA, -- Reflejara el costo individual de esta linea de producto
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
            WHEN SYD.CLASE_PEDIDO='contraentrega' THEN 'COBRAR ($'+ CAST(syd.IMPORTE_FLETE+2.50 AS VARCHAR) + ') DIR. '+SYD.CUSTOMS_1
            ELSE SYD.CUSTOMS_1
        END AS DIRECCION_DEST,
        NULL AS PISO_DEST,
        NULL AS DEPTO_DEST,
        syd.CUSTOMS_2 AS CP_DEST,
        syd.CUSTOMS_2 AS LOCALIDAD_DEST,
        syd.info_adicional_6 AS PROVINCIA_DEST,
        syd.doc_ext AS NRO_REFERENCIA,

        -- Multiplicacion directa a nivel de fila (sin funcion de ventana)
        (ISNULL(syded.CANTIDAD_SOLICITADA, 0) * ISNULL(pr.COSTO, 0)) AS VALOR_TOTAL_FACTURA,

        SYD.IMPORTE_FLETE AS IMPORTEFLETE,
        NULL AS MONEDA_FACTURA,
        NULL AS NRO_REMITO,
        syd.info_adicional_4 AS DNI,
        syd.info_adicional_5 AS TELEFONO_MOVIL,
        '' AS Telefono_FIJO,
        'karine.arteaga@degso.com' AS Email,
        ROUND(CONVERT (FLOAT,syd.FECHA_SOLICITUD_CPTE) + 2, 0,9 ) AS FECHA_COMPRA,
        syded.PRODUCTO_ID AS CODIGO_PRODUCTO,
        PR.DESCRIPCION AS DESCRIPCION,
        syded.CANTIDAD_SOLICITADA AS CANTIDAD,
        pr.PESO AS PESO_KG,
        ((ISNULL(pr.LARGO, 0) * ISNULL(pr.ANCHO, 0) * ISNULL(pr.ALTO, 0)) / 1000000.0) * ISNULL(syded.CANTIDAD_SOLICITADA, 0) AS VOLUMEN_M3,
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
        -- Variante restringida al cliente DEGSO (hoy GALEAS solo existe ahi).
        -- Usar esta si manana DPW incorpora un transporte con nombre parecido
        -- que NO deba tratarse como retiro:
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
    -- Normaliza la clase de pedido UNA sola vez y la reutiliza en T_AUX_1 y OPERACION
    CROSS APPLY (VALUES (UPPER(LTRIM(RTRIM(syd.CLASE_PEDIDO))))) AS CP(CLASE_PEDIDO_NORM)
    WHERE syd.tipo_documento_id ='E04'
      AND syd_ad.fecha_creacion >= DATEADD(day, -60, GETDATE())
      AND syd.CLIENTE_ID IN ('DEGSO','DPW')
      -- AND SYDED.DOC_EXT = 'UIO-SAL-016523'
) TBX;


-- ============================================================================
-- CONTROL: que clases de pedido existen y como quedan clasificadas
-- ----------------------------------------------------------------------------
-- Correr despues del cambio. Toda clase nueva que aparezca aca hay que
-- decidir si va como DESPACHO o como RETIRA CLIENTE.
--
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
-- ============================================================================
