Sub EjecutarProceso()
    ' Ejecutar la primera macro
    On Error GoTo ErrorHandler
    Call InsertarImagen_v2
    
    ' Preguntar si se desea imprimir después del error
    Dim respuesta As VbMsgBoxResult
    respuesta = MsgBox("¿Desea continuar con la impresión?", vbYesNo + vbQuestion, "Confirmación")
    
    If respuesta = vbYes Then
        Call ImprimirEtiquetas_v2
        Call LimpiarDatos ' Llamar a la función para limpiar imagen y celda H9
    Else
        MsgBox "Proceso cancelado por el usuario.", vbInformation, "Cancelado"
    End If
    
    Exit Sub

ErrorHandler:
    MsgBox "Error al insertar la imagen. El proceso se ha detenido.", vbCritical, "Error"
End Sub

Sub InsertarImagen_v2()
    Dim ws As Worksheet
    Dim imgPath As String
    Dim imgCell As Range
    Dim imgShape As Object
    Dim imgName As String
    Dim folderPath As String
    Dim fileExtension As String
    
    ' Definir la hoja de trabajo
    Set ws = ThisWorkbook.Sheets("impresionEtiquetas")
    
    ' Definir la ruta de la carpeta donde están las imágenes
    folderPath = "\\192.168.4.211\telefonica\Desarrollo\"
    
    ' Obtener el nombre del archivo desde la celda H9
    imgName = ws.Range("H9").Value
    
    ' Verificar si el archivo existe con diferentes extensiones
    If Dir(folderPath & imgName & ".png") <> "" Then
        fileExtension = ".png"
    ElseIf Dir(folderPath & imgName & ".jpg") <> "" Then
        fileExtension = ".jpg"
    Else
        MsgBox "No se encontró la imagen: " & folderPath & imgName, vbExclamation, "Error"
        Exit Sub
    End If
    
    ' Construir la ruta completa del archivo
    imgPath = folderPath & imgName & fileExtension
    
    ' Definir la celda donde se insertará la imagen
    Set imgCell = ws.Range("E5")
    
    ' Eliminar cualquier imagen previa en la celda E5
    Dim shp As Shape
    For Each shp In ws.Shapes
        If Not Intersect(shp.TopLeftCell, imgCell) Is Nothing Then
            shp.Delete
        End If
    Next shp
    
    ' Insertar la imagen usando AddPicture
    Set imgShape = ws.Shapes.AddPicture(imgPath, 0, 1, imgCell.Left, imgCell.Top, imgCell.Width, imgCell.Height)

    MsgBox "Imagen insertada correctamente: " & imgPath, vbInformation, "Éxito"
End Sub

Sub ImprimirEtiquetas_v2()
    Dim ws As Worksheet
    Dim cantidadBultos As Integer
    Dim i As Integer
    Dim etiquetaBase As String
    
    ' Definir la hoja de trabajo
    Set ws = ThisWorkbook.Sheets("ImpresionEtiquetas")
    
    ' Obtener la cantidad de bultos desde la celda H10
    cantidadBultos = ws.Range("H10").Value
    
    ' Verificar que la cantidad de bultos sea válida
    If cantidadBultos < 1 Then
        MsgBox "La cantidad de bultos debe ser mayor a 0", vbExclamation, "Error"
        Exit Sub
    End If
    
    ' Obtener la parte base de la etiqueta desde E9
    etiquetaBase = ws.Range("E9").Value
    
    ' Generar e imprimir las etiquetas
    For i = 1 To cantidadBultos
        ' Asignar la fórmula en C12 con la validación de C11
        ws.Range("C12").Formula = "=IF(C11=""PEDIDO NO ENCONTRADO"","""",E9 & ""/"" & " & i & ")"
        
        ' Asignar la fórmula en D5 con la numeración de los bultos
        ws.Range("D5").Formula = "=""Bultos: "" & " & i & " & ""/"" & H10"
        
        ' Imprimir la hoja
        ws.PrintOut Copies:=1, Collate:=True
    Next i
    
    ' Restaurar la fórmula original en C12
    ws.Range("C12").Formula = "=IF(C11=""PEDIDO NO ENCONTRADO"","""",E9 & ""/"" & H10)"
    
    ' Restaurar la fórmula original en D5
    ws.Range("D5").Formula = "=""Bultos: "" & H10"
    
    MsgBox "Impresión de etiquetas completada.", vbInformation, "Proceso Finalizado"
End Sub

Sub LimpiarDatos()
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets("ImpresionEtiquetas")
    
    ' Eliminar la imagen en la celda E5
    Dim shp As Shape
    For Each shp In ws.Shapes
        If Not Intersect(shp.TopLeftCell, ws.Range("E5")) Is Nothing Then
            shp.Delete
        End If
    Next shp
    
    ' Borrar el dato en H9
    ws.Range("H9").ClearContents
    
    MsgBox "Datos limpiados correctamente.", vbInformation, "Limpieza Completa"
End Sub


