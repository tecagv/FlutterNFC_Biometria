import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../services/biometric_auth_service.dart';
import '../services/face_detection_service.dart';
import '../services/nfc_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NfcService _nfcService = NfcService();
  final BiometricAuthService _biometricService = BiometricAuthService();
  final FaceDetectionService _faceService = FaceDetectionService();

  String _nfcStatus = 'Nenhuma leitura NFC realizada.';
  String _biometricStatus = 'Nenhuma autenticacao realizada.';
  String _faceStatus = 'Nenhuma imagem analisada.';
  File? _lastFaceImage;
  bool _loadingNfc = false;
  bool _loadingBiometric = false;
  bool _loadingFace = false;

  @override
  void dispose() {
    _nfcService.stop();
    _faceService.close();
    super.dispose();
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _checkNfcAndRead() async {
    _setStateIfMounted(() {
      _loadingNfc = true;
      _nfcStatus = 'Verificando NFC...';
    });

    try {
      final availability = await _nfcService.checkAvailability();
      switch (availability) {
        case NfcAvailability.unsupported:
          _setStateIfMounted(
              () => _nfcStatus = 'Este dispositivo nao possui antena NFC.');
          return;
        case NfcAvailability.disabled:
          _setStateIfMounted(() => _nfcStatus =
              'NFC esta desligado. Ative nas configuracoes do aparelho.');
          return;
        case NfcAvailability.enabled:
          break;
      }

      _setStateIfMounted(
          () => _nfcStatus = 'Aproxime uma tag NFC do smartphone...');
      final result = await _nfcService.readTag();
      _setStateIfMounted(() => _nfcStatus = result);
    } on TimeoutException catch (e) {
      _setStateIfMounted(() => _nfcStatus = e.message ?? 'Tempo esgotado.');
    } catch (e) {
      await _nfcService.stop();
      _setStateIfMounted(() => _nfcStatus = 'Erro ao ler NFC: $e');
    } finally {
      _setStateIfMounted(() => _loadingNfc = false);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    _setStateIfMounted(() {
      _loadingBiometric = true;
      _biometricStatus = 'Aguardando o sistema operacional...';
    });

    try {
      final capable = await _biometricService.isBiometricCapable();
      final biometrics = await _biometricService.availableBiometrics();
      if (!capable || biometrics.isEmpty) {
        _setStateIfMounted(() => _biometricStatus =
            'Este aparelho nao possui biometria cadastrada ou disponivel.');
        return;
      }

      final result = await _biometricService.authenticate();
      _setStateIfMounted(
          () => _biometricStatus = _describeBiometricResult(result));
    } finally {
      _setStateIfMounted(() => _loadingBiometric = false);
    }
  }

  String _describeBiometricResult(BiometricAuthResult result) {
    switch (result) {
      case BiometricAuthResult.success:
        return 'Autenticacao biometrica aprovada pelo sistema operacional.';
      case BiometricAuthResult.failed:
        return 'Autenticacao cancelada ou reprovada.';
      case BiometricAuthResult.systemCanceled:
        return 'Autenticacao interrompida pelo sistema (app em background).';
      case BiometricAuthResult.lockedOut:
        return 'Biometria bloqueada apos varias tentativas. Tente novamente mais tarde.';
      case BiometricAuthResult.notAvailable:
        return 'Biometria nao disponivel neste momento.';
      case BiometricAuthResult.error:
        return 'Erro inesperado durante a autenticacao.';
    }
  }

  Future<void> _takePhotoAndDetectFace() async {
    _setStateIfMounted(() {
      _loadingFace = true;
      _faceStatus = 'Abrindo camera frontal...';
    });

    try {
      final capture = await _faceService.takePhoto();
      switch (capture.status) {
        case PhotoCaptureStatus.permissionDenied:
          _setStateIfMounted(() =>
              _faceStatus = 'Permissao de camera negada. Tente novamente.');
          return;
        case PhotoCaptureStatus.permissionPermanentlyDenied:
          _setStateIfMounted(() => _faceStatus =
              'Permissao bloqueada. Abra as configuracoes do app para liberar.');
          await _faceService.openAppPermissionSettings();
          return;
        case PhotoCaptureStatus.canceled:
          _setStateIfMounted(
              () => _faceStatus = 'Captura cancelada pelo usuario.');
          return;
        case PhotoCaptureStatus.taken:
          break;
      }

      final file = File(capture.file!.path);
      final faces = await _faceService.detectFaces(file);
      _setStateIfMounted(() {
        _lastFaceImage = file;
        _faceStatus = _formatFaceResult(faces);
      });
    } catch (e) {
      _setStateIfMounted(() => _faceStatus = 'Erro na deteccao facial: $e');
    } finally {
      _setStateIfMounted(() => _loadingFace = false);
    }
  }

  String _formatFaceResult(List<Face> faces) {
    if (faces.isEmpty) {
      return 'Nenhum rosto detectado. Tente boa iluminacao e enquadramento frontal.';
    }

    final buffer = StringBuffer('Rostos detectados: ${faces.length}\n');
    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      buffer
        ..writeln('Rosto ${i + 1}: caixa=${face.boundingBox}')
        ..writeln(
            'Probabilidade de sorriso: ${_fmtProb(face.smilingProbability)}')
        ..writeln(
            'Olho esquerdo aberto: ${_fmtProb(face.leftEyeOpenProbability)}')
        ..writeln(
            'Olho direito aberto: ${_fmtProb(face.rightEyeOpenProbability)}');
    }
    return buffer.toString();
  }

  String _fmtProb(double? value) =>
      value == null ? 'indisponivel' : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC e Biometria com Flutter'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Projeto didatico: teste em dispositivo fisico para validar NFC, sensor biometrico e camera.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            title: '1. Leitura NFC',
            description:
                'Aproxime uma tag NFC para ler os dados retornados pelo dispositivo.',
            buttonLabel: _loadingNfc ? 'Lendo...' : 'Ler tag NFC',
            loading: _loadingNfc,
            onPressed: _loadingNfc ? null : _checkNfcAndRead,
            result: _nfcStatus,
          ),
          _FeatureCard(
            title: '2. Biometria local',
            description:
                'Usa Face ID, reconhecimento facial do Android ou impressao digital cadastrada no aparelho.',
            buttonLabel:
                _loadingBiometric ? 'Aguardando...' : 'Autenticar com biometria',
            loading: _loadingBiometric,
            onPressed:
                _loadingBiometric ? null : _authenticateWithBiometrics,
            result: _biometricStatus,
          ),
          _FeatureCard(
            title: '3. Deteccao facial didatica',
            description:
                'Captura uma foto e detecta a presenca de rostos usando ML Kit. Nao identifica a pessoa.',
            buttonLabel:
                _loadingFace ? 'Analisando...' : 'Fotografar e detectar rosto',
            loading: _loadingFace,
            onPressed: _loadingFace ? null : _takePhotoAndDetectFace,
            result: _faceStatus,
            image: _lastFaceImage,
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.result,
    this.loading = false,
    this.image,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String result;
  final bool loading;
  final File? image;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPressed,
              child: loading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(buttonLabel),
                      ],
                    )
                  : Text(buttonLabel),
            ),
            if (image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image!, height: 220, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 12),
            SelectableText(result),
          ],
        ),
      ),
    );
  }
}
