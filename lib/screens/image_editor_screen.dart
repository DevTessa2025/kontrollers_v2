import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/image_service.dart';

class ImageEditorScreen extends StatefulWidget {
  final String base64Image;

  ImageEditorScreen({required this.base64Image});

  @override
  _ImageEditorScreenState createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();
  List<DrawingPoint> drawingPoints = [];
  Color selectedColor = Colors.red;
  double strokeWidth = 3.0;
  bool isDrawing = false;
  late Uint8List originalImageBytes;
  ui.Image? backgroundImage;
  Size? imageDisplaySize;
  
  // Variables para el zoom y pan
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    originalImageBytes = ImageService.base64ToBytes(widget.base64Image);
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    final codec = await ui.instantiateImageCodec(originalImageBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      backgroundImage = frame.image;
      _calculateImageDisplaySize();
    });
  }

  void _calculateImageDisplaySize() {
    if (backgroundImage == null) return;
    
    // Obtener el tamaño de la pantalla disponible para el canvas
    final screenSize = MediaQuery.of(context).size;
    final availableHeight = screenSize.height - 280; // Todos los controles + márgenes
    final availableWidth = screenSize.width - 50; // Márgenes laterales + borde
    
    // Calcular el tamaño de visualización manteniendo la proporción
    double imageRatio = backgroundImage!.width / backgroundImage!.height;
    double screenRatio = availableWidth / availableHeight;
    
    if (imageRatio > screenRatio) {
      // La imagen es más ancha, ajustar por ancho
      imageDisplaySize = Size(
        availableWidth,
        availableWidth / imageRatio,
      );
    } else {
      // La imagen es más alta, ajustar por altura
      imageDisplaySize = Size(
        availableHeight * imageRatio,
        availableHeight,
      );
    }
    
    // Asegurar que la imagen no sea más pequeña que 200px
    if (imageDisplaySize!.width < 200 || imageDisplaySize!.height < 200) {
      if (imageDisplaySize!.width < imageDisplaySize!.height) {
        double factor = 200 / imageDisplaySize!.width;
        imageDisplaySize = Size(200, imageDisplaySize!.height * factor);
      } else {
        double factor = 200 / imageDisplaySize!.height;
        imageDisplaySize = Size(imageDisplaySize!.width * factor, 200);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Editor de Imagen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.undo, color: Colors.white),
            onPressed: _undo,
            tooltip: 'Deshacer',
          ),
          IconButton(
            icon: Icon(Icons.clear_all, color: Colors.white),
            onPressed: _clearDrawing,
            tooltip: 'Limpiar dibujos',
          ),
          IconButton(
            icon: Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: _resetPosition,
            tooltip: 'Centrar imagen',
          ),
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _saveImage,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Herramientas de dibujo
          Container(
            height: 80,
            color: Colors.grey[900],
            child: Column(
              children: [
                // Colores
                Container(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      _buildColorButton(Colors.red),
                      _buildColorButton(Colors.blue),
                      _buildColorButton(Colors.green),
                      _buildColorButton(Colors.yellow),
                      _buildColorButton(Colors.orange),
                      _buildColorButton(Colors.purple),
                      _buildColorButton(Colors.pink),
                      _buildColorButton(Colors.cyan),
                      _buildColorButton(Colors.white),
                      _buildColorButton(Colors.black),
                    ],
                  ),
                ),
                // Control de grosor
                Container(
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.brush, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Grosor: ${strokeWidth.toInt()}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: strokeWidth,
                          min: 1.0,
                          max: 15.0,
                          divisions: 14,
                          activeColor: Colors.red[600],
                          inactiveColor: Colors.grey[600],
                          onChanged: (value) {
                            setState(() {
                              strokeWidth = value;
                            });
                          },
                        ),
                      ),
                      if (isDrawing)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: selectedColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Dibujando',
                            style: TextStyle(
                              color: selectedColor == Colors.white ? Colors.black : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Control de Zoom
          Container(
            height: 50,
            color: Colors.grey[850],
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.zoom_out, color: Colors.white, size: 20),
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 0.5,
                    max: 4.0,
                    divisions: 35,
                    activeColor: Colors.blue[400],
                    inactiveColor: Colors.grey[600],
                    onChanged: (value) {
                      setState(() {
                        _scale = value;
                        // Ajustar offset al cambiar zoom para mantener centrado
                        _offset = _constrainOffset(_offset);
                      });
                    },
                  ),
                ),
                Icon(Icons.zoom_in, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(_scale * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Instrucciones
          Container(
            height: 30,
            color: Colors.grey[800],
            child: Center(
              child: Text(
                '1 dedo: Dibujar  •  2 dedos: Mover imagen',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Canvas de dibujo
          Expanded(
            child: Container(
              key: _canvasKey,
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Margen externo
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!, width: 1), // Borde visual
              ),
              child: ClipRRect( // CORRECCIÓN: ClipRRect con border radius
                borderRadius: BorderRadius.circular(7), // Ligeramente menor que el container
                child: backgroundImage != null && imageDisplaySize != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: GestureDetector(
                              onScaleStart: (details) {
                                if (details.pointerCount == 1) {
                                  // Un dedo: verificar si está en la imagen y empezar a dibujar
                                  Offset localPoint = _globalToLocal(details.localFocalPoint, constraints);
                                  if (_isPointInImageBounds(localPoint, constraints)) {
                                    setState(() {
                                      isDrawing = true;
                                      Offset imageCoordinate = _localToImageCoordinate(localPoint, constraints);
                                      drawingPoints.add(
                                        DrawingPoint(
                                          offset: imageCoordinate,
                                          paint: Paint()
                                            ..color = selectedColor
                                            ..strokeWidth = strokeWidth
                                            ..strokeCap = StrokeCap.round,
                                        ),
                                      );
                                    });
                                  }
                                }
                              },
                              onScaleUpdate: (details) {
                                if (details.pointerCount == 1 && isDrawing) {
                                  // Un dedo: continuar dibujando
                                  Offset localPoint = _globalToLocal(details.localFocalPoint, constraints);
                                  if (_isPointInImageBounds(localPoint, constraints)) {
                                    setState(() {
                                      Offset imageCoordinate = _localToImageCoordinate(localPoint, constraints);
                                      drawingPoints.add(
                                        DrawingPoint(
                                          offset: imageCoordinate,
                                          paint: Paint()
                                            ..color = selectedColor
                                            ..strokeWidth = strokeWidth
                                            ..strokeCap = StrokeCap.round,
                                        ),
                                      );
                                    });
                                  }
                                } else if (details.pointerCount == 2) {
                                  // Dos dedos: mover imagen
                                  setState(() {
                                    isDrawing = false;
                                    _offset = _constrainOffset(_offset + details.focalPointDelta);
                                  });
                                }
                              },
                              onScaleEnd: (details) {
                                if (isDrawing) {
                                  setState(() {
                                    isDrawing = false;
                                    drawingPoints.add(DrawingPoint(offset: null, paint: Paint()));
                                  });
                                }
                              },
                              child: Container(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: CustomPaint(
                                  painter: ImageCanvasPainter(
                                    backgroundImage: backgroundImage!,
                                    drawingPoints: drawingPoints,
                                    imageDisplaySize: imageDisplaySize!,
                                    scale: _scale,
                                    offset: _offset,
                                    canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
                                  ),
                                  child: RepaintBoundary(
                                    key: _repaintBoundaryKey,
                                    child: Container(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.red[600]),
                            SizedBox(height: 16),
                            Text(
                              'Cargando imagen...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Botones de acción
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.cancel, color: Colors.white),
                    label: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[600]!),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveImage,
                    icon: Icon(Icons.check, color: Colors.white),
                    label: Text(
                      'Aplicar Cambios',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Convertir coordenadas globales a locales del canvas
  Offset _globalToLocal(Offset globalPoint, BoxConstraints constraints) {
    return globalPoint;
  }

  // Convertir coordenadas locales del canvas a coordenadas de imagen original
  Offset _localToImageCoordinate(Offset localPoint, BoxConstraints constraints) {
    // Calcular el centro del canvas
    Offset canvasCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    
    // Calcular la posición de la imagen en el canvas
    Offset imageCenter = canvasCenter + _offset;
    Size scaledImageSize = Size(imageDisplaySize!.width * _scale, imageDisplaySize!.height * _scale);
    
    // Punto relativo a la esquina superior izquierda de la imagen
    Offset relativeToImage = localPoint - (imageCenter - Offset(scaledImageSize.width / 2, scaledImageSize.height / 2));
    
    // Convertir a coordenadas de imagen original
    double imageX = (relativeToImage.dx / scaledImageSize.width) * backgroundImage!.width;
    double imageY = (relativeToImage.dy / scaledImageSize.height) * backgroundImage!.height;
    
    return Offset(
      imageX.clamp(0.0, backgroundImage!.width.toDouble()),
      imageY.clamp(0.0, backgroundImage!.height.toDouble()),
    );
  }

  // Verificar si un punto está dentro de los límites de la imagen
  bool _isPointInImageBounds(Offset localPoint, BoxConstraints constraints) {
    // Calcular el centro del canvas
    Offset canvasCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    
    // Calcular la posición de la imagen en el canvas
    Offset imageCenter = canvasCenter + _offset;
    Size scaledImageSize = Size(imageDisplaySize!.width * _scale, imageDisplaySize!.height * _scale);
    
    // Calcular los límites de la imagen
    double left = imageCenter.dx - scaledImageSize.width / 2;
    double right = imageCenter.dx + scaledImageSize.width / 2;
    double top = imageCenter.dy - scaledImageSize.height / 2;
    double bottom = imageCenter.dy + scaledImageSize.height / 2;
    
    return localPoint.dx >= left && 
           localPoint.dx <= right && 
           localPoint.dy >= top && 
           localPoint.dy <= bottom;
  }

  // Limitar el offset para mantener la imagen visible dentro del canvas
  Offset _constrainOffset(Offset newOffset) {
    if (imageDisplaySize == null) return newOffset;
    
    final screenSize = MediaQuery.of(context).size;
    final canvasWidth = screenSize.width - 40; // 20px padding cada lado
    final canvasHeight = screenSize.height - 270; // Altura de controles
    
    Size scaledImageSize = Size(imageDisplaySize!.width * _scale, imageDisplaySize!.height * _scale);
    
    // Si la imagen es menor que el canvas, centrarla
    if (scaledImageSize.width <= canvasWidth && scaledImageSize.height <= canvasHeight) {
      return Offset.zero; // Mantener centrada
    }
    
    // Calcular límites máximos de movimiento
    double maxOffsetX = 0;
    double minOffsetX = 0;
    double maxOffsetY = 0;
    double minOffsetY = 0;
    
    if (scaledImageSize.width > canvasWidth) {
      maxOffsetX = (scaledImageSize.width - canvasWidth) / 2;
      minOffsetX = -maxOffsetX;
    }
    
    if (scaledImageSize.height > canvasHeight) {
      maxOffsetY = (scaledImageSize.height - canvasHeight) / 2;
      minOffsetY = -maxOffsetY;
    }
    
    return Offset(
      newOffset.dx.clamp(minOffsetX, maxOffsetX),
      newOffset.dy.clamp(minOffsetY, maxOffsetY),
    );
  }

  void _resetPosition() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  Widget _buildColorButton(Color color) {
    bool isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey[600]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, color: color == Colors.white ? Colors.black : Colors.white, size: 16)
            : null,
      ),
    );
  }

  void _undo() {
    if (drawingPoints.isNotEmpty) {
      setState(() {
        do {
          drawingPoints.removeLast();
        } while (drawingPoints.isNotEmpty && drawingPoints.last.offset != null);
      });
    }
  }

  void _clearDrawing() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpiar Dibujos'),
        content: Text('¿Está seguro que desea eliminar todos los dibujos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                drawingPoints.clear();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: Text('Limpiar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      canvas.drawImage(backgroundImage!, Offset.zero, Paint());
      
      for (int i = 0; i < drawingPoints.length - 1; i++) {
        DrawingPoint currentPoint = drawingPoints[i];
        DrawingPoint nextPoint = drawingPoints[i + 1];

        if (currentPoint.offset != null && nextPoint.offset != null) {
          canvas.drawLine(
            currentPoint.offset!,
            nextPoint.offset!,
            currentPoint.paint,
          );
        }
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        backgroundImage!.width,
        backgroundImage!.height,
      );
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List imageBytes = byteData.buffer.asUint8List();
        String base64Edited = await ImageService.compressImageToBase64(
          imageBytes,
          quality: 85,
        );
        Navigator.pop(context, base64Edited);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la imagen: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }
}

class DrawingPoint {
  final Offset? offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class ImageCanvasPainter extends CustomPainter {
  final ui.Image backgroundImage;
  final List<DrawingPoint> drawingPoints;
  final Size imageDisplaySize;
  final double scale;
  final Offset offset;
  final Size canvasSize;

  ImageCanvasPainter({
    required this.backgroundImage,
    required this.drawingPoints,
    required this.imageDisplaySize,
    required this.scale,
    required this.offset,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calcular posición y tamaño de la imagen en el canvas
    Offset canvasCenter = Offset(canvasSize.width / 2, canvasSize.height / 2);
    Offset imageCenter = canvasCenter + offset;
    Size scaledImageSize = Size(imageDisplaySize.width * scale, imageDisplaySize.height * scale);
    
    // Dibujar la imagen de fondo
    Rect imageRect = Rect.fromCenter(
      center: imageCenter,
      width: scaledImageSize.width,
      height: scaledImageSize.height,
    );
    
    canvas.drawImageRect(
      backgroundImage,
      Rect.fromLTWH(0, 0, backgroundImage.width.toDouble(), backgroundImage.height.toDouble()),
      imageRect,
      Paint(),
    );

    // Dibujar los trazos
    for (int i = 0; i < drawingPoints.length - 1; i++) {
      DrawingPoint currentPoint = drawingPoints[i];
      DrawingPoint nextPoint = drawingPoints[i + 1];

      if (currentPoint.offset != null && nextPoint.offset != null) {
        // Convertir coordenadas de imagen a coordenadas de canvas
        Offset currentCanvas = _imageToCanvasCoordinate(currentPoint.offset!, imageRect);
        Offset nextCanvas = _imageToCanvasCoordinate(nextPoint.offset!, imageRect);
        
        // Crear paint escalado
        Paint canvasPaint = Paint()
          ..color = currentPoint.paint.color
          ..strokeWidth = currentPoint.paint.strokeWidth * scale
          ..strokeCap = currentPoint.paint.strokeCap;
        
        canvas.drawLine(currentCanvas, nextCanvas, canvasPaint);
      }
    }
  }

  Offset _imageToCanvasCoordinate(Offset imagePoint, Rect imageRect) {
    double x = imageRect.left + (imagePoint.dx / backgroundImage.width) * imageRect.width;
    double y = imageRect.top + (imagePoint.dy / backgroundImage.height) * imageRect.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}