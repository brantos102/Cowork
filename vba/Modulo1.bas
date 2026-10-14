Sub InsertarImagen()
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
    folderPath = "\\192.168.4.211\telefonica\"
    
    ' Obtener el nombre del archivo desde la celda H9
    imgName = ws.Range("H9").Value
    
    ' Verificar si el archivo existe con diferentes extensiones
    If Dir(folderPath & imgName & ".png") <> "" Then
        fileExtension = ".png"
    ElseIf Dir(folderPath & imgName & ".jpg") <> "" Then
        fileExtension = ".jpg"
    Else
        Err.Raise 1001, "InsertarImagen", "No se encontró la imagen"
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


