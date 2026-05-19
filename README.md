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

O projeto possui uma única tela (`HomeScreen`) dividida em três `Cards`, cada um responsável por demonstrar uma das funcionalidades acima, com exibição de resultados em tempo real.

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

---

## 🧠 Como funciona o código? (Resumo dos Serviços)

### 1. Leitura NFC (`nfc_service.dart`)
Utilizamos a classe `NfcManager` para iniciar uma sessão de leitura. Especificamos os protocolos aceitos (ISO 14443, ISO 15693, ISO 18092). Quando uma tag se aproxima, capturamos os dados na forma de um `NfcTag`.
```dart
await NfcManager.instance.startSession(
  pollingOptions: {
    NfcPollingOption.iso14443,
    NfcPollingOption.iso15693,
    NfcPollingOption.iso18092,
  },
  onDiscovered: (NfcTag tag) async {
    // Processamento da tag e parada da sessão.
    await NfcManager.instance.stopSession();
  },
);
```

### 2. Autenticação Biométrica (`biometric_auth_service.dart`)
Usa o sistema operacional para realizar a validação, de forma segura. O app não tem acesso ao "molde" do rosto ou da digital do usuário; o sistema apenas devolve um booleano (`true`/`false`).
```dart
final LocalAuthentication auth = LocalAuthentication();
final bool didAuthenticate = await auth.authenticate(
  localizedReason: 'Autentique-se para acessar a área protegida do app.',
  biometricOnly: true, // Força a biometria ao invés de PIN numérico
);
```

### 3. Detecção Facial Inteligente (`face_detection_service.dart`)
Diferente da *autenticação facial* do SO, a *detecção facial* com ML Kit é usada para saber **onde** estão os rostos na imagem, quantas pessoas há na foto, e detalhes como olhos e boca. O processamento é totalmente offline (on-device).
```dart
final FaceDetector detector = FaceDetector(
  options: FaceDetectorOptions(
    enableContours: true,
    enableClassification: true, // Habilita checagem de olhos e sorriso
    performanceMode: FaceDetectorMode.fast,
  ),
);

// Converte a imagem tirada com o ImagePicker para InputImage
final InputImage inputImage = InputImage.fromFile(imageFile);
final List<Face> faces = await detector.processImage(inputImage);
```

---

## ⚠️ Pré-requisitos para Executar

- É **altamente recomendável** utilizar um **Smartphone físico (Android ou iOS)** para testar este projeto. Emuladores geralmente não possuem:
  - Antena NFC.
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

# Para compilar um APK de release para Android
flutter build apk
```

> **Nota:** Para compilar para iOS, você precisará configurar as chaves no arquivo `Info.plist` referentes ao uso de Câmera, Face ID e leitura NFC, além de uma conta Apple Developer para habilitar as 'Capabilities' do NFC no Xcode.
