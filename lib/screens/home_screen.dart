import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
  bool _loadingFace = false;

  @override
  void dispose() {
    _faceService.close();
    super.dispose();
  }

  Future<void> _checkNfcAndRead() async {
    setState(() {
      _loadingNfc = true;
      _nfcStatus = 'Verificando NFC...';
    });

    try {
      final available = await _nfcService.isAvailable();
      if (!available) {
        setState(() => _nfcStatus = 'NFC indisponivel neste dispositivo.');
        return;
      }

      setState(() => _nfcStatus = 'Aproxime uma tag NFC do smartphone.');
      final result = await _nfcService.readTag();
      setState(() => _nfcStatus = result);
    } catch (e) {
      await _nfcService.stop();
      setState(() => _nfcStatus = 'Erro ao ler NFC: $e');
    } finally {
      setState(() => _loadingNfc = false);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final supported = await _biometricService.isDeviceSupported();
      final biometrics = await _biometricService.availableBiometrics();

      if (!supported || biometrics.isEmpty) {
        setState(() {
          _biometricStatus = 'Este aparelho nao possui biometria cadastrada ou disponivel.';
        });
        return;
      }

      final ok = await _biometricService.authenticate();
      setState(() {
        _biometricStatus = ok
            ? 'Autenticacao biometrica aprovada pelo sistema operacional.'
            : 'Autenticacao cancelada ou reprovada.';
      });
    } catch (e) {
      setState(() => _biometricStatus = 'Erro na autenticacao: $e');
    }
  }

  Future<void> _takePhotoAndDetectFace() async {
    setState(() {
      _loadingFace = true;
      _faceStatus = 'Abrindo camera frontal...';
    });

    try {
      final photo = await _faceService.takePhoto();
      if (photo == null) {
        setState(() => _faceStatus = 'Permissao negada ou foto cancelada.');
        return;
      }

      final file = File(photo.path);
      final faces = await _faceService.detectFaces(file);
      setState(() {
        _lastFaceImage = file;
        _faceStatus = _formatFaceResult(faces);
      });
    } catch (e) {
      setState(() => _faceStatus = 'Erro na deteccao facial: $e');
    } finally {
      setState(() => _loadingFace = false);
    }
  }

  String _formatFaceResult(List<Face> faces) {
    if (faces.isEmpty) {
      return 'Nenhum rosto detectado. Tente boa iluminacao e enquadramento frontal.';
    }

    final buffer = StringBuffer('Rostos detectados: ${faces.length}\n');
    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      buffer.writeln('Rosto ${i + 1}: caixa=${face.boundingBox}');
      buffer.writeln('Probabilidade de sorriso: ${face.smilingProbability?.toStringAsFixed(2) ?? 'indisponivel'}');
      buffer.writeln('Olho esquerdo aberto: ${face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'indisponivel'}');
      buffer.writeln('Olho direito aberto: ${face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'indisponivel'}');
    }
    return buffer.toString();
  }

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
            description: 'Aproxime uma tag NFC para ler os dados retornados pelo dispositivo.',
            buttonLabel: _loadingNfc ? 'Lendo...' : 'Ler tag NFC',
            onPressed: _loadingNfc ? null : _checkNfcAndRead,
            result: _nfcStatus,
          ),
          _FeatureCard(
            title: '2. Biometria local',
            description: 'Usa Face ID, reconhecimento facial do Android ou impressao digital cadastrada no aparelho.',
            buttonLabel: 'Autenticar com biometria',
            onPressed: _authenticateWithBiometrics,
            result: _biometricStatus,
          ),
          _FeatureCard(
            title: '3. Deteccao facial didatica',
            description: 'Captura uma foto e detecta a presenca de rostos usando ML Kit. Nao identifica a pessoa.',
            buttonLabel: _loadingFace ? 'Analisando...' : 'Fotografar e detectar rosto',
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
    this.image,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String result;
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
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
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
