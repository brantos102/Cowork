Option Explicit

'==============================================================================
' Impresion de etiquetas con imagen - hoja "ImpresionEtiquetas"
'------------------------------------------------------------------------------
' Correcciones respecto de la version original:
'
'  1. AddPicture en UNA sola linea y con literales 0 / 1 en lugar de
'     msoFalse / msoCTrue: evita el error de compilacion cuando la referencia
'     a la Microsoft Office Object Library esta rota.
'  2. La ruta de la imagen se arma con el nombre REAL que devuelve Dir, no
'     reconstruyendolo: asi no falla por comodines, mayusculas o variantes.
'  3. Si AddPicture falla igual, se avisa con la ruta exacta y se ofrece
'     imprimir sin imagen, en vez de abortar todo.
'  4. I10 e I11 se leen resolviendo la celda ancla si estan combinadas: una
'     celda combinada que no es la de arriba-izquierda devuelve Empty.
'  5. Validacion de bultos que distingue celda vacia, error de formula y
'     texto invalido, y muestra el contenido real en el mensaje.
'  6. El borrado de shapes recorre la coleccion HACIA ATRAS: al borrar dentro
'     de un For Each la coleccion se reindexa y se salteaban shapes.
'  7. ws.Calculate antes de cada PrintOut: con calculo manual se imprimian
'     las etiquetas con el numero de bulto anterior.
'  8. Manejador de errores con Resume: las formulas se restauran siempre,
'     incluso si la impresion falla a mitad de camino.
'==============================================================================

