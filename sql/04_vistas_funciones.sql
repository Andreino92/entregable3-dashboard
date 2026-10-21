-- =====================================================================
-- 04_vistas_funciones.sql  |  OBJETOS SQL QUE ALIMENTAN EL DASHBOARD
-- Convencion: parametros NULL = "sin filtro" (Todos).
-- Regla de negocio: los KPI de ventas consideran solo pedidos Completed.
-- =====================================================================

-- ---------- VISTAS ---------------------------------------------------

-- Valores de los filtros del dashboard (Año, País, Categoría, Canal de venta)
CREATE OR REPLACE VIEW vw_filtros AS
SELECT 'anio' AS filtro, anio::text AS valor FROM dim_tiempo GROUP BY anio
UNION ALL SELECT 'pais',      pais      FROM dim_ubicacion GROUP BY pais
UNION ALL SELECT 'categoria', categoria FROM dim_producto  GROUP BY categoria
UNION ALL SELECT 'canal',     canal_venta FROM dim_pedido  GROUP BY canal_venta;

-- Pregunta 1: evolucion de ventas y utilidad (serie mensual, filtrable)
CREATE OR REPLACE VIEW vw_ventas_mensuales AS
SELECT t.anio, t.mes, t.anio_mes, t.nombre_mes,
       u.pais, dp.canal_venta, pr.categoria, dp.estado_pedido,
       SUM(f.cantidad)        AS unidades,
       SUM(f.ventas_brutas)   AS ventas_brutas,
       SUM(f.monto_descuento) AS descuento,
       SUM(f.ventas_netas)    AS ventas_netas,
       SUM(f.costo_producto)  AS costo_producto,
       SUM(f.utilidad)        AS utilidad
FROM fact_ventas f
JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
GROUP BY t.anio, t.mes, t.anio_mes, t.nombre_mes, u.pais, dp.canal_venta, pr.categoria, dp.estado_pedido;

-- Pregunta 2: utilidad y margen por categoria / subcategoria / marca (solo Completed)
CREATE OR REPLACE VIEW vw_margen_categoria AS
SELECT t.anio, u.pais, pr.categoria, pr.subcategoria, pr.marca,
       SUM(f.cantidad)        AS unidades,
       SUM(f.ventas_netas)    AS ventas_netas,
       SUM(f.utilidad)        AS utilidad,
       ROUND(100.0 * SUM(f.utilidad)         / NULLIF(SUM(f.ventas_netas),  0), 2) AS margen_pct,
       ROUND(100.0 * SUM(f.monto_descuento)  / NULLIF(SUM(f.ventas_brutas), 0), 2) AS descuento_pct
FROM fact_ventas f
JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
WHERE dp.estado_pedido = 'Completed'
GROUP BY t.anio, u.pais, pr.categoria, pr.subcategoria, pr.marca;

-- Pregunta 3: ventas perdidas (Returned / Cancelled / Pending) por motivo, pago y canal
CREATE OR REPLACE VIEW vw_perdidas_por_estado AS
SELECT t.anio, u.pais, dp.estado_pedido, dp.motivo_devolucion, dp.metodo_pago, dp.canal_venta,
       COUNT(DISTINCT f.order_id) AS pedidos,
       SUM(f.ventas_netas)        AS ventas_netas,
       SUM(f.utilidad)            AS utilidad
FROM fact_ventas f
JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
WHERE dp.estado_pedido <> 'Completed'
GROUP BY t.anio, u.pais, dp.estado_pedido, dp.motivo_devolucion, dp.metodo_pago, dp.canal_venta;

-- Pregunta 4: entregas y satisfaccion por metodo de envio / almacen (solo Completed)
CREATE OR REPLACE VIEW vw_entregas_envio AS
SELECT t.anio, u.pais, dp.metodo_envio, a.codigo_almacen, dp.estado_entrega,
       COUNT(*)                         AS entregas,
       ROUND(AVG(fp.dias_entrega), 2)   AS dias_entrega_prom,
       ROUND(AVG(fp.dias_retraso), 2)   AS dias_retraso_prom,
       ROUND(AVG(fp.calificacion), 2)   AS calificacion_prom
FROM fact_pedidos fp
JOIN dim_tiempo    t  ON t.id_tiempo      = fp.id_tiempo
JOIN dim_ubicacion u  ON u.id_ubicacion   = fp.id_ubicacion
JOIN dim_pedido    dp ON dp.id_dim_pedido = fp.id_dim_pedido
JOIN dim_almacen   a  ON a.id_almacen     = fp.id_almacen
WHERE dp.estado_pedido = 'Completed'
GROUP BY t.anio, u.pais, dp.metodo_envio, a.codigo_almacen, dp.estado_entrega;

