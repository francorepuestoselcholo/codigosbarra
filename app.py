import sqlite3
from pathlib import Path

import pandas as pd
import streamlit as st

DB_PATH = Path(__file__).with_name("codigos.db")


def normalizar_codigo(valor):
    """Normaliza códigos sin modificar su contenido interno."""
    if valor is None:
        return ""
    return str(valor).replace("\ufeff", "").strip()


def get_connection():
    return sqlite3.connect(DB_PATH)


def init_db():
    with get_connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS mapeo (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                codigo_barras TEXT UNIQUE NOT NULL,
                codigo_original TEXT NOT NULL,
                descripcion TEXT DEFAULT ''
            )
            """
        )


init_db()

st.set_page_config(page_title="Traductor de Códigos", page_icon="📦", layout="wide")
st.title("Traductor de Códigos de Barras")
st.write(
    "Gestiona la equivalencia entre los códigos de barras externos y los códigos originales de tu sistema de facturación."
)

menu = ["Traducir / Buscar", "Registrar Nuevo", "Ver Base de Datos"]
choice = st.sidebar.selectbox("Menú de Navegación", menu)


if choice == "Traducir / Buscar":
    st.subheader("Consultar Código de Barras")
    busqueda = st.text_input("Escanea o ingresa el código de barras:").strip()

    if busqueda:
        with get_connection() as conn:
            resultado = conn.execute(
                "SELECT codigo_original, descripcion FROM mapeo WHERE codigo_barras = ?",
                (normalizar_codigo(busqueda),),
            ).fetchone()

        if resultado:
            st.success("¡Código encontrado!")
            st.metric(label="Código Original (Sistema)", value=resultado[0])
            st.write(f"**Descripción:** {resultado[1]}")
            st.code(resultado[0], language="text")
        else:
            st.error("El código de barras no está registrado en el sistema.")


elif choice == "Registrar Nuevo":
    st.subheader("Añadir Nueva Equivalencia")

    with st.form("registro_form", clear_on_submit=True):
        codigo_barras = st.text_input("Código de Barras (Externo / Proveedor)")
        codigo_original = st.text_input("Código Original (Sistema de Facturación)")
        descripcion = st.text_input("Descripción del Producto")
        submitted = st.form_submit_button("Guardar en el Sistema")

        if submitted:
            codigo_barras = normalizar_codigo(codigo_barras)
            codigo_original = normalizar_codigo(codigo_original)
            descripcion = descripcion.strip()

            if not codigo_barras or not codigo_original:
                st.warning("Por favor completa al menos el código de barras y el código original.")
            else:
                try:
                    with get_connection() as conn:
                        conn.execute(
                            "INSERT INTO mapeo (codigo_barras, codigo_original, descripcion) VALUES (?, ?, ?)",
                            (codigo_barras, codigo_original, descripcion),
                        )
                    st.success(f"Guardado exitoso: {codigo_barras} ➔ {codigo_original}")
                except sqlite3.IntegrityError:
                    st.warning("Este código de barras ya se encuentra registrado.")


else:
    st.subheader("Listado de Códigos Mapeados")

    with get_connection() as conn:
        df = pd.read_sql_query(
            """
            SELECT
                id,
                codigo_barras AS 'Código de Barras',
                codigo_original AS 'Código Original',
                descripcion AS 'Descripción'
            FROM mapeo
            ORDER BY id DESC
            """,
            conn,
        )

    if not df.empty:
        st.dataframe(df, use_container_width=True, hide_index=True)

        st.write("---")
        id_a_borrar = st.number_input("ID a eliminar:", min_value=1, step=1, value=1)

        if st.button("Eliminar Registro", type="secondary"):
            with get_connection() as conn:
                cursor = conn.execute("DELETE FROM mapeo WHERE id = ?", (int(id_a_borrar),))
                eliminado = cursor.rowcount

            if eliminado:
                st.success(f"Registro con ID {int(id_a_borrar)} eliminado.")
                st.rerun()
            else:
                st.warning(f"No existe un registro con ID {int(id_a_borrar)}.")
    else:
        st.info("Aún no hay códigos cargados en la base de datos.")