Sub InsertarEImprimirEtiquetas()

    ' Valores de MsoTriState como literales (sin dependencia de librerias)
    Const PIC_LINK_TO_FILE  As Long = 0   ' msoFalse  : no vincular al archivo
    Const PIC_SAVE_WITH_DOC As Long = 1   ' msoCTrue  : guardar dentro del libro

    Dim ws            As Worksheet
    Dim imgCell       As Range
    Dim celdaImagen   As Range
    Dim celdaBultos   As Range
    Dim imgShape      As Object
    Dim folderPath    As String
    Dim imgName       As String
    Dim nombreReal    As String
    Dim imgPath       As String
    Dim textoBultos   As String
    Dim cantidadBultos As Long
    Dim i             As Long
    Dim k             As Long
    Dim errNum        As Long
    Dim errDesc       As String
    Dim continuar     As VbMsgBoxResult

    On Error GoTo ManejoError

    Set ws = ThisWorkbook.Sheets("ImpresionEtiquetas")
    Set imgCell = ws.Range("F5")

    folderPath = "\\192.168.4.211\telefonica\"

    '--------------------------------------------------------------------------
    ' 1. Leer las celdas de entrada (resolviendo combinadas)
    '--------------------------------------------------------------------------
    Set celdaImagen = ws.Range("I10")
    If celdaImagen.MergeCells Then Set celdaImagen = celdaImagen.MergeArea.Cells(1, 1)
    imgName = Trim$(Replace(CStr(celdaImagen.Text), Chr(160), ""))

    Set celdaBultos = ws.Range("I11")
    If celdaBultos.MergeCells Then Set celdaBultos = celdaBultos.MergeArea.Cells(1, 1)

    '--------------------------------------------------------------------------
    ' 2. Validar la cantidad de bultos ANTES de insertar o imprimir nada
    '--------------------------------------------------------------------------
    If IsError(celdaBultos.Value) Then
        MsgBox "La celda " & celdaBultos.Address(False, False) & " devuelve un error de formula: " & _
               celdaBultos.Text & vbCrLf & vbCrLf & _
               "Verifique que el pedido exista antes de imprimir.", _
               vbExclamation, "Error"
        Exit Sub
    End If

    textoBultos = Trim$(Replace(CStr(celdaBultos.Text), Chr(160), ""))

    If Len(textoBultos) = 0 Then
        MsgBox "La celda " & celdaBultos.Address(False, False) & " esta vacia." & vbCrLf & _
               "Ingrese la cantidad de bultos.", vbExclamation, "Error"
        Exit Sub
    End If

    If Not IsNumeric(textoBultos) Then
        MsgBox "La celda " & celdaBultos.Address(False, False) & " no contiene una cantidad valida." & vbCrLf & vbCrLf & _
               "Contenido actual : [" & celdaBultos.Text & "]" & vbCrLf & _
               "Formula          : [" & celdaBultos.Formula & "]", _
               vbExclamation, "Error"
        Exit Sub
    End If

    cantidadBultos = CLng(textoBultos)

    If cantidadBultos < 1 Then
        MsgBox "La cantidad de bultos debe ser mayor a 0", vbExclamation, "Error"
        Exit Sub
    End If

    '--------------------------------------------------------------------------
    ' 3. Buscar la imagen. Se guarda el NOMBRE REAL devuelto por Dir
    '--------------------------------------------------------------------------
    nombreReal = ""

    If Len(imgName) > 0 Then
        On Error Resume Next                       ' la ruta de red puede no responder
        nombreReal = Dir(folderPath & imgName & ".png")
        If nombreReal = "" Then nombreReal = Dir(folderPath & imgName & ".jpg")
        On Error GoTo ManejoError
    End If

    If nombreReal = "" Then
        continuar = MsgBox("No se encontro la imagen." & vbCrLf & vbCrLf & _
                           "Carpeta : " & folderPath & vbCrLf & _
                           "Nombre  : [" & imgName & "]" & vbCrLf & vbCrLf & _
                           "Desea continuar con la impresion?", _
                           vbExclamation + vbYesNo, "Imagen no encontrada")
        If continuar = vbNo Then Exit Sub
    End If

    Application.ScreenUpdating = False

    '--------------------------------------------------------------------------
    ' 4. Borrar imagenes previas en F5 (recorrido hacia atras)
    '--------------------------------------------------------------------------
    For k = ws.Shapes.Count To 1 Step -1
        If Not Intersect(ws.Shapes(k).TopLeftCell, imgCell) Is Nothing Then
            ws.Shapes(k).Delete
        End If
    Next k

    '--------------------------------------------------------------------------
    ' 5. Insertar la imagen
    '--------------------------------------------------------------------------
    If nombreReal <> "" Then
        imgPath = folderPath & nombreReal

        On Error Resume Next
        Set imgShape = ws.Shapes.AddPicture(imgPath, PIC_LINK_TO_FILE, PIC_SAVE_WITH_DOC, imgCell.Left, imgCell.Top, imgCell.Width, imgCell.Height)
        errNum = Err.Number
        errDesc = Err.Description
        Err.Clear
        On Error GoTo ManejoError

        If errNum <> 0 Then
            continuar = MsgBox("No se pudo insertar la imagen:" & vbCrLf & vbCrLf & _
                               imgPath & vbCrLf & vbCrLf & _
                               "Error " & errNum & ": " & errDesc & vbCrLf & vbCrLf & _
                               "Desea imprimir sin imagen?", _
                               vbExclamation + vbYesNo, "Imagen no disponible")
            If continuar = vbNo Then GoTo LimpiarYSalir
        End If
    End If

    '--------------------------------------------------------------------------
    ' 6. Generar e imprimir las etiquetas
    '--------------------------------------------------------------------------
    For i = 1 To cantidadBultos
        ws.Range("D13").Formula = "=IF(C12=""PEDIDO NO ENCONTRADO"","""",""*"" & C7 & ""/"" & " & i & " & ""*"" )"
        ws.Range("D5").Formula = "=""Bultos: "" & " & i & " & ""/"" & I11"

        ws.Calculate                               ' fuerza el recalculo antes de imprimir
        ws.PrintOut Copies:=1, Collate:=True
    Next i

    Application.ScreenUpdating = True
    MsgBox "Impresion de etiquetas completada." & vbCrLf & _
           "Etiquetas impresas: " & cantidadBultos, _
           vbInformation, "Proceso Finalizado"

'------------------------------------------------------------------------------
LimpiarYSalir:
    On Error Resume Next

    ' Restaurar las formulas originales
    If Not ws Is Nothing Then
        ws.Range("D13").Formula = "=IF(C12=""PEDIDO NO ENCONTRADO"","""",""*"" & C7 & ""/"" & I11 & ""*"" )"
        ws.Range("D5").Formula = "=""Bultos: "" & I11"

        ' Eliminar la imagen insertada
        If Not imgCell Is Nothing Then
            For k = ws.Shapes.Count To 1 Step -1
                If Not Intersect(ws.Shapes(k).TopLeftCell, imgCell) Is Nothing Then
                    ws.Shapes(k).Delete
                End If
            Next k
        End If
    End If

    ' Limpiar el nombre de imagen (en la celda ancla si esta combinada)
    If Not celdaImagen Is Nothing Then celdaImagen.ClearContents

    Application.ScreenUpdating = True
    Exit Sub

