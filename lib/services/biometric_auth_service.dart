import 'package:local_auth/local_auth.dart';

/// Servico de autenticacao local. O app nao recebe a digital nem a face do
/// usuario; quem valida e o sistema operacional do aparelho.
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheckBiometrics || isSupported;
  }

  Future<List<BiometricType>> availableBiometrics() {
    return _auth.getAvailableBiometrics();
  }

  Future<bool> authenticate() async {
    return _auth.authenticate(
      localizedReason: 'Autentique-se para acessar a area protegida do app.',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
