import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../config/app_config.dart';
import '../models/pump.dart';
import '../models/reading.dart';
import '../providers/reading_provider.dart';
import '../services/ocr_service.dart';
import '../services/image_service.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class CaptureArgs {
  final Pump pump;
  final Reading? openReading;
  const CaptureArgs({required this.pump, this.openReading});
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _ocrService = OcrService();
  final _imageService = ImageService();

  Pump? _pump;
  Reading? _openReading;
  String _selectedShift = AppConfig.shifts.first.name.toLowerCase();
  File? _capturedImage;
  bool _isSubmitting = false;
  bool _isProcessingOcr = false;
  bool _isCompressing = false;

  bool get _isClosingMode => _openReading != null;

  @override
  void initState() {
    super.initState();
    _selectedShift = AppConfig.getCurrentShift().name.toLowerCase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is CaptureArgs) {
        setState(() {
          _pump = args.pump;
          _openReading = args.openReading;
        });
      } else if (args is Pump) {
        setState(() => _pump = args);
      }
    });
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _processImageWithOcr(File imageFile) async {
    setState(() => _isProcessingOcr = true);
    try {
      final numbers = await _ocrService.extractAllNumbers(imageFile);
      if (!mounted) return;
      if (numbers.isEmpty) {
        setState(() => _isProcessingOcr = false);
        _showSnack('NO NUMBERS DETECTED', AppColors.warning);
        return;
      }
      if (numbers.length > 1) {
        setState(() => _isProcessingOcr = false);
        _showNumberPicker(numbers);
      } else {
        _valueController.text = numbers.first.value.toStringAsFixed(1);
        setState(() => _isProcessingOcr = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  void _showNumberPicker(List<RecognizedNumber> numbers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('SELECT METER VALUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            ...numbers.map((n) => ListTile(
              title: Text(FormatService.formatDecimal(n.value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              onTap: () {
                _valueController.text = n.value.toStringAsFixed(1);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndProcess(ImageSource source) async {
    final XFile? photo = await _imagePicker.pickImage(source: source, imageQuality: 100);
    if (photo != null) {
      final originalFile = File(photo.path);
      setState(() => _isCompressing = true);
      try {
        final compressedFile = await _imageService.compressAndPersist(originalFile, _isClosingMode ? 'closing' : 'opening');
        setState(() {
          _capturedImage = compressedFile;
          _isCompressing = false;
        });
        await _processImageWithOcr(compressedFile);
      } catch (e) {
        setState(() {
          _capturedImage = originalFile;
          _isCompressing = false;
        });
        await _processImageWithOcr(originalFile);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isClosingMode) {
      final readingProvider = context.read<ReadingProvider>();
      final completedShifts = readingProvider.readings
          .where((r) => r.pumpId == _pump?.id && DateUtils.isSameDay(r.date, DateTime.now()))
          .map((r) => r.shift.toLowerCase())
          .toList();
          
      if (completedShifts.contains(_selectedShift)) {
        _showSnack('SHIFT RECORD ALREADY EXISTS FOR TODAY', AppColors.warning);
        return;
      }
    }

    setState(() => _isSubmitting = true);
    bool success;
    if (_isClosingMode) {
      success = await context.read<ReadingProvider>().submitClosingReading(
        readingId: _openReading!.id,
        closingReading: double.parse(_valueController.text),
        notes: _notesController.text,
        closingImage: _capturedImage,
      );
    } else {
      success = await context.read<ReadingProvider>().submitOpeningReading(
        pumpId: _pump!.id,
        pumpName: _pump!.name,
        openingReading: double.parse(_valueController.text),
        shift: _selectedShift,
        notes: _notesController.text,
        openingImage: _capturedImage,
      );
    }
    setState(() => _isSubmitting = false);
    if (mounted && success) {
      Navigator.pop(context, true);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w800)), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = _isClosingMode ? 'Closing' : 'Opening';
    final accentColor = _isClosingMode ? AppColors.warning : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$modeLabel Entry'.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.pagePadding,
              children: [
                if (_pump != null) _buildPumpInfo(),
                const SizedBox(height: 20),
                
                if (!_isClosingMode) _buildShiftSelector(),
                
                const SizedBox(height: 20),
                _buildEntryCard(accentColor),

                const SizedBox(height: 20),
                _buildNotesCard(),

                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(backgroundColor: accentColor),
                    child: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) 
                      : Text('AUTHORIZE & SAVE $modeLabel'.toUpperCase()),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isCompressing || _isProcessingOcr) _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildPumpInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.ev_station_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pump!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('${_pump!.productType} Unit • ${FormatService.formatCurrency(_pump!.currentPrice)}/L', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSelector() {
    final readingProvider = context.read<ReadingProvider>();
    final completedShifts = readingProvider.readings
        .where((r) => r.pumpId == _pump?.id && DateUtils.isSameDay(r.date, DateTime.now()))
        .map((r) => r.shift.toLowerCase())
        .toList();

    return Row(
      children: AppConfig.shifts.map((s) {
        final shiftName = s.name.toLowerCase();
        final active = _selectedShift == shiftName;
        final isCompleted = completedShifts.contains(shiftName);

        return Expanded(
          child: GestureDetector(
            onTap: isCompleted ? null : () => setState(() => _selectedShift = shiftName),
            child: Container(
              margin: EdgeInsets.only(right: s == AppConfig.shifts.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active 
                    ? AppColors.primary.withValues(alpha: 0.1) 
                    : isCompleted 
                        ? AppColors.surfaceLight.withValues(alpha: 0.5)
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  s.name.toUpperCase(), 
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.w900, 
                    color: active ? AppColors.primary : (isCompleted ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textMuted),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEntryCard(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SCAN INTERFACE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_capturedImage != null) 
            _buildImagePreview()
          else 
            _buildScanButton(accentColor),
          const SizedBox(height: 20),
          TextFormField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'METER READING',
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              suffixIcon: Icon(Icons.speed_rounded, color: accentColor),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'REQUIRED' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OPERATIONAL NOTES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Optional observations...',
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(Color color) {
    return GestureDetector(
      onTap: () => _captureAndProcess(ImageSource.camera),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_rounded, size: 28, color: color),
            const SizedBox(height: 8),
            Text('INITIATE OPTICAL SCAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_capturedImage!, height: 140, width: double.infinity, fit: BoxFit.cover)),
        Positioned(
          top: 8, right: 8,
          child: IconButton.filled(
            onPressed: () => setState(() => _capturedImage = null),
            icon: const Icon(Icons.close_rounded, size: 18),
            style: IconButton.styleFrom(backgroundColor: AppColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    return Container(
      color: AppColors.overlay,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 4),
              const SizedBox(height: 20),
              const Text('ANALYZING...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