-- Pregunta 5a: valor del cliente frente a su costo de adquisicion, por segmento
CREATE OR REPLACE VIEW vw_clv_cac_segmento AS
SELECT segmento, tipo_cliente,
       COUNT(*)                                   AS clientes,
       ROUND(AVG(costo_adquisicion), 2)           AS cac_promedio,
       ROUND(AVG(valor_vida_cliente), 2)          AS clv_promedio,
       ROUND(AVG(valor_vida_cliente) / NULLIF(AVG(costo_adquisicion), 0), 2) AS relacion_clv_cac
FROM dim_cliente
WHERE tipo_cliente <> 'Sin compras'
GROUP BY segmento, tipo_cliente;

-- Pregunta 5b: aporte de cada canal / campana de marketing (solo Completed)
CREATE OR REPLACE VIEW vw_marketing_canal AS
SELECT t.anio, m.canal, m.campana,
       COUNT(DISTINCT f.order_id)   AS pedidos,
       COUNT(DISTINCT f.id_cliente) AS clientes,
       SUM(f.ventas_netas)          AS ventas_netas,
       SUM(f.utilidad)              AS utilidad,
       ROUND(100.0 * SUM(f.monto_descuento) / NULLIF(SUM(f.ventas_brutas), 0), 2) AS descuento_pct
FROM fact_ventas f
JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
JOIN dim_marketing m  ON m.id_marketing   = f.id_marketing
JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
WHERE dp.estado_pedido = 'Completed'
GROUP BY t.anio, m.canal, m.campana;

-- Tabla de detalle del dashboard: una fila por linea de pedido, ya "aplanada"
CREATE OR REPLACE VIEW vw_detalle_ventas AS
SELECT f.order_id, f.num_linea, t.fecha, t.anio, t.nombre_mes,
       c.cliente_id_origen AS cliente, c.segmento,
       u.pais, u.estado, u.ciudad,
       pr.categoria, pr.subcategoria, pr.marca, pr.nombre_producto,
       dp.canal_venta, dp.estado_pedido, dp.metodo_pago,
       f.cantidad, f.pct_descuento, f.ventas_netas, f.utilidad
FROM fact_ventas f
JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
JOIN dim_cliente   c  ON c.id_cliente     = f.id_cliente
JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido;

-- ---------- FUNCIONES (KPI con filtros) -------------------------------

-- KPI: ventas netas, utilidad, margen % y ticket promedio (pedidos Completed)
CREATE OR REPLACE FUNCTION fn_kpi_ventas(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL,
    p_categoria TEXT DEFAULT NULL, p_canal TEXT DEFAULT NULL)
RETURNS TABLE (ventas_netas NUMERIC, utilidad NUMERIC, margen_pct NUMERIC,
               pedidos BIGINT, ticket_promedio NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(f.ventas_netas), 0),
           COALESCE(SUM(f.utilidad), 0),
           ROUND(100.0 * SUM(f.utilidad) / NULLIF(SUM(f.ventas_netas), 0), 2),
           COUNT(DISTINCT f.order_id),
           ROUND(SUM(f.ventas_netas) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2)
    FROM fact_ventas f
    JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
    JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
    JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio      IS NULL OR t.anio          = p_anio)
      AND (p_pais      IS NULL OR u.pais          = p_pais)
      AND (p_categoria IS NULL OR pr.categoria    = p_categoria)
      AND (p_canal     IS NULL OR dp.canal_venta  = p_canal);
$$;

