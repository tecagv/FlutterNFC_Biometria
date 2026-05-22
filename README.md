# Flutter NFC e Biometria Educacional

Projeto didático e educacional para ensino médio técnico focado em explorar os recursos de hardware do dispositivo mobile e integração com Inteligência Artificial on-device, utilizando Flutter.

- Prof. Alexandre Garcez Vieira
- ETEC Juscelino Kubitschek - Diadema / SP

O projeto foi desenvolvido para demonstrar, de maneira simples e desacoplada, os seguintes recursos:
1. **Leitura de tag NFC:** Integração com sensores de aproximação para leitura de dados brutos de tags (Smartcards, bilhetes de transporte, tags industriais).
2. **Autenticação Biométrica Local:** Uso dos recursos de segurança nativos do sistema operacional (Impressão digital, Face ID do iOS ou Reconhecimento Facial do Android).
3. **Detecção Facial Educacional (Google ML Kit):** Análise de uma foto via câmera para detectar a presença de rostos, pontos de referência (landmarks) e inferência de probabilidade (ex: olhos abertos e sorriso).

---

## 📸 Capturas de Tela / Funcionalidades

O projeto possui uma única tela (`HomeScreen`) dividida em três `Cards`, cada um responsável por demonstrar uma das funcionalidades acima, com exibição de resultados em tempo real e indicador de carregamento por botão.

---

## 🚀 Tecnologias e Pacotes Utilizados

