; ============================================================
;  LECTOR DE CÓDIGOS - El Cholo Repuestos
;  AutoHotkey v2
;
;  El lector funciona como teclado: escribe el código y manda Enter.
;  El script solo intercepta Enter cuando está activa la ventana
;  "Ingreso y Modificación de Ítems".
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetTitleMatchMode(2)

TituloVentana := "Ingreso y Modificación de Ítems"

ArchivoBase := A_ScriptDir "\codigos.tsv"
ArchivoArticulos := A_ScriptDir "\articulos.tsv"
ArchivoAgregados := A_ScriptDir "\codigos_agregados.tsv"

Codigos := Map()                 ; clave -> array de candidatos {codigo, desc}
Codigos.CaseSense := false
Articulos := []                  ; [{codigo, desc}, ...]

NormalizarCodigo(valor) {
    ; Quita BOM, espacios y saltos de línea que pueden venir de TSV/lector.
    valor := StrReplace(valor, Chr(0xFEFF), "")
    valor := StrReplace(valor, "`r", "")
    valor := StrReplace(valor, "`n", "")
    return Trim(valor)
}

AgregarCandidato(clave, codigo, desc) {
    global Codigos
    clave := NormalizarCodigo(clave)
    codigo := NormalizarCodigo(codigo)
    desc := Trim(desc)
    if clave = "" || codigo = ""
        return

    if !Codigos.Has(clave)
        Codigos[clave] := []

    ; Evita duplicar exactamente el mismo artículo si aparece repetido en los TSV.
    for candidato in Codigos[clave] {
        if candidato.codigo = codigo && candidato.desc = desc
            return
    }
    Codigos[clave].Push({codigo: codigo, desc: desc})
}

CargarLineaCodigo(linea) {
    partes := StrSplit(linea, "`t")
    if partes.Length < 2
        return

    clave := NormalizarCodigo(partes[1])
    valor := partes[2]
    candidatos := StrSplit(valor, ";;")

    for candidato in candidatos {
        p := StrSplit(candidato, "|")
        if p.Length >= 1 {
            codigo := p[1]
            desc := p.Length >= 2 ? p[2] : ""
            AgregarCandidato(clave, codigo, desc)
        }
    }
}

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
            if partes.Length >= 1 {
                codigo := NormalizarCodigo(partes[1])
                desc := partes.Length >= 2 ? Trim(partes[2]) : ""
                if codigo != ""
                    Articulos.Push({codigo: codigo, desc: desc})
            }
        }
    }
}

CargarBase()

#HotIf WinActive(TituloVentana)
Enter:: {
    ventanaOrigen := WinExist("A")
    controlOrigen := ""

    try {
        controlOrigen := ControlGetFocus("A")
    } catch {
        controlOrigen := ""
    }

    texto := ""
    if controlOrigen != "" {
        try texto := NormalizarCodigo(ControlGetText(controlOrigen, "A"))
    }

    ; Respaldo para controles que no permiten ControlGetText.
    if texto = "" {
        clipAnterior := ClipboardAll()
        A_Clipboard := ""
        Send("^a")
        Send("^c")
        if ClipWait(0.3)
            texto := NormalizarCodigo(A_Clipboard)
        A_Clipboard := clipAnterior
    }

    if texto = "" {
        Send("{Enter}")
        return
    }

    ProcesarCodigo(texto, ventanaOrigen, controlOrigen)
}
#HotIf

ProcesarCodigo(codigoEscaneado, ventanaOrigen, controlOrigen) {
    global Codigos
    clave := NormalizarCodigo(codigoEscaneado)

    if !Codigos.Has(clave) {
        SoundBeep(300, 200)
        MostrarAsignar(clave, ventanaOrigen, controlOrigen)
        return
    }

    candidatos := Codigos[clave]

    if candidatos.Length = 1 {
        TipearCodigo(candidatos[1].codigo, ventanaOrigen, controlOrigen)
        SoundBeep(1200, 80)
    } else {
        MostrarSelector(candidatos, ventanaOrigen, controlOrigen)
    }
}

