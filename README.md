# MI PRIMER DASHBOARD · Entregable 3

Solución de Business Intelligence de extremo a extremo sobre el dataset
**E-commerce Sales & Customer Analytics** (Kaggle, 2021-2025):

`CSV → Python/SQL (limpieza) → PostgreSQL (modelo dimensional) → vistas y funciones SQL → Python → Streamlit`

La aplicación **no lee ningún CSV**: todo lo que muestra sale de PostgreSQL.

## Requisitos
- Docker Desktop
- Python 3.10 o superior
- Los 4 archivos CSV del dataset en la carpeta `data/` (ver `data/LEEME.txt`):
  `ecommerce_sales_customer_analytics_150k.csv`, `order_items.csv`, `customer_master.csv`, `product_catalog.csv`
  (descarga: https://www.kaggle.com/datasets/datascikhan/e-commerce-sales-and-customer-analytics)

## Ejecución (desde la carpeta raíz del proyecto)
```powershell
# 1) Encender PostgreSQL 17 (localhost:5432, bi_database / bi_user / bi_password)
docker compose up -d

# 2) Instalar dependencias de Python
pip install -r app/requirements.txt

# 3) Crear el modelo, cargar los datos y validar (tarda alrededor de 1 minuto)
python cargar_datos.py

# 4) Abrir el dashboard (http://localhost:8501)
streamlit run app/app.py
```
Al terminar el paso 3 se imprime la tabla de validaciones: **27 filas en OK y 1 INFO**.

Para apagar: `docker compose down` (conserva los datos) o `docker compose down -v` (los borra).

## Estructura
```
docker-compose.yml          PostgreSQL 17
cargar_datos.py             pipeline: staging -> modelo -> ETL -> vistas/funciones -> validaciones
sql/01_staging.sql          tablas stg_* (CSV crudo, todo texto)
sql/02_modelo_ddl.sql       dimensiones, hechos, PK, FK, índices
sql/03_etl_carga.sql        limpieza, transformación y carga
sql/04_vistas_funciones.sql 8 vistas y 10 funciones que consume la aplicación
sql/05_validaciones.sql     consultas de validación (vista v_resultado_validaciones)
app/app.py                  dashboard Streamlit (2 secciones)
app/db.py                   conexión a PostgreSQL y consultas parametrizadas
imagenes/                   diagrama estrella, mockup y capturas de la aplicación
docs/                       documento final, guion del video y guía de estudio
```

## Modelo dimensional (resumen)
- `fact_ventas`: **una fila = un producto dentro de un pedido** (397.569 filas).
- `fact_pedidos`: una fila = un pedido (138.116 filas): entrega, calificación y lealtad.
- Dimensiones: `dim_tiempo`, `dim_cliente`, `dim_producto`, `dim_ubicacion`, `dim_marketing`, `dim_almacen`, `dim_pedido`.

## Problemas frecuentes
| Síntoma | Solución |
|---|---|
| `port is already allocated` | Otro PostgreSQL usa el 5432. Cambia el puerto en `docker-compose.yml` (`"5433:5432"`) y define `$env:PGPORT=5433` antes de los pasos 3 y 4. |
| La app muestra «No se pudo conectar a PostgreSQL» | Falta `docker compose up -d` o `python cargar_datos.py`. |
| `No such file ... data/...csv` | Copia los 4 CSV a `data/`. |
