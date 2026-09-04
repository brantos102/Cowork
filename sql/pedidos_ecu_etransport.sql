-- ============================================================================
-- ECU e-Transport - Pedidos consolidados (anio actual +/- 1)
-- ----------------------------------------------------------------------------
-- Version con las columnas nuevas solicitadas:
--   * Transporte        -> transporte.razon_social
--   * Placa             -> vehiculo.patente  (verificado en information_schema)
--   * Tipo_Vehiculo     -> tipo_vehiculo.descripcion
--   * Observaciones     -> evento_pedido.observaciones (ultima no vacia)
--   * Zona (urb/rural)  -> pendiente de confirmar tabla (ver bloque ZONA abajo)
--
-- Cadena de enlace (verificada contra information_schema del schema etransport):
--   pedido.ultima_idcarta_porte -> carta_porte
--   carta_porte.idvehiculo      -> vehiculo.patente          (Placa)
--   carta_porte.idtransporte    -> transporte.razon_social   (Transporte)
--   vehiculo.idtipo_vehiculo    -> tipo_vehiculo.descripcion (Tipo_Vehiculo)
--   evento_pedido.idpedido      -> observaciones (ultimo evento con texto)
--
-- OJO: vehiculo NO tiene idtransporte; el transportista cuelga de la carta
-- de porte. carta_porte tambien tiene su propia columna observaciones.
--
-- Todos los joins nuevos son 1:1 (o 1 fila por pedido en el caso de las
-- observaciones), por lo tanto NO multiplican filas del resultado original.
-- ============================================================================

-- Si el cliente SQL no tiene schema activo (error 1046 "No database selected"),
-- descomentar la linea siguiente o seleccionar etransport en el arbol de bases.
-- USE etransport;

