import 'package:local_auth/local_auth.dart';

/// Resultado consolidado de uma tentativa de autenticacao biometrica.
enum BiometricAuthResult {
  /// Usuario autenticado com sucesso pelo sistema operacional.
  success,

  /// Usuario cancelou ou falhou silenciosamente (toque invalido, etc).
  failed,

  /// Cancelado pelo SO (app foi para o background, por exemplo).
  systemCanceled,

  /// Bloqueado temporariamente apos varias tentativas invalidas.
  lockedOut,

  /// Aparelho nao possui hardware ou biometria cadastrada.
  notAvailable,

  /// Outro erro inesperado.
  error,
}

/// Servico de autenticacao local. O app nao recebe a digital nem a face do
/// usuario; quem valida e o sistema operacional do aparelho.
class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Verifica se o aparelho possui hardware biometrico utilizavel.
  ///
  /// Diferente da versao anterior, exige ambos: hardware capaz e suporte
  /// confirmado pelo SO. Combinar com [availableBiometrics] para confirmar que
  /// existe pelo menos uma biometria cadastrada.
  Future<bool> isBiometricCapable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    return canCheck && supported;
  }

  Future<List<BiometricType>> availableBiometrics() =>
      _auth.getAvailableBiometrics();

  /// Tenta autenticar o usuario. Retorna um [BiometricAuthResult] em vez de
  /// apenas booleano para que a UI possa explicar exatamente o que aconteceu.
  Future<BiometricAuthResult> authenticate({
    String reason = 'Autentique-se para acessar a area protegida do app.',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricAuthResult.success : BiometricAuthResult.failed;
    } on LocalAuthException catch (e) {
      return _mapException(e.code);
    } catch (_) {
      return BiometricAuthResult.error;
    }
  }

  BiometricAuthResult _mapException(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return BiometricAuthResult.failed;
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        return BiometricAuthResult.systemCanceled;
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricAuthResult.lockedOut;
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return BiometricAuthResult.notAvailable;
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.uiUnavailable:
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return BiometricAuthResult.error;
    }
  }
}
