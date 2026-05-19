import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servico para demonstracao de DETECCAO facial, nao autenticacao facial.
/// Detectar rosto significa localizar faces em uma imagem; autenticar significa
/// comparar identidade com seguranca, normalmente pelo sistema operacional.
class FaceDetectionService {
  final ImagePicker _picker = ImagePicker();

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  Future<XFile?> takePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return null;

    return _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
  }

  Future<List<Face>> detectFaces(File file) async {
    final inputImage = InputImage.fromFile(file);
    return _detector.processImage(inputImage);
  }

  Future<void> close() => _detector.close();
}