WITH filtered_pedidos AS (
    -- 1. Pre-filtrado SARGable de pedidos por rango de fecha deseado
    SELECT
        vpt.idpedido,
        vpt.idempresa,
        vpt.idtipo_operacion,
        vpt.idtipo_servicio,
        vpt.idtipo_servicio_administrativo,
        vpt.varchar_aux1,
        vpt.fecha_aux1,
        vpt.varchar_aux2,
        vpt.fecha_aux2,
        vpt.idreferencia,
        vpt.nro_remito,
        vpt.nombre,
        vpt.nombre_origen,
        vpt.volumen_total_m3,
        vpt.valor_factura,
        vpt.ultima_idcarta_porte,
        vpt.fecha_interfaz,
        vpt.idcodigo_postal,
        vpt.idlocalidad,
        vpt.idprovincia,
        vpt.idcodigo_postal_origen,
        vpt.idlocalidad_origen,
        vpt.idprovincia_origen,
        vpt.idstatus,
        vpt.fecha_status,
        vpt.peso_total_kg,
        vpt.cantidad_bultos,
        vpt.idexpreso
    FROM view_pedidos_total vpt
    WHERE vpt.fecha_interfaz >= MAKEDATE(YEAR(CURRENT_DATE()) - 1, 1)
      AND vpt.fecha_interfaz <  MAKEDATE(YEAR(CURRENT_DATE()) + 1, 1)
),
consolidated_events AS (
    -- 2. Consolidacion limitada estricta a los pedidos pre-filtrados y eventos requeridos
    SELECT
        e.idpedido,
        ev.codigo_evento,
        CAST(e.fecha_evento AS DATE) AS fecha_evento_clean,
        e.idevento_pedido
    FROM (
        SELECT idpedido, idevento, fecha_evento, idevento_pedido
        FROM view_eventos_pedidos
        WHERE idpedido IN (SELECT idpedido FROM filtered_pedidos)

        UNION ALL

        SELECT idpedido, idevento, fecha_evento, idevento_pedido
        FROM historico_evento_pedido
        WHERE idpedido IN (SELECT idpedido FROM filtered_pedidos)
    ) e
    INNER JOIN evento ev
        ON e.idevento = ev.idevento
    WHERE ev.codigo_evento IN (
        'PEDIDO_ENTREGADO',
        'HABILITADO_RUTEO',
        'FECHA_ESTIMADA_ENTREGA',
        'CARTA_PORTE_CREADA_RETIRO'
    )
),
ranked_events AS (
    -- 3. Particionado y numeracion analitica sobre el dataset reducido
    SELECT
        ce.idpedido,
        ce.codigo_evento,
        ce.fecha_evento_clean,
        ROW_NUMBER() OVER(
            PARTITION BY ce.idpedido, ce.codigo_evento
            ORDER BY ce.idevento_pedido DESC
        ) AS ranking
    FROM consolidated_events ce
),
pivoted_events AS (
    -- 4. Agregacion condicional del ultimo evento registrado (ranking = 1)
    SELECT
        idpedido,
        MAX(CASE WHEN codigo_evento = 'PEDIDO_ENTREGADO'          THEN fecha_evento_clean END) AS Fecha_Entregado,
        MAX(CASE WHEN codigo_evento = 'FECHA_ESTIMADA_ENTREGA'    THEN fecha_evento_clean END) AS Fecha_Estimada_Entrega,
        MAX(CASE WHEN codigo_evento = 'HABILITADO_RUTEO'          THEN fecha_evento_clean END) AS Fecha_Con_Stock,
        MAX(CASE WHEN codigo_evento = 'CARTA_PORTE_CREADA_RETIRO' THEN fecha_evento_clean END) AS Fecha_Carta_Porte_R
    FROM ranked_events
    WHERE ranking = 1
    GROUP BY idpedido
),
ultima_observacion AS (
    -- 4.b NUEVO: ultima observacion cargada en evento_pedido para cada pedido.
    --     Se ignoran las vacias para no "pisar" un comentario util con un NULL.
    --     Queda 1 sola fila por idpedido => el LEFT JOIN final no duplica filas.
    SELECT
        o.idpedido,
        o.observaciones
    FROM (
        SELECT
            ep.idpedido,
            ep.observaciones,
            ROW_NUMBER() OVER(
                PARTITION BY ep.idpedido
                ORDER BY ep.idevento_pedido DESC
            ) AS rn
        FROM evento_pedido ep
        WHERE ep.idpedido IN (SELECT idpedido FROM filtered_pedidos)
          AND ep.observaciones IS NOT NULL
          AND TRIM(ep.observaciones) <> ''
    ) o
    WHERE o.rn = 1
    -- ALTERNATIVA: si en vez de la ultima observacion se quiere el historial
    -- completo concatenado (util para incidencias tipo Tramaco), reemplazar
    -- todo el CTE por:
    --
    -- SELECT ep.idpedido,
    --        GROUP_CONCAT(ep.observaciones
    --                     ORDER BY ep.idevento_pedido DESC
    --                     SEPARATOR ' | ') AS observaciones
    -- FROM evento_pedido ep
    -- WHERE ep.idpedido IN (SELECT idpedido FROM filtered_pedidos)
    --   AND ep.observaciones IS NOT NULL AND TRIM(ep.observaciones) <> ''
    -- GROUP BY ep.idpedido
    -- (ojo: GROUP_CONCAT trunca en group_concat_max_len, por defecto 1024 bytes)
)
-- 5. Proyeccion final con uniones dimensionales
SELECT
    em.codigo_empresa,
    oper.descripcion AS Tipo_Operacion,
    serv.descripcion AS Tipo_Servicio,
    tsa.descripcion  AS Tipo_Serv_Administrativo,
    fp.varchar_aux1,
    fp.fecha_aux1,
    fp.varchar_aux2,
    fp.fecha_aux2,
    fp.idpedido,
    fp.idreferencia,
    fp.nro_remito,
    fp.nombre,
    fp.nombre_origen,
    fp.volumen_total_m3,
    fp.valor_factura,
    fp.ultima_idcarta_porte AS Carta_Porte,
    fp.fecha_interfaz,
    fp.idcodigo_postal AS ParroquiaDestino,
    lo.descripcion     AS LocalidadDestino,
    pr.descripcion     AS ProvinciaDestino,
    cpl.idcodigo_postal AS ParroquiaOrigen,
    loc.descripcion     AS LocalidadOrigen,
    pro.descripcion     AS ProvinciaOrigen,
    fp.idstatus,
    CASE
        WHEN fp.idstatus = 'CANCELADO' THEN 'CANCELADO'
        WHEN fp.idstatus IN ('DEVOLUCION_EN_PROCESO', 'DEVUELTO') THEN 'DEVUELTO'
        WHEN fp.idstatus IN ('ENTREGADO', 'RENDIDO', 'RETIRO_X_CLIENTE') THEN 'ENTREGADO'
        WHEN fp.idstatus IN ('RETIRO_NO_REALIZADO', 'STAND BY', 'INCIDENCIA', 'RETIRO_PROVEEDOR_NO_REALIZADO') THEN 'INCIDENCIA'
        WHEN fp.idstatus IN ('RETIRADO', 'DEVUELTO_AL_CLIENTE', 'RETIRADO_PROVEEDOR') THEN 'RETIRADO'
        WHEN fp.idstatus IN ('FECHA_ESTIMADA_ENTREGA', 'EN_PROCESO', 'SIN STOCK') THEN 'EN_PROCESO'
        WHEN fp.idstatus IN ('EN_CARTA_PORTE_RETIRO', 'EN_TRANSITO', 'COORDINADO', 'RE-COORDINADO', 'MOVIMIENTO_ID', 'ARRIBADO SUCURSAL', 'RETIRO_A_COORDINAR', 'CARTA_PORTE_CREADA_RETIRO', 'CARTA_PORTE_CREADA', 'HABILITADO RUTEO', 'RETIRO_COORDINADO') THEN 'TRANSITO'
        ELSE 'NO_HOMOLOGADO'
    END AS ESTADO,
    fp.fecha_status,
    fp.peso_total_kg,
    fp.cantidad_bultos,
    evt.Fecha_Entregado,
    evt.Fecha_Con_Stock,
    evt.Fecha_Estimada_Entrega,
    evt.Fecha_Carta_Porte_R,
    ex.razon_social AS Expreso,
    -- ---------------- COLUMNAS NUEVAS ----------------
    tr.razon_social   AS Transporte,
    veh.patente       AS Placa,
    tv.descripcion    AS Tipo_Vehiculo,
    obs.observaciones AS Observaciones,
    -- cp.observaciones AS Observaciones_Carta_Porte,  -- opcional: obs. del despacho
    -- Zona: descomentar la linea que corresponda una vez identificada la tabla
    -- (ver bloque "DESCUBRIMIENTO DE ZONA" al final del archivo).
    CAST(NULL AS CHAR) AS Zona,
    -- z.descripcion   AS Zona,          -- opcion A: tabla zona via codigo_postal
    -- cpd.tipo_zona   AS Zona,          -- opcion B: columna dentro de codigo_postal
    -- -------------------------------------------------
    'ecu_etransport'  AS Source,
    'Ecuador'         AS country,
    CURRENT_TIMESTAMP AS DataDate
