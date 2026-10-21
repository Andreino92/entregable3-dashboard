"""
db.py - Acceso a PostgreSQL para la aplicación Streamlit.

Reglas:
  * Todos los datos salen de PostgreSQL (vistas y funciones SQL). La app NO lee ningún CSV.
  * Los filtros se envían como parámetros (%s), nunca se concatenan en el texto SQL.
"""
import os

import pandas as pd
import psycopg2
import streamlit as st

CONFIG = dict(
    host=os.getenv("PGHOST", "localhost"),
    port=int(os.getenv("PGPORT", 5432)),
    dbname=os.getenv("PGDATABASE", "bi_database"),
    user=os.getenv("PGUSER", "bi_user"),
    password=os.getenv("PGPASSWORD", "bi_password"),
    connect_timeout=5,
)


def consultar(sql: str, params: tuple = ()) -> pd.DataFrame:
    """Ejecuta una consulta parametrizada y devuelve un DataFrame."""
    with psycopg2.connect(**CONFIG) as con, con.cursor() as cur:
        cur.execute(sql, params)
        columnas = [c.name for c in cur.description]
        filas = cur.fetchall()
    df = pd.DataFrame(filas, columns=columnas)
    # NUMERIC de PostgreSQL llega como Decimal: se convierte a float para graficar.
    for c in df.columns:
        if df[c].dtype == object and len(df) and df[c].map(lambda v: hasattr(v, "as_tuple")).all():
            df[c] = df[c].astype(float)
    return df


@st.cache_data(ttl=300, show_spinner=False)
def datos(sql: str, params: tuple = ()) -> pd.DataFrame:
    """Igual que consultar(), pero con caché de 5 minutos por (sql, parámetros)."""
    return consultar(sql, params)


def probar_conexion() -> tuple[bool, str]:
    try:
        df = consultar("SELECT current_database() AS bd, (SELECT count(*) FROM fact_ventas) AS lineas")
        return True, f"{df.bd[0]} · {int(df.lineas[0]):,} líneas de venta".replace(",", ".")
    except Exception as e:  # noqa: BLE001
        return False, str(e).strip().splitlines()[0]


@st.cache_data(ttl=600, show_spinner=False)
def opciones_filtros() -> dict:
    """Valores de los filtros, leídos de la vista vw_filtros."""
    df = consultar("SELECT filtro, valor FROM vw_filtros ORDER BY filtro, valor")
    return {f: g["valor"].tolist() for f, g in df.groupby("filtro")}
