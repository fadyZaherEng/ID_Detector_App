import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../services/ai_detector_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;
  DetectionResult? _result;
  String _apiKey = '';
  bool _isDemoMode = true;
  String? _errorMessage;

  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;

  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();

    // Setup scanning laser animation
    _scannerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final savedKey = await StorageService.getApiKey();
    final demoMode = await StorageService.isDemoModeEnabled();
    setState(() {
      _apiKey = savedKey ?? '';
      _apiKeyController.text = _apiKey;
      _isDemoMode = demoMode;
    });
  }

  Future<void> _saveSettings() async {
    await StorageService.saveApiKey(_apiKeyController.text);
    await StorageService.setDemoModeEnabled(_isDemoMode);
    setState(() {
      _apiKey = _apiKeyController.text;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Settings saved successfully!',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _errorMessage = null;
        _result = null;
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _scanImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _result = null;
    });

    _scannerController.repeat(reverse: true);

    try {
      if (_isDemoMode) {
        // Simulate local AI detection for 2.5 seconds
        await Future.delayed(const Duration(milliseconds: 2500));
        
        // Let's decide if it is an ID based on some simple path checks (e.g. if name contains "id" or user picked something)
        // Or we can randomly decide, or let the user choose.
        // For a smart demo, if the filename or path has "id", "card", or "document" in it, we say it's an ID card.
        // Otherwise, we randomly choose or default to ID since they likely picked an ID.
        final fileName = _imageFile!.path.toLowerCase();
        final isLikelyId = fileName.contains('id') || fileName.contains('card') || fileName.contains('doc') || fileName.contains('license') || fileName.contains('passport') || DateTime.now().second % 2 == 0;
        
        setState(() {
          _result = isLikelyId ? DetectionResult.mockId() : DetectionResult.mockNotId();
        });
      } else {
        if (_apiKey.trim().isEmpty) {
          throw Exception('Please set your Gemini API Key in Settings or enable Demo Mode.');
        }

        final result = await AiDetectorService.detectIdCard(
          imageFile: _imageFile!,
          apiKey: _apiKey,
        );

        setState(() {
          _result = result;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
      _scannerController.stop();
      _scannerController.reset();
    }
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      _result = null;
      _errorMessage = null;
    });
  }

  void _openSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AI Engine Settings',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  
                  // Demo Mode Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Demo / Simulation Mode',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Simulate AI scanning without a real Gemini API Key.',
                                style: GoogleFonts.outfit(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isDemoMode,
                          activeColor: Colors.cyanAccent,
                          activeTrackColor: Colors.cyan.shade900,
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white12,
                          onChanged: (val) {
                            setModalState(() {
                              _isDemoMode = val;
                            });
                            setState(() {
                              _isDemoMode = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // API Key Field (Conditional)
                  AnimatedOpacity(
                    opacity: _isDemoMode ? 0.5 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: _isDemoMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Gemini API Key',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _apiKeyController,
                            obscureText: true,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'AIzaSy...',
                              hintStyle: const TextStyle(color: Colors.white30),
                              prefixIcon: const Icon(Icons.key, color: Colors.cyanAccent),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _apiKey = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          
                          // Instruction to get key
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.outfit(
                                        color: Colors.cyan.shade100,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                      children: const [
                                        TextSpan(text: 'Get a free API Key from '),
                                        TextSpan(
                                          text: 'Google AI Studio',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                            color: Colors.cyanAccent,
                                          ),
                                        ),
                                        TextSpan(text: '. Gemini 1.5 Flash provides fast, accurate image verification.'),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 18),
                                  tooltip: 'Copy Link',
                                  onPressed: () {
                                    Clipboard.setData(const ClipboardData(
                                        text: 'https://aistudio.google.com/'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'AI Studio link copied to clipboard!',
                                          style: GoogleFonts.outfit(),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  ElevatedButton(
                    onPressed: () {
                      _saveSettings();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Save Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1E38), // Deep purple-blue
              Color(0xFF0F172A), // Dark slate
            ],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID Scanner AI',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isDemoMode ? Colors.amber : Colors.greenAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isDemoMode
                                          ? Colors.amber.withOpacity(0.5)
                                          : Colors.greenAccent.withOpacity(0.5),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isDemoMode ? 'Demo Mode (Simulation)' : 'Gemini AI Active',
                                style: GoogleFonts.outfit(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Settings Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune, color: Colors.cyanAccent),
                          onPressed: _openSettingsDialog,
                          tooltip: 'AI Engine Settings',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildImageCard(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    if (_errorMessage != null) _buildErrorCard(),
                    if (_result != null) _buildResultsCard(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    const double cardHeight = 240.0;

    return Center(
      child: Container(
        width: double.infinity,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isScanning
                ? Colors.cyanAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            if (_isScanning)
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (_imageFile == null)
              // Empty state
              InkWell(
                onTap: () => _pickImage(ImageSource.gallery),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.contact_mail_outlined,
                          size: 40,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Upload Identity Document',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Support for National ID, Passports & Licenses',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Selected Image display
              Positioned.fill(
                child: Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),
              // Close button
              if (!_isScanning)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: _clearImage,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              // Scanner laser animation
              if (_isScanning)
                AnimatedBuilder(
                  animation: _scannerAnimation,
                  builder: (context, child) {
                    final position = _scannerAnimation.value * cardHeight;
                    return Positioned(
                      top: position - 2,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.8),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              // Scanning overlay text
              if (_isScanning)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI ANALYZING DOCUMENT...',
                            style: GoogleFonts.outfit(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_imageFile == null) {
      // Prompt options
      return Row(
        children: [
          Expanded(
            child: _buildSelectorButton(
              onTap: () => _pickImage(ImageSource.camera),
              icon: Icons.photo_camera,
              label: 'Take Photo',
              gradientColors: [Colors.cyan.shade600, Colors.teal.shade500],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSelectorButton(
              onTap: () => _pickImage(ImageSource.gallery),
              icon: Icons.photo_library,
              label: 'From Gallery',
              gradientColors: [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
            ),
          ),
        ],
      );
    }

    if (_isScanning) return const SizedBox.shrink();

    // Primary action to scan
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.cyanAccent, Colors.tealAccent],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _scanImage,
            icon: const Icon(Icons.document_scanner, color: Color(0xFF0F172A)),
            label: Text(
              'Analyze Identity Document',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _clearImage,
          icon: const Icon(Icons.refresh, color: Colors.white60, size: 18),
          label: Text(
            'Choose another photo',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
  }) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Error',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.outfit(
                    color: Colors.red.shade100,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final result = _result!;
    final isSuccess = result.isIdCard;
    final color = isSuccess ? Colors.greenAccent : Colors.orangeAccent;
    final bgColor = isSuccess ? Colors.green.withOpacity(0.04) : Colors.orange.withOpacity(0.04);
    final borderColor = isSuccess ? Colors.greenAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2);

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess ? Icons.verified_user : Icons.gpp_bad,
                    color: color,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isSuccess ? 'ID DOCUMENT DETECTED' : 'NOT AN ID CARD',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(result.confidence * 100).toStringAsFixed(0)}% Match',
                  style: GoogleFonts.outfit(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          const Divider(color: Colors.white12, height: 30),

          // Document Type Info
          Row(
            children: [
              Text(
                'Document Classification: ',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
              ),
              Text(
                result.documentType,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Confidence Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Verification confidence score',
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                  ),
                  Text(
                    result.confidence.toStringAsFixed(2),
                    style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: result.confidence,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Extracted Info Section
          if (isSuccess && result.extractedDetails.isNotEmpty) ...[
            Text(
              'Extracted Metadata',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: result.extractedDetails.entries.map((entry) {
                  final isLast = result.extractedDetails.keys.last == entry.key;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatDetailKey(entry.key),
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.value,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Reasoning Card
          Text(
            'AI Reasoning Analysis',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text(
              result.reasoning,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailKey(String key) {
    return key
        .split('_')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
