-- ============================================================================
-- HYCITE2 - Pendientes desde el viernes anterior   (SQL Server)
-- ----------------------------------------------------------------------------
-- CAMBIO: la ventana pasa de "ultimo dia" a "desde el viernes anterior,
-- 00:00", de modo que un lunes arrastre todo lo pendiente del fin de semana.
--
-- Bugs corregidos de la version anterior:
--   1) El comentario decia 7 dias pero el codigo tenia DATEADD(day,-1,...):
--      traia solo el ultimo dia.
--   2) GETDATE() incluye la HORA, asi que la ventana se corria con el momento
--      de ejecucion (correr a las 15:00 arrancaba el dia anterior a las 15:00
--      y perdia la manana). Ahora se ancla a las 00:00 del dia.
--
-- COMO SE CALCULA EL VIERNES
-- DATEDIFF(day, 0, fecha) % 7 da el dia de la semana con 0 = LUNES, porque el
-- dia 0 de SQL Server (1900-01-01) fue lunes. A diferencia de DATEPART(weekday),
-- este calculo NO depende de SET DATEFIRST ni del idioma de la sesion, asi que
-- da igual en cualquier servidor.
--
--   indice w:  0=Lun 1=Mar 2=Mie 3=Jue 4=Vie 5=Sab 6=Dom
--   dias a restar para caer en el viernes = (w + 3) % 7
--      Lun->3  Mar->4  Mie->5  Jue->6  Vie->0  Sab->1  Dom->2
-- ============================================================================

DECLARE @DESDE datetime =
    CAST(
        DATEADD(day,
                -(( DATEDIFF(day, 0, GETDATE()) + 3) % 7),
                CAST(GETDATE() AS date)
        ) AS datetime);

-- VARIANTE: viernes ESTRICTAMENTE anterior (si hoy es viernes, va 7 dias atras
-- en vez de arrancar hoy). Descomentar si el proceso tambien corre los viernes
-- y necesita incluir la semana completa:
-- DECLARE @DESDE datetime =
--     CAST(
--         DATEADD(day,
--                 -((( DATEDIFF(day, 0, GETDATE()) + 2) % 7) + 1),
--                 CAST(GETDATE() AS date)
--         ) AS datetime);

-- Control: verificar que la fecha calculada es la esperada antes de correr
-- SELECT @DESDE AS desde, DATENAME(weekday, @DESDE) AS dia_semana, GETDATE() AS ahora;


SELECT DISTINCT
    -- 1. Seleccion de campos solicitados (Sintaxis nativa T-SQL)
    SUBSTRING(syd.cliente_id, 1, 6)                      AS EMPRESA,
    syd.CUSTOMS_1                                        AS DIRECCION_DEST,
    syd.doc_ext                                          AS NRO_REFERENCIA,
    syd.doc_ext                                          AS NRO_REFERENCIA_VIAJE,
    syd.info_adicional_3                                 AS DESTINATARIO,
    syd.info_adicional_6                                 AS PROVINCIA_DEST,
    syd.CUSTOMS_2                                        AS LOCALIDAD_DEST,
    syd.CUSTOMS_3                                        AS CP_DEST,
    REPLACE('0' + syd.info_adicional_5, '-', '')         AS TELEFONO_MOVIL,
    REPLACE('0' + syd.info_adicional_4, '-', '')         AS Telefono_FIJO,
    syd.NRO_DESPACHO_IMPORTACION                         AS Email
FROM sys_int_documento syd

-- 2. Sin LTRIM/RTRIM para permitir que SQL Server use los indices existentes
INNER JOIN cliente cl
    ON syd.cliente_id = cl.cliente_id

INNER JOIN sys_int_documento_adicional syd_ad
    ON syd.doc_ext     = syd_ad.doc_ext
   AND syd.cliente_id  = syd_ad.cliente_id

WHERE syd.tipo_documento_id = 'E04'
  AND syd.cliente_id        = 'HYCITE2'

  -- 3. Filtro SARGable: la columna queda limpia a la izquierda del operador,
  --    por lo que el motor puede hacer Index Seek sobre fecha_creacion
  AND syd_ad.fecha_creacion >= @DESDE

  -- 4. Pendientes: sin agente asignado, o asignado a un agente distinto
  AND (syd.agente_id IS NULL OR syd.agente_id <> 'HYCITE2');


-- ============================================================================
-- CONTROL: que trae cada dia dentro de la ventana
-- ----------------------------------------------------------------------------
-- Util para confirmar que el fin de semana entro completo.
--
-- SELECT  CAST(syd_ad.fecha_creacion AS date)            AS dia,
--         DATENAME(weekday, syd_ad.fecha_creacion)       AS dia_semana,
--         COUNT(DISTINCT syd.doc_ext)                    AS documentos
-- FROM    sys_int_documento syd
--         INNER JOIN sys_int_documento_adicional syd_ad
--               ON syd.doc_ext = syd_ad.doc_ext AND syd.cliente_id = syd_ad.cliente_id
-- WHERE   syd.tipo_documento_id = 'E04'
--   AND   syd.cliente_id = 'HYCITE2'
--   AND   syd_ad.fecha_creacion >= @DESDE
--   AND   (syd.agente_id IS NULL OR syd.agente_id <> 'HYCITE2')
-- GROUP BY CAST(syd_ad.fecha_creacion AS date), DATENAME(weekday, syd_ad.fecha_creacion)
-- ORDER BY dia;
--
-- ----------------------------------------------------------------------------
-- VERIFICACION DE LA FORMULA DEL VIERNES (no toca datos)
-- ----------------------------------------------------------------------------
-- Imprime los proximos 14 dias y que viernes resuelve cada uno.
--
-- WITH dias AS (
--     SELECT CAST(GETDATE() AS date) AS d
--     UNION ALL
--     SELECT DATEADD(day, 1, d) FROM dias WHERE d < DATEADD(day, 13, CAST(GETDATE() AS date))
-- )
-- SELECT  d                                              AS fecha,
--         DATENAME(weekday, d)                           AS dia_semana,
--         DATEADD(day, -((DATEDIFF(day, 0, d) + 3) % 7), d) AS viernes_resuelto,
--         DATENAME(weekday, DATEADD(day, -((DATEDIFF(day, 0, d) + 3) % 7), d)) AS control
-- FROM dias
-- OPTION (MAXRECURSION 0);
-- ============================================================================
