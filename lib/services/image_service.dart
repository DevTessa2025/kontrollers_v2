import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  // Comprimir imagen y convertir a base64 con calidad balanceada
  static Future<String> compressImageToBase64(
    Uint8List imageBytes, {
    int maxWidth = 1200,        
    int maxHeight = 900,        
    int quality = 85,           
  }) async {
    try {
      // Decodificar la imagen
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('No se pudo decodificar la imagen');

      // Solo redimensionar si es realmente necesario (imágenes muy grandes)
      if (image.width > maxWidth || image.height > maxHeight) {
        // Usar algoritmo de interpolación de buena calidad
        image = img.copyResize(
          image,
          width: image.width > maxWidth ? maxWidth : null,
          height: image.height > maxHeight ? maxHeight : null,
          maintainAspect: true,
          interpolation: img.Interpolation.cubic, // Buena interpolación
        );
      }

      // Comprimir como JPEG con calidad balanceada
      List<int> compressedBytes = img.encodeJpg(
        image, 
        quality: quality
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

  // Crear thumbnail de la imagen con buena calidad
  static Future<String> createThumbnail(
    String base64String, {
    int thumbnailSize = 200,    
    int quality = 80,           
  }) async {
    try {
      Uint8List imageBytes = base64Decode(base64String);
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) throw Exception('No se pudo decodificar la imagen');

      // Crear thumbnail cuadrado con buen algoritmo
      img.Image thumbnail = img.copyResizeCropSquare(
        image, 
        size: thumbnailSize,
        interpolation: img.Interpolation.cubic,
      );
      
      // Comprimir como JPEG con buena calidad
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

  static Future<String> convertImageToBase64(Uint8List imageBytes) async {
    try {
      String base64String = base64Encode(imageBytes);
      return base64String;
    } catch (e) {
      throw Exception('Error convertiendo imagen a base64: $e');
    }
  }

  // Mostrar imagen desde base64
  static Widget displayBase64Image(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: Colors.grey[500],
                  size: 50,
                ),
                SizedBox(height: 8),
                Text(
                  'Error cargando imagen',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              color: Colors.red[500],
              size: 50,
            ),
            SizedBox(height: 8),
            Text(
              'Imagen inválida',
              style: TextStyle(color: Colors.red[600]),
            ),
          ],
        ),
      );
    }
  }

  // Convertir base64 a bytes
  static Uint8List base64ToBytes(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      throw Exception('Error decodificando base64: $e');
    }
  }

  // Obtener información de la imagen
  static Map<String, dynamic> getImageInfo(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      double sizeKB = bytes.length / 1024;
      
      return {
        'sizeKB': sizeKB,
        'sizeBytes': bytes.length,
        'resolution': '${bytes.length} bytes',
      };
    } catch (e) {
      return {
        'sizeKB': 0.0,
        'sizeBytes': 0,
        'resolution': 'Desconocida',
      };
    }
  }

  // Diálogo para seleccionar fuente de imagen
  static Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  // Seleccionar y comprimir imagen
  static Future<String?> pickAndCompressImage({required ImageSource source}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        Uint8List imageBytes = await image.readAsBytes();
        return await convertImageToBase64(imageBytes);
      }
      return null;
    } catch (e) {
      throw Exception('Error seleccionando imagen: $e');
    }
  }
}