FROM filtered_pedidos fp
LEFT JOIN empresa                        em   ON fp.idempresa                      = em.idempresa
LEFT JOIN tipo_operacion                 oper ON fp.idtipo_operacion               = oper.idtipo_operacion
LEFT JOIN tipo_servicio                  serv ON fp.idtipo_servicio                = serv.idtipo_servicio
LEFT JOIN codigo_postal                  cpl  ON fp.idcodigo_postal_origen         = cpl.idcodigo_postal
LEFT JOIN localidad                      loc  ON fp.idlocalidad_origen             = loc.idlocalidad
LEFT JOIN provincia                      pro  ON fp.idprovincia_origen             = pro.idprovincia
LEFT JOIN localidad                      lo   ON fp.idlocalidad                    = lo.idlocalidad
LEFT JOIN provincia                      pr   ON fp.idprovincia                    = pr.idprovincia
LEFT JOIN expreso                        ex   ON fp.idexpreso                      = ex.idexpreso
LEFT JOIN pivoted_events                 evt  ON fp.idpedido                       = evt.idpedido
LEFT JOIN tipo_servicio_administrativo   tsa  ON tsa.idtipo_servicio_administrativo = fp.idtipo_servicio_administrativo
-- ---------------- JOINS NUEVOS (todos 1:1, no multiplican filas) ----------------
-- Puerta de entrada al vehiculo: la ultima carta de porte del pedido
LEFT JOIN carta_porte   cp   ON cp.idcarta_porte    = fp.ultima_idcarta_porte
LEFT JOIN vehiculo      veh  ON veh.idvehiculo      = cp.idvehiculo
LEFT JOIN transporte    tr   ON tr.idtransporte     = cp.idtransporte
LEFT JOIN tipo_vehiculo tv   ON tv.idtipo_vehiculo  = veh.idtipo_vehiculo
LEFT JOIN ultima_observacion obs ON obs.idpedido    = fp.idpedido
-- Zona (descomentar junto con la columna de arriba):
-- LEFT JOIN codigo_postal cpd ON cpd.idcodigo_postal = fp.idcodigo_postal
-- LEFT JOIN zona          z   ON z.idzona            = cpd.idzona
;


