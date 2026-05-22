import 'dart:async';

import 'package:nfc_manager/nfc_manager.dart';

/// Servico responsavel por consultar disponibilidade NFC e iniciar uma sessao
/// de leitura. A classe isola a biblioteca NFC para simplificar a tela.
class NfcService {
  /// Tempo maximo padrao para aguardar a aproximacao de uma tag.
  static const Duration defaultTimeout = Duration(seconds: 30);

  Completer<String>? _readCompleter;

  /// Retorna o estado atual da antena NFC: habilitada, desabilitada ou nao
  /// suportada pelo hardware. Permite mensagens mais precisas que um booleano.
  Future<NfcAvailability> checkAvailability() =>
      NfcManager.instance.checkAvailability();

  /// Inicia a leitura. Quando uma tag e aproximada, retorna os dados brutos
  /// expostos pela biblioteca. Em projetos reais, valide o tipo da tag e trate
  /// NDEF, ISO-DEP, FeliCa ou outras tecnologias conforme a necessidade.
  ///
  /// Lanca [TimeoutException] se nenhuma tag for aproximada dentro de [timeout].
  /// Lanca [StateError] se ja houver uma leitura em andamento.
  Future<String> readTag({Duration timeout = defaultTimeout}) async {
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      throw StateError('Ja existe uma leitura NFC em andamento.');
    }

    final completer = Completer<String>();
    _readCompleter = completer;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          if (completer.isCompleted) return;
          final buffer = StringBuffer()
            ..writeln('Tag NFC detectada com sucesso.')
            ..writeln('Dados brutos retornados pela biblioteca:')
            // Em projetos reais, prefira NdefAndroid/IsoDepAndroid/IsoDepIos etc.
            // Aqui exibimos o payload bruto apenas para fins didaticos.
            // ignore: invalid_use_of_protected_member
            ..writeln(tag.data.toString());
          completer.complete(buffer.toString());
          await NfcManager.instance.stopSession();
        },
        onSessionErrorIos: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
      );

      return await completer.future.timeout(
        timeout,
        onTimeout: () async {
          await stop();
          throw TimeoutException(
            'Nenhuma tag NFC foi aproximada em ${timeout.inSeconds}s.',
          );
        },
      );
    } catch (_) {
      await stop();
      rethrow;
    } finally {
      if (identical(_readCompleter, completer)) {
        _readCompleter = null;
      }
    }
  }

  /// Encerra a sessao NFC ativa, se houver. Seguro de chamar sempre.
  Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // stopSession pode falhar se nenhuma sessao estiver ativa; ignoramos.
    }
  }
}
