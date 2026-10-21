# Guion del video individual (3 a 5 minutos)

Grábalo con la pantalla compartida (OBS, Xbox Game Bar con Win+G, o Zoom). Antes de grabar:
`docker compose up -d`, `python cargar_datos.py` terminado, `streamlit run app/app.py` abierto,
y DBeaver conectado a `bi_database`. Deja el video entre 3:30 y 4:30 para no pasarte de 5:00.

| Tiempo | Qué mostrar | Qué decir (con tus palabras) |
|---|---|---|
| 0:00 - 0:30 | Documento o README | Me llamo Andrés Poveda. Uso el dataset E-commerce Sales & Customer Analytics de Kaggle: 138.116 pedidos y 397.569 líneas entre 2021 y 2025. El problema: las áreas comercial y logística no saben qué categorías rinden mejor, cuánto se pierde en devoluciones ni dónde se atrasan las entregas. |
| 0:30 - 1:15 | `imagenes/estrella.png` | Modelo estrella: la tabla de hechos `fact_ventas` y 7 dimensiones. **Una fila de `fact_ventas` representa un producto dentro de un pedido.** `fact_pedidos` guarda lo que es del pedido completo (entrega y calificación). Muestro dimensiones tiempo, cliente, producto, ubicación, marketing, almacén y pedido. |
| 1:15 - 2:00 | DBeaver | Abro `bi_database`: tablas cargadas. Ejecuto `SELECT count(*) FROM fact_ventas;` (397.569). Ejecuto `SELECT * FROM v_resultado_validaciones;` (27 OK). Muestro la función `fn_kpi_ventas` y la ejecuto: `SELECT * FROM fn_kpi_ventas(2025,'USA',NULL,NULL);`. |
| 2:00 - 3:15 | Streamlit, sección «Ventas y rentabilidad» | Estos KPI vienen de `fn_kpi_ventas`. El gráfico de línea viene de `fn_serie_mensual`, las barras de `fn_margen_por_categoria` y la tabla de `fn_top_productos`. **Cambio el filtro Año a 2025 y País a USA: cambian los KPI, los gráficos y la tabla.** Paso a «Logística y pérdidas» y cambio el método de envío. |
| 3:15 - 4:00 | Un resultado | Electronics es la categoría que más vende pero la de menor margen (32,6 %). Decisión posible: revisar los descuentos de Electronics antes de impulsarla. (Elige otro resultado si prefieres, pero explica qué decisión permite.) |
| 4:00 - 4:30 | Documento, sección de IA | Usé IA para generar el código base y resolver errores. Ejemplo: la carga de la tabla de hechos se quedaba más de 5 minutos; la IA sugirió `ANALYZE` y simplificar los joins; lo probé y bajó a unos 25 segundos y las validaciones siguieron en OK. |

Consejos: no leas, explica; muestra la pantalla real todo el tiempo (no solo diapositivas);
habla de lo que **entiendes**, porque el docente puede pedirte que lo repitas o lo modifiques.