- [**Flutter**](https://flutter.dev/): SDK UI de código aberto do Google.
- [**nfc_manager**](https://pub.dev/packages/nfc_manager): Pacote para comunicação com a API NFC do Android/iOS.
- [**local_auth**](https://pub.dev/packages/local_auth): Pacote para realizar autenticação local usando a biometria do dispositivo.
- [**google_mlkit_face_detection**](https://pub.dev/packages/google_mlkit_face_detection): API On-device do Google ML Kit para processamento de imagem e detecção de faces.
- [**image_picker**](https://pub.dev/packages/image_picker) & [**permission_handler**](https://pub.dev/packages/permission_handler): Para uso de câmera frontal e controle de permissões.

---

## 📂 Estrutura do Projeto

O código está estruturado para separar as regras de acesso aos sensores da Interface de Usuário (UI):

```text
lib/
├── main.dart                      # Ponto de entrada do aplicativo
├── screens/
│   └── home_screen.dart           # Tela principal do app com os 3 botões de ação
└── services/
    ├── biometric_auth_service.dart # Serviço que isola o pacote local_auth
    ├── face_detection_service.dart # Serviço que usa ImagePicker e Google ML Kit
    └── nfc_service.dart            # Serviço para gerenciar sessões do nfc_manager
```

Cada serviço expõe **tipos de resultado próprios** (enums) para que a UI possa traduzir cada estado em uma mensagem clara para o usuário — em vez de devolver apenas `true` / `false`.

---

## 🧠 Como funciona o código? (Resumo dos Serviços)

### 1. Leitura NFC (`nfc_service.dart`)
Utilizamos `NfcManager.checkAvailability()` para distinguir três estados: NFC habilitado, desligado nas configurações, ou não suportado pelo hardware. A leitura propriamente dita usa um `Completer<String>` (em vez de polling) e respeita um **timeout configurável** — sem isso, a sessão poderia ficar aberta indefinidamente.

```dart
final availability = await NfcManager.instance.checkAvailability();
// NfcAvailability.enabled | .disabled | .unsupported

final completer = Completer<String>();
await NfcManager.instance.startSession(
  pollingOptions: const {
    NfcPollingOption.iso14443,
    NfcPollingOption.iso15693,
    NfcPollingOption.iso18092,
  },
  onDiscovered: (NfcTag tag) async {
    if (completer.isCompleted) return;
    completer.complete('Tag detectada: ${tag.data}');
    await NfcManager.instance.stopSession();
  },
  onSessionErrorIos: (error) {
    if (!completer.isCompleted) completer.completeError(error);
  },
);

return completer.future.timeout(const Duration(seconds: 30));
```

### 2. Autenticação Biométrica (`biometric_auth_service.dart`)
Usa o sistema operacional para realizar a validação, de forma segura. O app não tem acesso ao "molde" do rosto ou da digital do usuário; o sistema apenas devolve o resultado da operação.

A capacidade do aparelho é confirmada combinando `canCheckBiometrics` **E** `isDeviceSupported` (ambos verdadeiros) e, em seguida, garantindo que existe ao menos uma biometria **cadastrada** (`getAvailableBiometrics()` não vazio). O `authenticate()` retorna um enum `BiometricAuthResult` que distingue os cenários reais (sucesso, falha, cancelamento pelo SO, lockout temporário, hardware indisponível, erro), tratando `LocalAuthException` internamente.

```dart
enum BiometricAuthResult { success, failed, systemCanceled, lockedOut, notAvailable, error }

final LocalAuthentication auth = LocalAuthentication();

final capable = (await auth.canCheckBiometrics) && (await auth.isDeviceSupported());
final enrolled = (await auth.getAvailableBiometrics()).isNotEmpty;
if (!capable || !enrolled) return BiometricAuthResult.notAvailable;

try {
  final ok = await auth.authenticate(
    localizedReason: 'Autentique-se para acessar a area protegida do app.',
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
  return ok ? BiometricAuthResult.success : BiometricAuthResult.failed;
} on LocalAuthException catch (e) {
  // Mapeia e.code (userCanceled, temporaryLockout, biometricLockout, ...)
  // para um BiometricAuthResult especifico.
}
```

### 3. Detecção Facial Inteligente (`face_detection_service.dart`)
Diferente da *autenticação facial* do SO, a *detecção facial* com ML Kit é usada para saber **onde** estão os rostos na imagem, quantas pessoas há na foto, e detalhes como olhos e boca. O processamento é totalmente offline (on-device).

A captura de foto agora devolve um `PhotoCaptureResult` que distingue **permissão negada**, **permissão negada permanentemente** (caso em que o serviço também oferece `openAppPermissionSettings()` para enviar o usuário para a tela de configurações), **cancelamento** e **foto capturada**.

```dart
enum PhotoCaptureStatus { taken, permissionDenied, permissionPermanentlyDenied, canceled }

final FaceDetector detector = FaceDetector(
  options: FaceDetectorOptions(
    enableContours: true,
    enableLandmarks: true,
    enableClassification: true, // Habilita checagem de olhos e sorriso
    performanceMode: FaceDetectorMode.fast,
  ),
);

// Converte a imagem tirada com o ImagePicker para InputImage
final InputImage inputImage = InputImage.fromFile(imageFile);
final List<Face> faces = await detector.processImage(inputImage);
```

---

## 🛡️ Boas práticas aplicadas

O projeto foi pensado para servir de referência didática, então alguns pontos são intencionalmente explícitos:

- **Sem busy-wait:** o `NfcService` usa `Completer` e `Future.timeout`, em vez de loops `await Future.delayed(...)`.
- **`mounted` checks:** toda chamada `setState` após um `await` na `HomeScreen` é guardada por `if (mounted)`, evitando exceções quando o usuário sai da tela durante uma operação.
- **Mensagens precisas:** cada enum de resultado (`NfcAvailability`, `BiometricAuthResult`, `PhotoCaptureStatus`) é traduzido em texto específico no botão e no card — facilita o entendimento em sala de aula.
- **Injeção de dependências opcional:** os serviços aceitam instâncias customizadas (`LocalAuthentication`, `ImagePicker`, `FaceDetector`) para facilitar testes.

---

## ⚠️ Pré-requisitos para Executar

- É **altamente recomendável** utilizar um **Smartphone físico (Android ou iOS)** para testar este projeto. Emuladores geralmente não possuem:
  - Antena NFC (o app exibirá *"Este dispositivo nao possui antena NFC."*).
  - Sensores Biométricos avançados (embora o Android Emulator consiga simular uma digital).
  - Câmera física frontal real (é possível emular com a webcam do PC, mas pode causar falhas em certas detecções).
- SDK do Flutter `>=3.4.0` instalado.

## 🛠️ Como executar e compilar

1. Clone o repositório ou baixe o projeto.
2. Certifique-se de estar com o smartphone conectado ao PC em modo de depuração USB.
3. No terminal, execute os comandos:

```bash
# Para baixar e resolver as dependências
flutter pub get

# Para rodar em modo de depuração e testar na hora
flutter run

# Para rodar a análise estática e o smoke test do widget
flutter analyze
flutter test

# Para compilar um APK de release para Android
flutter build apk
```

> **Nota:** Para compilar para iOS, você precisará configurar as chaves no arquivo `Info.plist` referentes ao uso de Câmera, Face ID e leitura NFC, além de uma conta Apple Developer para habilitar as 'Capabilities' do NFC no Xcode.