TipearCodigo(codigo, ventanaOrigen, controlOrigen) {
    codigo := NormalizarCodigo(codigo)

    if ventanaOrigen && WinExist("ahk_id " ventanaOrigen)
        WinActivate("ahk_id " ventanaOrigen)
    Sleep(50)

    escrito := false

    ; Usamos el mismo control que tenía el foco al escanear.
    if controlOrigen != "" {
        try {
            ControlFocus(controlOrigen, "ahk_id " ventanaOrigen)
            ControlSetText(codigo, controlOrigen, "ahk_id " ventanaOrigen)
            escrito := true
        }
    }

    ; Fallback para controles que no acepten ControlSetText.
    if !escrito {
        Send("^a")
        SendText(codigo)
        escrito := true
    }

    ; Fuerza refresco de formularios que actualizan precio/descripción al teclear.
    if escrito {
        Sleep(30)
        Send("{End}{Space}{Backspace}")
    }
}

MostrarSelector(candidatos, ventanaOrigen, controlOrigen) {
    SoundBeep(700, 150)

    opciones := []
    for candidato in candidatos
        opciones.Push(candidato.codigo . "  -  " . candidato.desc)

    dlg := Gui("+AlwaysOnTop", "Código ambiguo - Elegí el artículo")
    dlg.SetFont("s10")
    dlg.Add("Text",, "Este código corresponde a varios artículos:")
    lb := dlg.Add("ListBox", "w480 r8 vSel", opciones)
    btnOk := dlg.Add("Button", "Default w100", "Usar este")

    btnOk.OnEvent("Click", (*) => (
        lb.Value > 0
            ? (TipearCodigo(candidatos[lb.Value].codigo, ventanaOrigen, controlOrigen), dlg.Destroy())
            : 0
    ))

    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

MostrarAsignar(codigoEscaneado, ventanaOrigen, controlOrigen) {
    global Articulos, Codigos, ArchivoAgregados

    dlg := Gui("+AlwaysOnTop", "Código no encontrado: " codigoEscaneado)
    dlg.SetFont("s10")
    dlg.Add("Text",, "No encontré ese código. Buscá el artículo para asignárselo:")
    txt := dlg.Add("Edit", "w480 vBusqueda")
    lv := dlg.Add("ListView", "w480 r10", ["Código", "Descripción"])
    lv.ModifyCol(1, 130)
    lv.ModifyCol(2, 340)

    ActualizarLista(lv, Articulos, "")
    txt.OnEvent("Change", (*) => ActualizarLista(lv, Articulos, txt.Value))

    btnAsignar := dlg.Add("Button", "Default w150", "Asignar y tipear")
    btnAsignar.OnEvent("Click", (*) => AsignarSeleccion(dlg, lv, codigoEscaneado, ventanaOrigen, controlOrigen))
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

AsignarSeleccion(dlg, lv, codigoEscaneado, ventanaOrigen, controlOrigen) {
    global Codigos, ArchivoAgregados

    fila := lv.GetNext(0)
    if !fila {
        MsgBox("Elegí un artículo de la lista primero.")
        return
    }

    codigo := lv.GetText(fila, 1)
    desc := lv.GetText(fila, 2)
    codigoEscaneado := NormalizarCodigo(codigoEscaneado)

    AgregarCandidato(codigoEscaneado, codigo, desc)
    FileAppend(codigoEscaneado "`t" codigo "|" desc "`n", ArchivoAgregados, "UTF-8")

    dlg.Destroy()
    TipearCodigo(codigo, ventanaOrigen, controlOrigen)
    SoundBeep(1200, 80)
}

TrayTip("Lector de Códigos activo", "El Cholo Repuestos - escuchando el lector")