-- ============================================================================
-- DESCUBRIMIENTO DE ZONA (urbana / rural)  -- ejecutar una sola vez
-- ----------------------------------------------------------------------------
-- 1) Buscar tablas cuyo nombre contenga "zona":
-- SHOW TABLES LIKE '%zona%';
--
-- 2) Buscar cualquier columna que hable de zona / urbano / rural:
-- SELECT table_name, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = DATABASE()
--   AND (column_name LIKE '%zona%'
--        OR column_name LIKE '%urban%'
--        OR column_name LIKE '%rural%')
-- ORDER BY table_name;
--
-- 3) Los candidatos mas probables son codigo_postal / localidad / parroquia:
-- SHOW COLUMNS FROM codigo_postal;
-- SHOW COLUMNS FROM localidad;
--
-- 4) Ver los valores reales para confirmar que son URBANA/RURAL:
-- SELECT DISTINCT <columna_zona> FROM <tabla_zona> LIMIT 20;
--
-- Con eso se completa el join y se descomenta la columna Zona.
-- ============================================================================

-- ============================================================================
-- VERIFICACION DE LOS JOINS NUEVOS (opcional, antes de pasar a produccion)
-- ----------------------------------------------------------------------------
-- Confirmar los nombres reales de las FKs:
-- SHOW COLUMNS FROM carta_porte   LIKE '%id%';
-- SHOW COLUMNS FROM vehiculo;
-- SHOW COLUMNS FROM tipo_vehiculo;
-- SHOW COLUMNS FROM transporte;
-- SHOW COLUMNS FROM evento_pedido LIKE '%observ%';
--
-- Confirmar que ninguna tabla nueva duplica pedidos (todas deben dar 1):
-- SELECT MAX(c) FROM (SELECT idcarta_porte, COUNT(*) c FROM carta_porte   GROUP BY idcarta_porte) t;
-- SELECT MAX(c) FROM (SELECT idvehiculo,    COUNT(*) c FROM vehiculo      GROUP BY idvehiculo)    t;
-- SELECT MAX(c) FROM (SELECT idtransporte,  COUNT(*) c FROM transporte    GROUP BY idtransporte)  t;
--
-- Indices sugeridos para que los joins nuevos no cuesten:
-- CREATE INDEX ix_evento_pedido_pedido ON evento_pedido (idpedido, idevento_pedido);
-- (carta_porte.idcarta_porte, vehiculo.idvehiculo, transporte.idtransporte y
--  tipo_vehiculo.idtipo_vehiculo deberian ser PK; si no lo son, indexarlas.)
-- ============================================================================