-- KPI: tasa de devolucion y de cancelacion (sobre el total de pedidos)
CREATE OR REPLACE FUNCTION fn_tasa_devolucion_cancelacion(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL, p_canal TEXT DEFAULT NULL)
RETURNS TABLE (pedidos_totales BIGINT, tasa_devolucion NUMERIC, tasa_cancelacion NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT COUNT(*),
           ROUND(100.0 * COUNT(*) FILTER (WHERE fp.es_devuelto)  / NULLIF(COUNT(*), 0), 2),
           ROUND(100.0 * COUNT(*) FILTER (WHERE fp.es_cancelado) / NULLIF(COUNT(*), 0), 2)
    FROM fact_pedidos fp
    JOIN dim_tiempo    t  ON t.id_tiempo      = fp.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = fp.id_ubicacion
    JOIN dim_pedido    dp ON dp.id_dim_pedido = fp.id_dim_pedido
    WHERE (p_anio  IS NULL OR t.anio         = p_anio)
      AND (p_pais  IS NULL OR u.pais         = p_pais)
      AND (p_canal IS NULL OR dp.canal_venta = p_canal);
$$;

-- KPI: % de entregas tardias y calificacion promedio (pedidos Completed)
CREATE OR REPLACE FUNCTION fn_kpi_logistica(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL, p_metodo_envio TEXT DEFAULT NULL)
RETURNS TABLE (entregas BIGINT, pct_tardias NUMERIC, calificacion_prom NUMERIC,
               dias_entrega_prom NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT COUNT(*),
           ROUND(100.0 * COUNT(*) FILTER (WHERE fp.es_entrega_tardia) / NULLIF(COUNT(*), 0), 2),
           ROUND(AVG(fp.calificacion), 2),
           ROUND(AVG(fp.dias_entrega), 2)
    FROM fact_pedidos fp
    JOIN dim_tiempo    t  ON t.id_tiempo      = fp.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = fp.id_ubicacion
    JOIN dim_pedido    dp ON dp.id_dim_pedido = fp.id_dim_pedido
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio        IS NULL OR t.anio           = p_anio)
      AND (p_pais        IS NULL OR u.pais           = p_pais)
      AND (p_metodo_envio IS NULL OR dp.metodo_envio = p_metodo_envio);
$$;

-- Tabla de detalle: ranking de productos por utilidad (con filtros)
DROP FUNCTION IF EXISTS fn_top_productos(INT, TEXT, TEXT, INT);
CREATE OR REPLACE FUNCTION fn_top_productos(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL,
    p_categoria TEXT DEFAULT NULL, p_limite INT DEFAULT 10, p_canal TEXT DEFAULT NULL)
RETURNS TABLE (producto TEXT, categoria TEXT, marca TEXT, unidades BIGINT,
               ventas_netas NUMERIC, utilidad NUMERIC, margen_pct NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT pr.nombre_producto::text, pr.categoria::text, pr.marca::text,
           SUM(f.cantidad)::bigint,
           SUM(f.ventas_netas),
           SUM(f.utilidad),
           ROUND(100.0 * SUM(f.utilidad) / NULLIF(SUM(f.ventas_netas), 0), 2)
    FROM fact_ventas f
    JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
    JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
    JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio      IS NULL OR t.anio       = p_anio)
      AND (p_pais      IS NULL OR u.pais       = p_pais)
      AND (p_categoria IS NULL OR pr.categoria = p_categoria)
      AND (p_canal     IS NULL OR dp.canal_venta = p_canal)
    GROUP BY pr.nombre_producto, pr.categoria, pr.marca
    ORDER BY SUM(f.utilidad) DESC
    LIMIT p_limite;
$$;

-- =====================================================================
-- FUNCIONES PARA LA APLICACION STREAMLIT (Entregable 3)
-- Cada funcion recibe los filtros del dashboard; NULL = sin filtro.
-- =====================================================================

-- Serie mensual de ventas y utilidad (pedidos Completed)
CREATE OR REPLACE FUNCTION fn_serie_mensual(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL,
    p_categoria TEXT DEFAULT NULL, p_canal TEXT DEFAULT NULL)
RETURNS TABLE (anio_mes TEXT, ventas_netas NUMERIC, utilidad NUMERIC, pedidos BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT t.anio_mes::text, SUM(f.ventas_netas), SUM(f.utilidad), COUNT(DISTINCT f.order_id)
    FROM fact_ventas f
    JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
    JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
    JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio      IS NULL OR t.anio         = p_anio)
      AND (p_pais      IS NULL OR u.pais         = p_pais)
      AND (p_categoria IS NULL OR pr.categoria   = p_categoria)
      AND (p_canal     IS NULL OR dp.canal_venta = p_canal)
    GROUP BY t.anio_mes
    ORDER BY t.anio_mes;
$$;

-- Margen por categoria (pedidos Completed)
CREATE OR REPLACE FUNCTION fn_margen_por_categoria(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL, p_canal TEXT DEFAULT NULL)
RETURNS TABLE (categoria TEXT, ventas_netas NUMERIC, utilidad NUMERIC, margen_pct NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT pr.categoria::text, SUM(f.ventas_netas), SUM(f.utilidad),
           ROUND(100.0 * SUM(f.utilidad) / NULLIF(SUM(f.ventas_netas), 0), 2)
    FROM fact_ventas f
    JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
    JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
    JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio  IS NULL OR t.anio         = p_anio)
      AND (p_pais  IS NULL OR u.pais         = p_pais)
      AND (p_canal IS NULL OR dp.canal_venta = p_canal)
    GROUP BY pr.categoria
    ORDER BY 4 DESC;
$$;

-- Detalle de lineas de venta (las de mayor venta primero)
CREATE OR REPLACE FUNCTION fn_detalle_ventas(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL,
    p_categoria TEXT DEFAULT NULL, p_canal TEXT DEFAULT NULL, p_limite INT DEFAULT 200)
RETURNS TABLE (order_id TEXT, fecha DATE, pais TEXT, categoria TEXT, producto TEXT,
               canal TEXT, cantidad INT, ventas_netas NUMERIC, utilidad NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT f.order_id::text, t.fecha, u.pais::text, pr.categoria::text, pr.nombre_producto::text,
           dp.canal_venta::text, f.cantidad, f.ventas_netas, f.utilidad
    FROM fact_ventas f
    JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
    JOIN dim_producto  pr ON pr.id_producto   = f.id_producto
    JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio      IS NULL OR t.anio         = p_anio)
      AND (p_pais      IS NULL OR u.pais         = p_pais)
      AND (p_categoria IS NULL OR pr.categoria   = p_categoria)
      AND (p_canal     IS NULL OR dp.canal_venta = p_canal)
    ORDER BY f.ventas_netas DESC
    LIMIT p_limite;
$$;

-- Entregas por metodo de envio (pedidos Completed)
CREATE OR REPLACE FUNCTION fn_entregas_por_envio(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL, p_metodo_envio TEXT DEFAULT NULL)
RETURNS TABLE (metodo_envio TEXT, entregas BIGINT, tardias BIGINT, pct_tardias NUMERIC,
               calificacion_prom NUMERIC, dias_entrega_prom NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT dp.metodo_envio::text, COUNT(*),
           COUNT(*) FILTER (WHERE fp.es_entrega_tardia),
           ROUND(100.0 * COUNT(*) FILTER (WHERE fp.es_entrega_tardia) / NULLIF(COUNT(*), 0), 2),
           ROUND(AVG(fp.calificacion), 2), ROUND(AVG(fp.dias_entrega), 2)
    FROM fact_pedidos fp
    JOIN dim_tiempo    t  ON t.id_tiempo      = fp.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = fp.id_ubicacion
    JOIN dim_pedido    dp ON dp.id_dim_pedido = fp.id_dim_pedido
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio         IS NULL OR t.anio           = p_anio)
      AND (p_pais         IS NULL OR u.pais           = p_pais)
      AND (p_metodo_envio IS NULL OR dp.metodo_envio  = p_metodo_envio)
    GROUP BY dp.metodo_envio
    ORDER BY 4 DESC;
$$;

-- Entregas por almacen (tabla de detalle de la pagina de logistica)
CREATE OR REPLACE FUNCTION fn_entregas_por_almacen(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL, p_metodo_envio TEXT DEFAULT NULL)
RETURNS TABLE (almacen TEXT, entregas BIGINT, pct_tardias NUMERIC,
               calificacion_prom NUMERIC, dias_entrega_prom NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT a.codigo_almacen::text, COUNT(*),
           ROUND(100.0 * COUNT(*) FILTER (WHERE fp.es_entrega_tardia) / NULLIF(COUNT(*), 0), 2),
           ROUND(AVG(fp.calificacion), 2), ROUND(AVG(fp.dias_entrega), 2)
    FROM fact_pedidos fp
    JOIN dim_tiempo    t  ON t.id_tiempo      = fp.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = fp.id_ubicacion
    JOIN dim_pedido    dp ON dp.id_dim_pedido = fp.id_dim_pedido
    JOIN dim_almacen   a  ON a.id_almacen     = fp.id_almacen
    WHERE dp.estado_pedido = 'Completed'
      AND (p_anio         IS NULL OR t.anio           = p_anio)
      AND (p_pais         IS NULL OR u.pais           = p_pais)
      AND (p_metodo_envio IS NULL OR dp.metodo_envio  = p_metodo_envio)
    GROUP BY a.codigo_almacen
    ORDER BY 3 DESC;
$$;

-- Ventas perdidas (Returned / Cancelled / Pending) por estado y motivo
CREATE OR REPLACE FUNCTION fn_perdidas(
    p_anio INT DEFAULT NULL, p_pais TEXT DEFAULT NULL, p_canal TEXT DEFAULT NULL)
RETURNS TABLE (estado_pedido TEXT, motivo TEXT, pedidos BIGINT, ventas_netas NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT dp.estado_pedido::text, dp.motivo_devolucion::text,
           COUNT(DISTINCT f.order_id), SUM(f.ventas_netas)
    FROM fact_ventas f
    JOIN dim_tiempo    t  ON t.id_tiempo      = f.id_tiempo
    JOIN dim_ubicacion u  ON u.id_ubicacion   = f.id_ubicacion
    JOIN dim_pedido    dp ON dp.id_dim_pedido = f.id_dim_pedido
    WHERE dp.estado_pedido <> 'Completed'
      AND (p_anio  IS NULL OR t.anio         = p_anio)
      AND (p_pais  IS NULL OR u.pais         = p_pais)
      AND (p_canal IS NULL OR dp.canal_venta = p_canal)
    GROUP BY dp.estado_pedido, dp.motivo_devolucion
    ORDER BY 4 DESC;
$$;
