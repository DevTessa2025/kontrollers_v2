import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  // Seleccionar imagen desde galería o cámara con compresión más suave
  static Future<String?> pickAndCompressImage({
    required ImageSource source,
    int maxWidth = 1200,        // Aumentado de 800 a 1200
    int maxHeight = 900,        // Aumentado de 600 a 900
    int quality = 85,           // Aumentado de 70 a 85
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,    // Esta calidad ya es mejor ahora
      );

      if (pickedFile == null) return null;

      // Leer el archivo
      Uint8List imageBytes = await pickedFile.readAsBytes();
      
      // Comprimir la imagen con parámetros mejorados
      String compressedBase64 = await compressImageToBase64(
        imageBytes,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );

      return compressedBase64;
    } catch (e) {
      print('Error seleccionando imagen: $e');
      return null;
    }
  }

  // Comprimir imagen y convertir a base64 con mejor calidad
  static Future<String> compressImageToBase64(
    Uint8List imageBytes, {
    int maxWidth = 1200,        // Aumentado
    int maxHeight = 900,        // Aumentado
    int quality = 85,           // Aumentado
  }) async {
    try {
      // Decodificar la imagen
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('No se pudo decodificar la imagen');

      // Solo redimensionar si es realmente necesario (imágenes muy grandes)
      if (image.width > maxWidth || image.height > maxHeight) {
        // Usar algoritmo de interpolación de mejor calidad
        image = img.copyResize(
          image,
          width: image.width > maxWidth ? maxWidth : null,
          height: image.height > maxHeight ? maxHeight : null,
          maintainAspect: true,
          interpolation: img.Interpolation.cubic, // Mejor algoritmo de interpolación
        );
      }

      // Comprimir como JPEG con mejor calidad
      List<int> compressedBytes = img.encodeJpg(
        image, 
        quality: quality  // Ahora usa 85 en lugar de 70
      );

      // Convertir a base64
      String base64String = base64Encode(compressedBytes);
      
      print('Imagen comprimida: ${compressedBytes.length} bytes (${(compressedBytes.length / 1024).toStringAsFixed(1)} KB), Base64: ${base64String.length} caracteres');
      
      return base64String;
    } catch (e) {
      print('Error comprimiendo imagen: $e');
      rethrow;
    }
  }

  // Convertir base64 a Uint8List para mostrar
  static Uint8List base64ToBytes(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error decodificando base64: $e');
      rethrow;
    }
  }

  // Versión para casos donde necesites máxima calidad
  static Future<String?> pickHighQualityImage({
    required ImageSource source,
    int maxWidth = 1920,        // Resolución más alta
    int maxHeight = 1440,       // Resolución más alta
    int quality = 95,           // Calidad muy alta
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );

      if (pickedFile == null) return null;

      // Leer el archivo
      Uint8List imageBytes = await pickedFile.readAsBytes();
      
      // Comprimir la imagen con alta calidad
      String compressedBase64 = await compressImageToBase64(
        imageBytes,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );

      return compressedBase64;
    } catch (e) {
      print('Error seleccionando imagen de alta calidad: $e');
      return null;
    }
  }

  // Diálogo mejorado con opción de calidad
  static Future<Map<String, dynamic>?> showImageSourceDialog(context) async {
    return await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Seleccionar Imagen',
            style: TextStyle(
              color: Colors.red[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.red[700]),
                title: Text('Tomar Foto'),
                subtitle: Text('Calidad estándar'),
                onTap: () {
                  Navigator.pop(context, {
                    'source': ImageSource.camera,
                    'highQuality': false
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: Colors.red[500]),
                title: Text('Tomar Foto HD'),
                subtitle: Text('Mayor calidad y tamaño'),
                onTap: () {
                  Navigator.pop(context, {
                    'source': ImageSource.camera,
                    'highQuality': true
                  });
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.red[700]),
                title: Text('Desde Galería'),
                subtitle: Text('Calidad estándar'),
                onTap: () {
                  Navigator.pop(context, {
                    'source': ImageSource.gallery,
                    'highQuality': false
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: Colors.red[500]),
                title: Text('Desde Galería HD'),
                subtitle: Text('Mayor calidad y tamaño'),
                onTap: () {
                  Navigator.pop(context, {
                    'source': ImageSource.gallery,
                    'highQuality': true
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  // Obtener tamaño estimado de la imagen en KB
  static double getImageSizeKB(String base64String) {
    try {
      int sizeInBytes = (base64String.length * 3) ~/ 4;
      return sizeInBytes / 1024;
    } catch (e) {
      return 0.0;
    }
  }

  // Validar si el string es una imagen base64 válida
  static bool isValidBase64Image(String base64String) {
    try {
      if (base64String.isEmpty) return false;
      
      Uint8List bytes = base64Decode(base64String);
      img.Image? image = img.decodeImage(bytes);
      
      return image != null;
    } catch (e) {
      return false;
    }
  }

  // Crear thumbnail de la imagen con mejor calidad
  static Future<String> createThumbnail(
    String base64String, {
    int thumbnailSize = 200,    // Aumentado de 150 a 200
    int quality = 80,           // Aumentado de 60 a 80
  }) async {
    try {
      Uint8List imageBytes = base64Decode(base64String);
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) throw Exception('No se pudo decodificar la imagen');

      // Crear thumbnail cuadrado con mejor algoritmo
      img.Image thumbnail = img.copyResizeCropSquare(
        image, 
        size: thumbnailSize,
        interpolation: img.Interpolation.cubic, // Mejor interpolación
      );
      
      // Comprimir como JPEG con mejor calidad
      List<int> thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);
      
      return base64Encode(thumbnailBytes);
    } catch (e) {
      print('Error creando thumbnail: $e');
      return base64String; // Retornar imagen original si falla
    }
  }

  // Método para optimizar imagen existente (si necesitas reconvertir)
  static Future<String> optimizeExistingImage(
    String base64String, {
    int quality = 85,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      Uint8List imageBytes = base64Decode(base64String);
      return await compressImageToBase64(
        imageBytes,
        maxWidth: maxWidth ?? 1200,
        maxHeight: maxHeight ?? 900,
        quality: quality,
      );
    } catch (e) {
      print('Error optimizando imagen existente: $e');
      return base64String; // Retornar original si falla
    }
  }

  // Obtener información detallada de la imagen
  static Map<String, dynamic> getImageInfo(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        return {
          'valid': false,
          'error': 'No se pudo decodificar la imagen'
        };
      }

      double sizeKB = getImageSizeKB(base64String);
      
      return {
        'valid': true,
        'width': image.width,
        'height': image.height,
        'sizeKB': sizeKB,
        'sizeMB': sizeKB / 1024,
        'aspectRatio': image.width / image.height,
        'resolution': '${image.width}x${image.height}',
        'estimatedQuality': sizeKB > 500 ? 'Alta' : sizeKB > 200 ? 'Media' : 'Baja',
      };
    } catch (e) {
      return {
        'valid': false,
        'error': 'Error procesando imagen: $e'
      };
    }
  }
}