'------------------------------------------------------------------------------
ManejoError:
    errNum = Err.Number
    errDesc = Err.Description
    Application.ScreenUpdating = True
    MsgBox "Error " & errNum & ": " & errDesc, vbCritical, "Error inesperado"
    Resume LimpiarYSalir

End Sub


'==============================================================================
' MACROS DE DIAGNOSTICO (opcionales). Ejecutar con F5 y ver el resultado en la
' ventana Inmediato del editor VBA (Ctrl + G).
'==============================================================================

Sub DiagnosticarBultos()
    Dim c As Range
    Set c = ThisWorkbook.Sheets("ImpresionEtiquetas").Range("I11")

    Debug.Print "---------------- I11 ----------------"
    Debug.Print "Celda          : " & c.Address
    Debug.Print "Combinada      : " & c.MergeCells
    If c.MergeCells Then
        Debug.Print "  Area         : " & c.MergeArea.Address
        Debug.Print "  Celda ancla  : " & c.MergeArea.Cells(1, 1).Address
    End If
    Debug.Print "Texto mostrado : [" & c.Text & "]"
    Debug.Print "Formula        : [" & c.Formula & "]"
    Debug.Print "TypeName(Value): " & TypeName(c.Value)
    Debug.Print "Es error       : " & IsError(c.Value)
    If Not IsError(c.Value) Then
        Debug.Print "IsNumeric      : " & IsNumeric(c.Value)
    End If
End Sub


Sub DiagnosticarImagen()
    Dim folderPath As String, imgName As String, p As String, encontrado As String
    Dim c As Range

    folderPath = "\\192.168.4.211\telefonica\"

    Set c = ThisWorkbook.Sheets("ImpresionEtiquetas").Range("I10")
    If c.MergeCells Then Set c = c.MergeArea.Cells(1, 1)
    imgName = Trim$(Replace(CStr(c.Text), Chr(160), ""))

    Debug.Print "---------------- I10 ----------------"
    Debug.Print "Celda ancla      : " & c.Address
    Debug.Print "Nombre           : [" & imgName & "]   largo=" & Len(imgName)
    Debug.Print "Carpeta accesible: " & CStr(Dir(folderPath, vbDirectory) <> "")

    encontrado = Dir(folderPath & imgName & ".png")
    Debug.Print "Busqueda .png    -> [" & encontrado & "]"
    If encontrado = "" Then
        encontrado = Dir(folderPath & imgName & ".jpg")
        Debug.Print "Busqueda .jpg    -> [" & encontrado & "]"
    End If

    If encontrado <> "" Then
        p = folderPath & encontrado
        Debug.Print "Ruta reconstruida: " & folderPath & imgName & ".png"
        Debug.Print "Ruta REAL        : " & p
        Debug.Print "Tamano           : " & FileLen(p) & " bytes"
    End If
End Sub
