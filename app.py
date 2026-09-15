import sqlite3
import streamlit as st
import pandas as pd

# Configuración de la base de datos SQLite
def init_db():
    conn = sqlite3.connect('codigos.db')
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS mapeo (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            codigo_barras TEXT UNIQUE,
            codigo_original TEXT,
            descripcion TEXT
        )
    ''')
    conn.commit()
    conn.close()

init_db()

st.title("Traductor de Códigos de Barras")
st.write("Gestiona la equivalencia entre los códigos de barras externos y los códigos originales de tu sistema de facturación.")

menu = ["Traducir / Buscar", "Registrar Nuevo", "Ver Base de Datos"]
choice = st.sidebar.selectbox("Menú de Navegación", menu)

if choice == "Traducir / Buscar":
    st.subheader("Consultar Código de Barras")
    busqueda = st.text_input("Escanea o ingresa el código de barras:")
    
    if busqueda:
        conn = sqlite3.connect('codigos.db')
        c = conn.cursor()
        c.execute("SELECT codigo_original, descripcion FROM mapeo WHERE codigo_barras = ?", (busqueda,))
        resultado = c.fetchone()
        conn.close()
        
        if resultado:
            st.success("¡Código encontrado!")
            st.metric(label="Código Original (Sistema)", value=resultado[0])
            st.write(f"**Descripción:** {resultado[1]}")
            # Código listo para copiar o usar
            st.code(resultado[0], language="text")
        else:
            st.error("El código de barras no está registrado en el sistema.")

elif choice == "Registrar Nuevo":
    st.subheader("Añadir Nueva Equivalencia")
    with st.form("registro_form"):
        codigo_barras = st.text_input("Código de Barras (Externo / Proveedor)")
        codigo_original = st.text_input("Código Original (Sistema de Facturación)")
        descripcion = st.text_input("Descripción del Producto")
        submitted = st.form_submit_button("Guardar en el Sistema")
        
        if submitted:
            if codigo_barras and codigo_original:
                try:
                    conn = sqlite3.connect('codigos.db')
                    c = conn.cursor()
                    c.execute("INSERT INTO mapeo (codigo_barras, codigo_original, descripcion) VALUES (?, ?, ?)", 
                              (codigo_barras, codigo_original, descripcion))
                    conn.commit()
                    conn.close()
                    st.success(f"Guardado exitoso: {codigo_barras} ➔ {codigo_original}")
                except sqlite3.IntegrityError:
                    st.warning("Este código de barras ya se encuentra registrado.")
            else:
                st.warning("Por favor completa al menos el código de barras y el código original.")

elif choice == "Ver Base de Datos":
    st.subheader("Listado de Códigos Mapeados")
    conn = sqlite3.connect('codigos.db')
    df = pd.read_sql_query("SELECT id, codigo_barras AS 'Código de Barras', codigo_original AS 'Código Original', descripcion AS 'Descripción' FROM mapeo", conn)
    conn.close()
    
    if not df.empty:
        st.dataframe(df, use_container_width=True)
        
        # Opción para eliminar registros
        st.write("---")
        id_a_borrar = st.number_input("ID a eliminar (opcional):", min_value=0, step=1)
        if st.button("Eliminar Registro"):
            if id_a_borrator > 0 or id_a_borrar == 0: # validación simple
                conn = sqlite3.connect('codigos.db')
                c = conn.cursor()
                c.execute("DELETE FROM mapeo WHERE id = ?", (id_a_borrar,))
                conn.commit()
                conn.close()
                st.success(f"Registro con ID {id_a_borrar} eliminado.")
                st.rerun()
    else:
        st.info("Aún no hay códigos cargados en la base de datos.")