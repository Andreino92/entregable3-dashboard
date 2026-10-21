"""
app.py - Dashboard de Business Intelligence (Streamlit + PostgreSQL).

Ejecutar:  streamlit run app/app.py
Cada KPI, gráfico y tabla se obtiene llamando a una vista o función SQL del Data Mart.
"""
import plotly.express as px
import streamlit as st

import db

st.set_page_config(page_title="BI E-commerce 2021-2025", page_icon="📊", layout="wide")

VERDE, NARANJA = "#2E6B3F", "#C98A2B"
st.markdown(
    f"""<style>
    .block-container {{padding-top: 1.6rem;}}
    [data-testid="stMetricValue"] {{color: {VERDE}; font-weight: 700;}}
    h1, h2, h3 {{color: #1F4D2C;}}
    </style>""",
    unsafe_allow_html=True,
)


def num(v, d=0):
    """Formato 1.234.567,89"""
    return f"{v:,.{d}f}".replace(",", "X").replace(".", ",").replace("X", ".")


def ninguno(valor):
    """Convierte 'Todos' en None (= sin filtro) para enviarlo a las funciones SQL."""
    return None if valor in ("Todos", "Todas") else valor


# ---------------------------------------------------------------- conexión
ok, detalle = db.probar_conexion()
if not ok:
    st.error(
        "No se pudo conectar a PostgreSQL. Verifica que el contenedor esté encendido "
        "(`docker compose up -d`) y que ya se haya ejecutado `python cargar_datos.py`."
    )
    st.code(detalle)
    st.stop()

opc = db.opciones_filtros()

# ---------------------------------------------------------------- barra lateral
st.sidebar.title("📊 BI E-commerce")
pagina = st.sidebar.radio("Sección", ["Ventas y rentabilidad", "Logística y pérdidas"])
st.sidebar.markdown("---")
st.sidebar.subheader("Filtros")
anio_txt = st.sidebar.selectbox("Año", ["Todos"] + opc["anio"])
pais = ninguno(st.sidebar.selectbox("País", ["Todos"] + opc["pais"]))
anio = None if anio_txt == "Todos" else int(anio_txt)

if pagina == "Ventas y rentabilidad":
    categoria = ninguno(st.sidebar.selectbox("Categoría", ["Todas"] + opc["categoria"]))
    canal = ninguno(st.sidebar.selectbox("Canal de venta", ["Todos"] + opc["canal"]))
    envio = None
else:
    envio = ninguno(st.sidebar.selectbox("Método de envío", ["Todos", "Standard", "Express", "Economy", "Same Day"]))
    canal = ninguno(st.sidebar.selectbox("Canal de venta", ["Todos"] + opc["canal"]))
    categoria = None

st.sidebar.markdown("---")
st.sidebar.caption(f"🟢 PostgreSQL: {detalle}")

# =====================================================================
# SECCIÓN 1 · VENTAS Y RENTABILIDAD
# =====================================================================
if pagina == "Ventas y rentabilidad":
    st.title("Ventas y rentabilidad")
    st.caption("Pedidos completados · medidas calculadas desde las líneas de pedido (fact_ventas).")

    kpi = db.datos("SELECT * FROM fn_kpi_ventas(%s, %s, %s, %s)", (anio, pais, categoria, canal)).iloc[0]
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Ventas netas", f"$ {num(kpi.ventas_netas / 1e6, 2)} M" if kpi.ventas_netas >= 1e6 else f"$ {num(kpi.ventas_netas)}")
    c2.metric("Margen de utilidad", f"{num(kpi.margen_pct or 0, 1)} %")
    c3.metric("Ticket promedio", f"$ {num(kpi.ticket_promedio or 0, 2)}")
    c4.metric("Pedidos completados", num(kpi.pedidos))

    serie = db.datos("SELECT * FROM fn_serie_mensual(%s, %s, %s, %s)", (anio, pais, categoria, canal))
    margen = db.datos("SELECT * FROM fn_margen_por_categoria(%s, %s, %s)", (anio, pais, canal))

    if serie.empty:
        st.warning("No hay ventas completadas con esta combinación de filtros.")
    else:
        g1, g2 = st.columns([3, 2])
        with g1:
            st.subheader("Evolución mensual")
            largo = serie.melt("anio_mes", ["ventas_netas", "utilidad"], "serie", "monto")
            largo["serie"] = largo["serie"].map({"ventas_netas": "Ventas netas", "utilidad": "Utilidad"})
            fig = px.line(largo, x="anio_mes", y="monto", color="serie",
                          color_discrete_map={"Ventas netas": VERDE, "Utilidad": NARANJA},
                          labels={"anio_mes": "Mes", "monto": "US$", "serie": ""})
            fig.update_layout(margin=dict(l=0, r=0, t=10, b=0), legend=dict(orientation="h", y=1.1), height=380)
            st.plotly_chart(fig, width="stretch")
        with g2:
            st.subheader("Margen por categoría")
            st.caption("No se filtra por categoría, para poder compararlas entre sí.")
            m = margen.sort_values("margen_pct")
            fig2 = px.bar(m, x="margen_pct", y="categoria", orientation="h",
                          labels={"margen_pct": "Margen %", "categoria": ""},
                          color="margen_pct", color_continuous_scale=[NARANJA, VERDE])
            fig2.update_layout(margin=dict(l=0, r=0, t=10, b=0), coloraxis_showscale=False, height=380)
            st.plotly_chart(fig2, width="stretch")

    st.subheader("Productos más rentables")
    n = st.slider("Cantidad de productos a mostrar", 5, 50, 10, 5)
    top = db.datos("SELECT * FROM fn_top_productos(%s, %s, %s, %s, %s)", (anio, pais, categoria, n, canal))
    if top.empty:
        st.info("Sin productos para esta combinación de filtros.")
    else:
        st.dataframe(
            top, width="stretch", hide_index=True,
            column_config={
                "producto": "Producto", "categoria": "Categoría", "marca": "Marca",
                "unidades": st.column_config.NumberColumn("Unidades", format="%d"),
                "ventas_netas": st.column_config.NumberColumn("Ventas netas", format="$ %.0f"),
                "utilidad": st.column_config.NumberColumn("Utilidad", format="$ %.0f"),
                "margen_pct": st.column_config.NumberColumn("Margen %", format="%.1f %%"),
            },
        )
        st.download_button("Descargar tabla (CSV)", top.to_csv(index=False).encode("utf-8"), "top_productos.csv", "text/csv")

    with st.expander("Detalle de líneas de pedido (las 200 de mayor venta)"):
        det = db.datos("SELECT * FROM fn_detalle_ventas(%s, %s, %s, %s, %s)", (anio, pais, categoria, canal, 200))
        st.dataframe(det, width="stretch", hide_index=True)

