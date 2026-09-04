-- ============================================================================
-- Validacion de un pedido puntual contra las columnas nuevas
-- ----------------------------------------------------------------------------
-- Uso: cambiar el valor de @pedido y ejecutar bloque por bloque.
-- ============================================================================

USE etransport;

SET @pedido := 1141775;


-- ----------------------------------------------------------------------------
-- BLOQUE 1. ¿El pedido entra en el rango de fechas de la consulta?
-- ----------------------------------------------------------------------------
-- Si devuelve 0 filas, el pedido queda fuera del filtro de fecha_interfaz y
-- por eso no aparece en el reporte: para la prueba hay que comentar las dos
-- lineas del WHERE de filtered_pedidos.
SELECT
    vpt.idpedido,
    vpt.fecha_interfaz,
    vpt.idstatus,
    vpt.ultima_idcarta_porte,
    vpt.idcodigo_postal AS cp_destino,
    MAKEDATE(YEAR(CURRENT_DATE()) - 1, 1) AS rango_desde,
    MAKEDATE(YEAR(CURRENT_DATE()) + 1, 1) AS rango_hasta,
    CASE
        WHEN vpt.fecha_interfaz >= MAKEDATE(YEAR(CURRENT_DATE()) - 1, 1)
         AND vpt.fecha_interfaz <  MAKEDATE(YEAR(CURRENT_DATE()) + 1, 1)
        THEN 'ENTRA EN EL REPORTE'
        ELSE 'FUERA DE RANGO'
    END AS diagnostico
FROM view_pedidos_total vpt
WHERE vpt.idpedido = @pedido;


-- ----------------------------------------------------------------------------
-- BLOQUE 2. Fuente cruda de Transporte / Placa / Tipo_Vehiculo / Zona
-- ----------------------------------------------------------------------------
-- Es lo que la consulta grande deberia devolver en esas columnas.
SELECT
    vpt.idpedido,
    vpt.ultima_idcarta_porte,
    cp.idvehiculo,
    cp.idtransporte,
    veh.patente     AS Placa,
    tr.razon_social AS Transporte,
    tv.descripcion  AS Tipo_Vehiculo,
    cpd.idcodigo_postal,
    cpd.zona        AS zona_cruda,
    CASE
        WHEN cpd.zona IS NULL OR TRIM(cpd.zona) = '' THEN NULL
        WHEN UPPER(TRIM(cpd.zona)) LIKE '%RURAL%'    THEN 'RURAL'
        WHEN UPPER(TRIM(cpd.zona)) LIKE '%URBAN%'    THEN 'URBANO'
        ELSE NULL
    END             AS Zona_Normalizada,
    cp.observaciones AS obs_carta_porte
FROM view_pedidos_total vpt
LEFT JOIN carta_porte   cp  ON cp.idcarta_porte    = vpt.ultima_idcarta_porte
LEFT JOIN vehiculo      veh ON veh.idvehiculo      = cp.idvehiculo
LEFT JOIN transporte    tr  ON tr.idtransporte     = cp.idtransporte
LEFT JOIN tipo_vehiculo tv  ON tv.idtipo_vehiculo  = veh.idtipo_vehiculo
LEFT JOIN codigo_postal cpd ON cpd.idcodigo_postal = vpt.idcodigo_postal
WHERE vpt.idpedido = @pedido;


-- ----------------------------------------------------------------------------
-- BLOQUE 3. Linea de tiempo completa de eventos (fechas y observaciones)
-- ----------------------------------------------------------------------------
-- El PRIMER renglon de cada codigo_evento es el que toma la consulta
-- (ranking = 1, ordenado por idevento_pedido DESC).
SELECT
    ep.idevento_pedido,
    ev.codigo_evento,
    CAST(ep.fecha_evento AS DATE) AS fecha_evento,
    ep.observaciones,
    ROW_NUMBER() OVER(PARTITION BY ev.codigo_evento
                      ORDER BY ep.idevento_pedido DESC) AS ranking
FROM evento_pedido ep
JOIN evento ev ON ev.idevento = ep.idevento
WHERE ep.idpedido = @pedido
ORDER BY ep.idevento_pedido DESC;


-- ----------------------------------------------------------------------------
-- BLOQUE 4. Lo mismo pero replicando exactamente la logica del pivot
-- ----------------------------------------------------------------------------
-- Estos valores tienen que coincidir con las columnas de fecha del reporte.
WITH ev_pedido AS (
    SELECT
        ev.codigo_evento,
        CAST(e.fecha_evento AS DATE) AS fecha_evento_clean,
        ROW_NUMBER() OVER(PARTITION BY ev.codigo_evento
                          ORDER BY e.idevento_pedido DESC) AS ranking
    FROM (
        SELECT idevento, fecha_evento, idevento_pedido
        FROM view_eventos_pedidos
        WHERE idpedido = @pedido
        UNION ALL
        SELECT idevento, fecha_evento, idevento_pedido
        FROM historico_evento_pedido
        WHERE idpedido = @pedido
    ) e
    JOIN evento ev ON ev.idevento = e.idevento
    WHERE ev.codigo_evento IN (
        'PEDIDO_ENTREGADO', 'HABILITADO_RUTEO', 'FECHA_ESTIMADA_ENTREGA',
        'CARTA_PORTE_CREADA_RETIRO', 'COORDINADO', 'RE-COORDINADO'
    )
)
SELECT
    MAX(CASE WHEN codigo_evento = 'PEDIDO_ENTREGADO'          THEN fecha_evento_clean END) AS Fecha_Entregado,
    MAX(CASE WHEN codigo_evento = 'FECHA_ESTIMADA_ENTREGA'    THEN fecha_evento_clean END) AS Fecha_Estimada_Entrega,
    MAX(CASE WHEN codigo_evento = 'HABILITADO_RUTEO'          THEN fecha_evento_clean END) AS Fecha_Con_Stock,
    MAX(CASE WHEN codigo_evento = 'CARTA_PORTE_CREADA_RETIRO' THEN fecha_evento_clean END) AS Fecha_Carta_Porte_R,
    MAX(CASE WHEN codigo_evento = 'COORDINADO'                THEN fecha_evento_clean END) AS `COORDINADO`,
    MAX(CASE WHEN codigo_evento = 'RE-COORDINADO'             THEN fecha_evento_clean END) AS `RE-COORDINADO`
FROM ev_pedido
WHERE ranking = 1;


-- ----------------------------------------------------------------------------
-- BLOQUE 5. Regresion: la consulta nueva no debe cambiar el conteo de filas
-- ----------------------------------------------------------------------------
-- Ejecutar la consulta VIEJA y la NUEVA completas (sin filtro de idpedido) y
-- comparar el numero de filas que informa el cliente. Deben ser identicos:
-- todos los joins agregados son 1:1.
