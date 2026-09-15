# Lector de Códigos - El Cholo Repuestos (PLAN 03)

## Qué hace
El lector queda en modo de fábrica, **no hace falta configurarlo**. El script solo actúa dentro de la ventana "Ingreso y Modificación de Ítems":

- Cuando aparece un Enter ahí (lo manda el lector al terminar de escanear), el script lee lo que quedó tipeado en el campo con foco, lo busca en la base, y:
  - **Lo encuentra:** borra lo tipeado y escribe el **CÓDIGO** correcto. **No manda Enter** — vos revisás el precio y aceptás a mano (Enter o botón Aceptar).
  - **Corresponde a varios artículos** (pasa en ~200 casos donde comparten referencia cruzada): aparece una ventanita para elegir cuál es.
  - **No lo encuentra:** aparece una ventanita para buscar el artículo por código o descripción y asignárselo. Queda guardado (`codigos_agregados.tsv`) para que la próxima vez lo reconozca solo.
- Si el campo está vacío, el Enter se comporta normal (no interfiere en nada más de tu sistema).

## Archivos
- `lector_codigos.ahk` — el script.
- `codigos.tsv` — base de códigos generada desde `articulos_mb.xlsx` (1726 artículos, 5576 claves entre CÓDIGO, CÓDIGO ANTERIOR e INFO ADICIONAL).
- `articulos.tsv` — listado completo código+descripción, para el buscador al asignar códigos nuevos.
- `codigos_agregados.tsv` — se crea solo la primera vez que asignás un código.

**Importante:** los cuatro archivos van juntos en la misma carpeta.

## Instalación
1. Instalá AutoHotkey v2 (gratis): https://www.autohotkey.com/download/ahk-v2.exe
2. Poné los 4 archivos en una carpeta, por ejemplo `C:\ElCholo\LectorCodigos\`.
3. Doble clic en `lector_codigos.ahk`. Va a aparecer un ícono en la bandeja confirmando que está activo.
4. (Opcional) Para que arranque solo con Windows: acceso directo al `.ahk` en la carpeta de Inicio (`shell:startup`).

## ⚠️ Un ajuste que puede hacer falta: el título de la ventana
El script solo actúa cuando está activa la ventana titulada **"Ingreso y Modificación de Ítems"**. Si en tu sistema el título es un poco distinto, hay que corregirlo:

1. Abrí esa ventana en tu sistema de facturación.
2. Instalado AutoHotkey, buscá en el menú de Windows "Window Spy" (viene incluido) y abrilo.
3. Pasá el mouse sobre la ventana de "Ingreso y Modificación de Ítems"; Window Spy te muestra su título exacto arriba de todo ("Title").
4. Si es distinto al que puse, avisame el título exacto (o el texto de la carpeta "ahk_class") y te actualizo el script — o vos mismo podés editar la línea cerca del principio del `.ahk`:
   ```
   TituloVentana := "Ingreso y Modificación de Ítems"
   ```
   poniendo ahí una parte del título real.

## Otro ajuste posible: si interfiere con otros campos de esa misma ventana
Ahora mismo el script reacciona a **cualquier Enter** dentro de esa ventana (no solo en el campo "Artículo"). Si notás que también te interfiere al presionar Enter en "Cantidad" u otro campo (por ejemplo, te borra o reemplaza algo que no corresponde), avisame — se puede acotar para que solo actúe en el campo "Artículo" puntual, usando Window Spy para identificar ese control exacto.

## Cómo usarlo en el día a día
1. Abrís la Factura, clic en "Agregar" como siempre, para que se abra "Ingreso y Modificación de Ítems" con el cursor en "Artículo".
2. Escaneás el código de barras del producto (normal, como siempre lo hiciste).
3. El script reemplaza lo tipeado por el código correcto.
4. Revisás el precio y aceptás normalmente (Enter o botón Aceptar) — se abre la ventana para el siguiente ítem.
5. Escaneás el siguiente.

## Pendiente / a probar juntos
- Confirmar que el título de la ventana coincide (ver arriba).
- Probar que "Ctrl+A / Ctrl+C" funcionan bien para leer el campo "Artículo" en tu sistema real (la mayoría de los controles de Windows lo soportan, pero puede haber excepciones).
- Ver si hace falta acotar la detección solo al campo "Artículo" (ver sección de arriba).
- Revisar juntos algunos de los ~200 códigos ambiguos.
