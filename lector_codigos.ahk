; ============================================================
;  LECTOR DE CÓDIGOS - El Cholo Repuestos
;
;  NO requiere configurar el lector de código de barras.
;  Funciona con el lector en modo de fábrica (tipea el código
;  y manda Enter al final).
;
;  Cómo funciona:
;  - Solo actúa dentro de la ventana "Ingreso y Modificación
;    de Ítems" de tu sistema de facturación.
;  - Cuando aparece un Enter ahí, en vez de dejarlo pasar de
;    una, primero lee lo que quedó tipeado en el campo con
;    foco (copiándolo), lo busca en la base de códigos, y:
;      · Si lo encuentra: borra lo tipeado y escribe el
;        CÓDIGO correcto. NO manda Enter — vos revisás el
;        precio y aceptás a mano (con Enter o el botón).
;      · Si corresponde a varios artículos: te deja elegir.
;      · Si no lo encuentra: te deja buscar el artículo y
;        asignárselo (queda guardado para la próxima vez).
;    Si el campo está vacío, el Enter se comporta normal.
;
;  REQUIERE: AutoHotkey v2  (https://www.autohotkey.com/)
;
;  IMPORTANTE - Ajustá esto a tu PC:
;  Si el título de la ventana en tu sistema es distinto a
;  "Ingreso y Modificación de Ítems", cambialo en la variable
;  TituloVentana más abajo (alcanza con que sea parte del
;  título, no hace falta que sea exacto).
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetTitleMatchMode(2)

TituloVentana := "Ingreso y Modificación de Ítems"

; --- Archivos ---
ArchivoBase := A_ScriptDir "\codigos.tsv"
ArchivoArticulos := A_ScriptDir "\articulos.tsv"
ArchivoAgregados := A_ScriptDir "\codigos_agregados.tsv"

; --- Datos en memoria ---
Codigos := Map()             ; clave -> "cod1|desc1;;cod2|desc2..."
Codigos.CaseSense := false
Articulos := []              ; [{codigo, desc}, ...] para el buscador

CargarBase() {
    global Codigos, Articulos, ArchivoBase, ArchivoArticulos, ArchivoAgregados

    if !FileExist(ArchivoBase) {
        MsgBox("No encuentro codigos.tsv al lado del script. Lo necesito para funcionar.", "Lector de Códigos", "Icon!")
        ExitApp()
    }
    Loop Read, ArchivoBase
        CargarLineaCodigo(A_LoopReadLine)

    if FileExist(ArchivoAgregados)
        Loop Read, ArchivoAgregados
            CargarLineaCodigo(A_LoopReadLine)

    if FileExist(ArchivoArticulos) {
        Loop Read, ArchivoArticulos {
            partes := StrSplit(A_LoopReadLine, "`t")
            if partes.Length >= 1
                Articulos.Push({codigo: Trim(partes[1]), desc: partes.Length >= 2 ? Trim(partes[2]) : ""})
        }
    }
}

CargarLineaCodigo(linea) {
    global Codigos
    partes := StrSplit(linea, "`t")
    if partes.Length < 2
        return
    clave := Trim(partes[1])
    if clave != ""
        Codigos[clave] := partes[2]
}

CargarBase()

; ============================================================
;  Solo actúa cuando esa ventana puntual está activa
; ============================================================
#HotIf WinActive(TituloVentana)
Enter:: {
    ventanaOrigen := WinExist("A")

    texto := ""
    try {
        ctl := ControlGetFocus("A")
        texto := Trim(ControlGetText(ctl, "A"))
    } catch {
        texto := ""
    }

    ; Si por lo que sea no se pudo leer el control directamente,
    ; probamos con el método anterior (portapapeles) como respaldo
    if texto = "" {
        clipAnterior := ClipboardAll()
        A_Clipboard := ""
        Send("^a")
        Send("^c")
        huboTexto := ClipWait(0.3)
        texto := huboTexto ? Trim(A_Clipboard) : ""
        A_Clipboard := clipAnterior
    }

    if texto = "" {
        Send("{Enter}")  ; campo vacío u otra situación -> Enter normal
        return
    }

    ProcesarCodigo(texto, ventanaOrigen)
}
#HotIf

; ============================================================
;  Busca el código y actúa según el resultado
; ============================================================
ProcesarCodigo(codigoEscaneado, ventanaOrigen) {
    global Codigos
    clave := Trim(codigoEscaneado)

    if !Codigos.Has(clave) {
        SoundBeep(300, 200)  ; beep grave = no encontrado
        MostrarAsignar(clave, ventanaOrigen)
        return
    }

    candidatos := StrSplit(Codigos[clave], ";;")

    if candidatos.Length = 1 {
        partes := StrSplit(candidatos[1], "|")
        TipearCodigo(partes[1], ventanaOrigen)
        SoundBeep(1200, 80)  ; beep agudo corto = OK
    } else {
        MostrarSelector(candidatos, ventanaOrigen)
    }
}

; Reemplaza lo que haya en el campo con foco por el código correcto
; (sin apretar Enter, para que se pueda revisar el precio antes)
TipearCodigo(codigo, ventanaOrigen) {
    if ventanaOrigen && WinExist("ahk_id " ventanaOrigen)
        WinActivate("ahk_id " ventanaOrigen)
    Sleep(30)

    escrito := false
    try {
        ctl := ControlGetFocus("A")
        ControlSetText(codigo, ctl, "A")
        ControlFocus(ctl, "A")
        ; "toque" inofensivo (espacio + borrar) para que el sistema dispare
        ; su refresco de descripción/precio si depende de tecleo, sin
        ; alterar el código que acabamos de poner
        Send("{End}{Space}{BackSpace}")
        escrito := true
    } catch {
        escrito := false
    }

    if !escrito {
        Send("^a")
        SendInput(codigo)
    }
}

; ============================================================
;  Elegir cuando el código corresponde a varios artículos
; ============================================================
MostrarSelector(candidatos, ventanaOrigen) {
    SoundBeep(700, 150)
    opciones := []
    for c in candidatos {
        partes := StrSplit(c, "|")
        opciones.Push(partes[1] . "  -  " . (partes.Length > 1 ? partes[2] : ""))
    }

    dlg := Gui("+AlwaysOnTop", "Código ambiguo - Elegí el artículo")
    dlg.SetFont("s10")
    dlg.Add("Text",, "Este código corresponde a varios artículos:")
    lb := dlg.Add("ListBox", "w480 r6 vSel", opciones)
    btnOk := dlg.Add("Button", "Default w100", "Usar este")
    btnOk.OnEvent("Click", (*) => (
        lb.Value > 0
            ? (TipearCodigo(StrSplit(candidatos[lb.Value], "|")[1], ventanaOrigen), dlg.Destroy())
            : 0
    ))
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

; ============================================================
;  Asignar un código no encontrado a un artículo existente
; ============================================================
MostrarAsignar(codigoEscaneado, ventanaOrigen) {
    global Articulos, Codigos, ArchivoAgregados

    dlg := Gui("+AlwaysOnTop", "Código no encontrado: " codigoEscaneado)
    dlg.SetFont("s10")
    dlg.Add("Text",, "No encontré ese código. Buscá el artículo para asignárselo:")
    txt := dlg.Add("Edit", "w480 vBusqueda")
    lv := dlg.Add("ListView", "w480 r10", ["Código", "Descripción"])
    lv.ModifyCol(1, 110)
    lv.ModifyCol(2, 360)

    ActualizarLista(lv, Articulos, "")
    txt.OnEvent("Change", (*) => ActualizarLista(lv, Articulos, txt.Value))

    btnAsignar := dlg.Add("Button", "Default w150", "Asignar y tipear")
    btnAsignar.OnEvent("Click", (*) => AsignarSeleccion(dlg, lv, codigoEscaneado, ventanaOrigen))
    btnCancelar := dlg.Add("Button", "w100 x+10", "Cancelar")
    btnCancelar.OnEvent("Click", (*) => dlg.Destroy())

    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

ActualizarLista(lv, articulos, filtro) {
    lv.Delete()
    filtro := Trim(filtro)
    contador := 0
    for a in articulos {
        if filtro = "" || InStr(a.codigo, filtro) || InStr(a.desc, filtro) {
            lv.Add(, a.codigo, a.desc)
            contador += 1
            if contador >= 200
                break
        }
    }
}

AsignarSeleccion(dlg, lv, codigoEscaneado, ventanaOrigen) {
    global Codigos, ArchivoAgregados
    fila := lv.GetNext(0)
    if !fila {
        MsgBox("Elegí un artículo de la lista primero.")
        return
    }
    codigo := lv.GetText(fila, 1)
    desc := lv.GetText(fila, 2)

    Codigos[codigoEscaneado] := codigo "|" desc
    FileAppend(codigoEscaneado "`t" codigo "|" desc "`n", ArchivoAgregados, "UTF-8")

    dlg.Destroy()
    TipearCodigo(codigo, ventanaOrigen)
    SoundBeep(1200, 80)
}

; ============================================================
;  Ícono en la bandeja para confirmar que está corriendo
; ============================================================
TrayTip("Lector de Códigos activo", "El Cholo Repuestos - escuchando el lector")
