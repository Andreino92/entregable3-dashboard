# Guía de estudio para la verificación individual

El docente puede pedirte que expliques o modifiques cualquier parte. Esto es lo esencial, en palabras simples.

## 1. ¿De dónde sale un KPI? (ejemplo: "Ventas netas")
1. En `app/app.py`, la línea `db.datos("SELECT * FROM fn_kpi_ventas(%s, %s, %s, %s)", (anio, pais, categoria, canal))` llama a una **función SQL**.
2. La función `fn_kpi_ventas` (en `sql/04_vistas_funciones.sql`) suma `ventas_netas` de la tabla `fact_ventas`, unida a las dimensiones, **solo de pedidos con estado Completed**, y aplica los filtros.
3. `ventas_netas` en `fact_ventas` viene de `order_items.net_sales`, cargado por `sql/03_etl_carga.sql`.

## 2. ¿Cómo se conecta Python con PostgreSQL?
`app/db.py` usa la librería **psycopg2** con host `localhost`, puerto `5432`, base `bi_database`, usuario `bi_user`. La función `consultar()` abre la conexión, ejecuta la consulta y devuelve un DataFrame de pandas. Los datos del filtro se envían como parámetros `%s` (no pegados al texto), lo que evita la inyección SQL.

## 3. ¿Cómo afecta un filtro a los resultados?
El filtro "Año" produce `anio = 2025` (o `None` si es "Todos"). Ese valor entra a la función como `p_anio`. Dentro, la condición `(p_anio IS NULL OR t.anio = p_anio)` hace que, si es NULL, no filtre nada. Por eso cada cambio de filtro vuelve a consultar la base.

## 4. Las dimensiones (cómo explicar cada una)
| Dimensión | Qué guarda | Para qué sirve |
|---|---|---|
| `dim_tiempo` | un día del calendario 2021-2025 | tendencias por mes y año |
| `dim_cliente` | edad, segmento, tipo, CLV, costo de adquisición | análisis por cliente |
| `dim_producto` | categoría, subcategoría, marca, proveedor | márgenes por producto |
| `dim_ubicacion` | ciudad, estado, país | comparación por país |
| `dim_marketing` | canal, campaña, cupón | desempeño de marketing |
| `dim_almacen` | código de almacén | entregas por almacén |
| `dim_pedido` | estado, canal, pago, envío, motivo de devolución | filtros de estado y canal |

## 5. Granularidad
"Una fila de `fact_ventas` representa **un producto dentro de un pedido**." Un pedido con 3 productos genera 3 filas. `order_id` es la dimensión degenerada que une con `fact_pedidos`.

## 6. Por qué las ventas del Entregable 1 y 3 difieren (144,2 M vs 156,8 M)
El encabezado del pedido y la suma de sus líneas no coinciden en 11.226 pedidos (8,1 %). Se eligieron las líneas porque son la única fuente con el producto. La validación 22 demuestra que el modelo suma exactamente lo que traen las líneas.

## 7. Modificaciones pequeñas que podrían pedirte
- **Cambiar el valor inicial del deslizador de productos:** en `app/app.py`, `st.slider("Cantidad de productos a mostrar", 5, 50, 10, 5)`: el tercer número (10) es el valor inicial.
- **Cambiar un título o color:** `VERDE` y `NARANJA` están al inicio de `app/app.py`.
- **Ejecutar una consulta:** en DBeaver, `SELECT * FROM fn_kpi_ventas(2024, 'Germany', NULL, NULL);`
- **Ver cuántas filas hay:** `SELECT count(*) FROM fact_ventas;` (397.569).
- **Explicar una vista:** `vw_margen_categoria` agrupa `fact_ventas` por categoría, subcategoría y marca, solo Completed, y calcula margen % = utilidad ÷ ventas netas.

## 8. Reglas que debes poder decir de memoria
1. La app **no lee CSV**; solo PostgreSQL.
2. Los KPI de ventas usan **solo pedidos Completed**.
3. Hay 2 secciones, 4 filtros en ventas y 4 en logística (año y país son comunes), 4 gráficos y 2 tablas de detalle.
4. 27 validaciones en OK; la 28 es informativa.
