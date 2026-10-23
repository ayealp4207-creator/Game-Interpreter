import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

List<CameraDescription> kameralar = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    kameralar = await availableCameras();
  } catch (e) {
    debugPrint("Kamera hatasi: $e");
  }
  runApp(const GameInterpreterApp());
}

class GameInterpreterApp extends StatelessWidget {
  const GameInterpreterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Interpreter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.amber),
      ),
      home: const AnaCevirmenEkrani(),
    );
  }
}

class AnaCevirmenEkrani extends StatefulWidget {
  const AnaCevirmenEkrani({super.key});

  @override
  State<AnaCevirmenEkrani> createState() => _AnaCevirmenEkraniState();
}

class _AnaCevirmenEkraniState extends State<AnaCevirmenEkrani> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isProcessing = false;
  String _yakalananMetin = "Altyazi araniyor...";
  String _turkceCeviri = "";
  String _sonOkunanMetin = "";

  @override
  void initState() {
    super.initState();
    _izinleriVeSistemiBaslat();
  }

  Future<void> _izinleriVeSistemiBaslat() async {
    await [Permission.camera, Permission.microphone].request();
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setSpeechRate(0.9);

    if (kameralar.isNotEmpty) {
      _cameraController = CameraController(
        kameralar[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    }
  }

  Future<void> _kareyiAnalizEt() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String bulunanYazi = recognizedText.text.trim();

      if (bulunanYazi.isNotEmpty && bulunanYazi != _sonOkunanMetin) {
        setState(() {
          _yakalananMetin = bulunanYazi;
        });

        String cevrilen = await _metniCevir(bulunanYazi);
        
        setState(() {
          _turkceCeviri = cevrilen;
          _sonOkunanMetin = bulunanYazi;
        });

        await _flutterTts.speak(cevrilen);
      }
    } catch (e) {
      debugPrint("Analiz hatasi: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String> _metniCevir(String ingilizceMetin) async {
    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=tr&dt=t&q=${Uri.encodeComponent(ingilizceMetin)}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data[0][0][0] ?? ingilizceMetin;
      }
    } catch (_) {}
    return "Ceviri yapilamadi";
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: CameraPreview(_cameraController!),
          ),
          Align(
            alignment: const Alignment(0, 0.4),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withOpacity(0.2),
              ),
              child: const Center(
                child: Text(
                  "TV Altyazisini Buraya Hizalayin",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Algilanan Ingilizce:",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      if (_isProcessing)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                        ),
                    ],
                  ),
                  Text(
                    _yakalananMetin,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  const Text(
                    "Turkce Ceviri & Ses:",
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _turkceCeviri.isEmpty ? "..." : _turkceCeviri,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _isProcessing ? null : _kareyiAnalizEt,
                      icon: const Icon(Icons.translate),
                      label: const Text("Metni Oku & Cevir"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
