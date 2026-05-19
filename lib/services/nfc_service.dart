import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Servico responsavel por consultar disponibilidade NFC e iniciar uma sessao
/// de leitura. A classe isola a biblioteca NFC para simplificar a tela.
class NfcService {
  /// Verifica se o dispositivo possui NFC disponivel no momento.
  Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  /// Inicia a leitura. Quando uma tag e aproximada, retorna os dados brutos
  /// expostos pela biblioteca. Em projetos reais, valide o tipo da tag e trate
  /// NDEF, ISO-DEP, FeliCa ou outras tecnologias conforme a necessidade.
  Future<String> readTag() async {
    final completer = ValueNotifier<String?>(null);

    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        final buffer = StringBuffer();
        buffer.writeln('Tag NFC detectada com sucesso.');
        buffer.writeln('Dados brutos retornados pela biblioteca:');
        buffer.writeln(tag.data.toString());

        completer.value = buffer.toString();
        await NfcManager.instance.stopSession();
      },
    );

    while (completer.value == null) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return completer.value!;
  }

  Future<void> stop() => NfcManager.instance.stopSession();
}