# =====================================================================
# SECCIÓN 2 · LOGÍSTICA Y PÉRDIDAS
# =====================================================================
else:
    st.title("Logística y pérdidas")
    st.caption("Entregas: pedidos completados · Pérdidas: pedidos devueltos, cancelados o pendientes.")

    log = db.datos("SELECT * FROM fn_kpi_logistica(%s, %s, %s)", (anio, pais, envio)).iloc[0]
    tasa = db.datos("SELECT * FROM fn_tasa_devolucion_cancelacion(%s, %s, %s)", (anio, pais, canal)).iloc[0]
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Entregas tardías", f"{num(log.pct_tardias or 0, 1)} %")
    c2.metric("Calificación promedio", num(log.calificacion_prom or 0, 2))
    c3.metric("Tasa de devolución", f"{num(tasa.tasa_devolucion or 0, 2)} %")
    c4.metric("Tasa de cancelación", f"{num(tasa.tasa_cancelacion or 0, 2)} %")

    env = db.datos("SELECT * FROM fn_entregas_por_envio(%s, %s, %s)", (anio, pais, envio))
    per = db.datos("SELECT * FROM fn_perdidas(%s, %s, %s)", (anio, pais, canal))

    g1, g2 = st.columns(2)
    with g1:
        st.subheader("% de entregas tardías por método de envío")
        if env.empty:
            st.info("Sin entregas para esta combinación de filtros.")
        else:
            fig = px.bar(env, x="metodo_envio", y="pct_tardias", text="pct_tardias",
                         labels={"metodo_envio": "Método de envío", "pct_tardias": "% tardías"},
                         color_discrete_sequence=[VERDE])
            fig.update_traces(texttemplate="%{text:.1f} %", textposition="outside")
            fig.update_layout(margin=dict(l=0, r=0, t=10, b=0), height=360, yaxis_range=[0, max(25, env.pct_tardias.max() * 1.2)])
            st.plotly_chart(fig, width="stretch")
    with g2:
        st.subheader("Ventas perdidas por estado y motivo")
        if per.empty:
            st.info("Sin pedidos perdidos para esta combinación de filtros.")
        else:
            per = per.assign(etiqueta=per.estado_pedido + " · " + per.motivo)
            fig2 = px.bar(per.sort_values("ventas_netas"), x="ventas_netas", y="etiqueta", orientation="h",
                          labels={"ventas_netas": "Ventas netas (US$)", "etiqueta": ""},
                          color="estado_pedido",
                          color_discrete_map={"Returned": NARANJA, "Cancelled": "#8C3B3B", "Pending": "#7A8A80"})
            fig2.update_layout(margin=dict(l=0, r=0, t=10, b=0), height=360, legend_title_text="")
            st.plotly_chart(fig2, width="stretch")

    st.subheader("Desempeño por almacén")
    alm = db.datos("SELECT * FROM fn_entregas_por_almacen(%s, %s, %s)", (anio, pais, envio))
    st.dataframe(
        alm, width="stretch", hide_index=True,
        column_config={
            "almacen": "Almacén",
            "entregas": st.column_config.NumberColumn("Entregas", format="%d"),
            "pct_tardias": st.column_config.NumberColumn("% tardías", format="%.2f %%"),
            "calificacion_prom": st.column_config.NumberColumn("Calificación", format="%.2f"),
            "dias_entrega_prom": st.column_config.NumberColumn("Días de entrega", format="%.2f"),
        },
    )
