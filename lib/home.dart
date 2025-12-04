import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Timer? _debounceTimer;
  final Duration debounceDuration = const Duration(milliseconds: 600);

  // Pure flowing animation
  final Duration _characterDelay = const Duration(milliseconds: 30);
  Timer? _typingTimer;
  bool _isAnimating = false;
  String? _queuedText;
  int _animationId = 0;

  String arabicText = " ";
  final List<String> _history = [];
  String _currentTranslationDisplayed = "";

  int _fadingGlobalIndex = -1;
  double _fadingOpacity = 1.0;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  DateTime _lastArabicUpdate = DateTime.now();

  late Timer _waveTimer;
  final Random _rand = Random();
  List<double> _barHeights = List.generate(24, (_) => 4.0);

  // --- UPDATED: Google API Key Variable ---
  // PASTE YOUR KEY INSIDE THE QUOTES BELOW
  final String _googleApiKey = "AIzaSyBWcsnur5KXdBbTztWQOxNUE_8nIrKp2SQ";

  final ScrollController _scrollController = ScrollController();
  static const int _visibleLineLimit = 5;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _checkMicPermission();

    // FIX: Added !mounted check to prevent setState call after dispose.
    _waveTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return; // Prevent setState if the widget is disposed
      if (_isListening) {
        setState(() {
          for (int i = 0; i < _barHeights.length; i++) {
            _barHeights[i] = 6.0 + _rand.nextDouble() * (40 * _rand.nextDouble());
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _waveTimer.cancel();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  // NEW: Smart anticipatory scroll — starts 60px BEFORE the bottom
  void _smartScroll({double offsetBeforeEnd = 120.0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final double maxScroll = _scrollController.position.maxScrollExtent;
      final double viewportHeight = _scrollController.position.viewportDimension;

      // Scroll when we're within ~60px of the bottom, or when content is growing
      final double triggerThreshold = maxScroll - viewportHeight + offsetBeforeEnd;

      if (_scrollController.offset < triggerThreshold || maxScroll <= viewportHeight) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // PURE FLOWING LIVE TRANSLATION — NO REWINDS, ONLY FORWARD
  void _startFlowingTranslation(String newText) {
    newText = newText.trim();
    if (newText.isEmpty) return;

    if (_isAnimating) {
      _queuedText = newText;
      return;
    }

    _isAnimating = true;
    final int currentId = ++_animationId;
    int index = 0;
    final String baseText = _currentTranslationDisplayed;

    _typingTimer = Timer.periodic(_characterDelay, (timer) {
      if (!mounted || currentId != _animationId) {
        timer.cancel();
        _isAnimating = false;
        return;
      }

      // Switch to newer text if available
      if (_queuedText != null && index >= newText.length - baseText.length) {
        timer.cancel();
        _isAnimating = false;
        final String next = _queuedText!;
        _queuedText = null;
        _startFlowingTranslation(next);
        return;
      }

      if (index >= newText.length - baseText.length) {
        timer.cancel();
        _isAnimating = false;
        return;
      }

      setState(() {
        _currentTranslationDisplayed = baseText + newText.substring(baseText.length, baseText.length + index + 1);
      });

      index++;
      _smartScroll(offsetBeforeEnd: 120); // Beautiful anticipation
    });
  }

  // --- UPDATED: Using Google Cloud API ---
  Future<void> _sendTranslationRequestToServer(String arabicTextToTranslate) async {
    if (arabicTextToTranslate.trim().isEmpty) return;

    String translation = "";
    try {
      final url = Uri.parse("https://translation.googleapis.com/language/translate/v2?key=$_googleApiKey");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "q": arabicTextToTranslate,
          "source": "ar",
          "target": "en",
          "format": "text",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Google response structure: { data: { translations: [ { translatedText: "..." } ] } }
        if (data['data'] != null &&
            data['data']['translations'] != null &&
            data['data']['translations'].isNotEmpty) {
          translation = data['data']['translations'][0]['translatedText'];
        }
      } else {
        debugPrint("Translation API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("HTTP error: $e");
    }

    if (mounted && translation.isNotEmpty) {
      _startFlowingTranslation(translation);
    }
  }

  void _debounceTranslationRequest(String newArabicText) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      _sendTranslationRequestToServer(newArabicText);
    });
  }

  void _addNewLine(String line) {
    if (line.trim().isEmpty) return;
    _history.add(line.trim());

    if (_history.length > _visibleLineLimit) {
      _fadingGlobalIndex = _history.length - _visibleLineLimit - 1;
      _fadingOpacity = 1.0;

      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        setState(() => _fadingOpacity = 0.0);
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() => _fadingGlobalIndex = -1);
      });
    }
    _smartScroll(offsetBeforeEnd: 120); // Also anticipate new lines
  }

  void _commitCurrentLine() {
    _typingTimer?.cancel();
    _isAnimating = false;
    _queuedText = null;
    _animationId++;

    if (_currentTranslationDisplayed.trim().isNotEmpty) {
      _addNewLine(_currentTranslationDisplayed);
      setState(() {
        _currentTranslationDisplayed = "";
      });
    }
  }

  Future<void> _checkMicPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      var result = await Permission.microphone.request();
      if (result.isPermanentlyDenied) {
        _showOpenSettingsDialog();
      }
    }
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text("Microphone Permission Required", style: TextStyle(color: Colors.white)),
        content: const Text("Please allow microphone access in settings to use live translation.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          TextButton(
            onPressed: () { openAppSettings(); Navigator.of(context).pop(); },
            child: const Text("Open Settings", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void _toggleListening() async {
    if (_isListening) {
      _speech.stop();
      _debounceTimer?.cancel();
      _commitCurrentLine();
      setState(() {
        _isListening = false;
        _barHeights = List.filled(24, 4.0);
      });
      return;
    }

    bool available = await _speech.initialize();
    if (!available) return;

    setState(() {
      _isListening = true;
      arabicText = " ";
      _currentTranslationDisplayed = "";
      _fadingGlobalIndex = -1;
      _isAnimating = false;
      _queuedText = null;
      _animationId++;
    });

    _speech.listen(
      onResult: (val) {
        String text = val.recognizedWords;
        if (text.isEmpty) return;
        setState(() {
          arabicText = text;
          _lastArabicUpdate = DateTime.now();
        });
        _debounceTranslationRequest(text);
      },
      localeId: 'ar-SA',
      partialResults: true,
      listenFor: const Duration(minutes: 10),
    );
  }

  Widget _buildArabicText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Container(
        width: double.infinity,
        height: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF121218),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black],
              stops: [0.0, 0.2, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Align(
              key: ValueKey('$arabicText|${_lastArabicUpdate.millisecondsSinceEpoch}'),
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  arabicText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1116),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: _buildTopBar(),
            ),
            _buildArabicText(),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Target Language Translation",
                          style: TextStyle(color: Color(0xFFBCC7EF), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontFamily: 'Circular', fontSize: 30, height: 1.5),
                              children: [
                                ..._history.asMap().entries.map((entry) {
                                  int globalIndex = entry.key;
                                  String text = entry.value;

                                  bool isInVisibleWindow = globalIndex >= _history.length - _visibleLineLimit;
                                  bool isFadingOut = globalIndex == _fadingGlobalIndex;

                                  double opacity = isFadingOut
                                      ? _fadingOpacity
                                      : isInVisibleWindow
                                          ? 0.4
                                          : 0.15;

                                  return TextSpan(
                                    text: "$text\n",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(opacity),
                                      fontWeight: isInVisibleWindow ? FontWeight.normal : FontWeight.w300,
                                    ),
                                  );
                                }),
                                TextSpan(
                                  text: _currentTranslationDisplayed,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(height: 60, child: _buildWaveform()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1116),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isListening ? Colors.greenAccent.shade400 : const Color(0xFF0B0E12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(_isListening ? Icons.mic : Icons.mic_off,
                  color: _isListening ? Colors.black : Colors.white70, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          const Text("Live Translation",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _barHeights.map((h) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: _isListening ? h : 4.0,
              decoration: BoxDecoration(
                color: _isListening ? const Color.fromARGB(255, 28, 28, 28) : const Color.fromARGB(58, 49, 49, 49),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}