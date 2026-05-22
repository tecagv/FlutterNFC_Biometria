import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado da captura de foto pela camera.
enum PhotoCaptureStatus {
  taken,
  permissionDenied,
  permissionPermanentlyDenied,
  canceled,
}

/// Pacote retornado por [FaceDetectionService.takePhoto].
class PhotoCaptureResult {
  const PhotoCaptureResult(this.status, [this.file]);

  final PhotoCaptureStatus status;
  final XFile? file;
}

/// Servico para demonstracao de DETECCAO facial, nao autenticacao facial.
/// Detectar rosto significa localizar faces em uma imagem; autenticar significa
/// comparar identidade com seguranca, normalmente pelo sistema operacional.
class FaceDetectionService {
  FaceDetectionService({ImagePicker? picker, FaceDetector? detector})
      : _picker = picker ?? ImagePicker(),
        _detector = detector ??
            FaceDetector(
              options: FaceDetectorOptions(
                enableContours: true,
                enableLandmarks: true,
                enableClassification: true,
                performanceMode: FaceDetectorMode.fast,
              ),
            );

  final ImagePicker _picker;
  final FaceDetector _detector;

  /// Solicita permissao e abre a camera frontal. Retorna um [PhotoCaptureResult]
  /// para que a UI possa diferenciar negacao temporaria, permanente e cancelamento.
  Future<PhotoCaptureResult> takePhoto() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      return const PhotoCaptureResult(
        PhotoCaptureStatus.permissionPermanentlyDenied,
      );
    }
    if (!status.isGranted) {
      return const PhotoCaptureResult(PhotoCaptureStatus.permissionDenied);
    }

    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (file == null) {
      return const PhotoCaptureResult(PhotoCaptureStatus.canceled);
    }
    return PhotoCaptureResult(PhotoCaptureStatus.taken, file);
  }

  /// Abre a tela de configuracoes do sistema para o usuario habilitar a
  /// permissao manualmente, quando foi negada permanentemente.
  Future<bool> openAppPermissionSettings() => openAppSettings();

  Future<List<Face>> detectFaces(File file) {
    final inputImage = InputImage.fromFile(file);
    return _detector.processImage(inputImage);
  }

  Future<void> close() => _detector.close();
}
