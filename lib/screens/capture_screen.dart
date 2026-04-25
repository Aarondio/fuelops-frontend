import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../config/app_config.dart';
import '../models/attendant.dart';
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
  final _declaredLitresController = TextEditingController();
  final _declaredCashController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _ocrService = OcrService();
  final _imageService = ImageService();

  Pump? _pump;
  Reading? _openReading;
  String _selectedShift = AppConfig.shifts.first.name.toLowerCase();
  File? _capturedImage;
  int? _selectedAttendantId;
  double? _ocrConfidence;
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
      context.read<ReadingProvider>().loadAttendants();
    });
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    _declaredLitresController.dispose();
    _declaredCashController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _processImageWithOcr(File imageFile) async {
    setState(() => _isProcessingOcr = true);
    try {
      final result = await _ocrService.scan(imageFile);
      if (!mounted) return;

      setState(() {
        _ocrConfidence = result.confidence;
        _isProcessingOcr = false;
      });

      if (result.numbers.isEmpty) {
        _showSnack('NO NUMBERS DETECTED', AppColors.warning);
        return;
      }

      if (result.numbers.length > 1) {
        _showNumberPicker(result.numbers);
      } else {
        _valueController.text = result.numbers.first.value.toStringAsFixed(1);
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  void _showNumberPicker(List<RecognizedNumber> numbers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Text('SELECT METER VALUE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 1.2)),
            const SizedBox(height: 16),
            ...numbers.map((n) => ListTile(
                  title: Text(FormatService.formatDecimal(n.value),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
        final compressedFile = await _imageService.compressAndPersist(
            originalFile, _isClosingMode ? 'closing' : 'opening');
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
        declaredLitresSold: double.parse(_declaredLitresController.text),
        declaredCashCollected: double.parse(_declaredCashController.text),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        closingImage: _capturedImage,
        ocrConfidence: _ocrConfidence,
      );
    } else {
      success = await context.read<ReadingProvider>().submitOpeningReading(
        pumpId: _pump!.id,
        pumpName: _pump!.name,
        openingReading: double.parse(_valueController.text),
        shift: _selectedShift,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        openingImage: _capturedImage,
        attendantId: _selectedAttendantId,
        ocrConfidence: _ocrConfidence,
      );
    }

    setState(() => _isSubmitting = false);
    if (mounted && success) Navigator.pop(context, true);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = _isClosingMode ? 'Closing' : 'Opening';
    final accentColor = _isClosingMode ? AppColors.warning : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$modeLabel Entry'.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
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

                if (!_isClosingMode) ...[
                  _buildShiftSelector(),
                  const SizedBox(height: 20),
                  _buildAttendantPicker(),
                  const SizedBox(height: 20),
                ],

                _buildEntryCard(accentColor),

                if (_isClosingMode) ...[
                  const SizedBox(height: 16),
                  _buildDeclaredFieldsCard(),
                ],

                if (_ocrConfidence != null && _ocrConfidence! < 85) ...[
                  const SizedBox(height: 12),
                  _buildOcrWarning(),
                ],

                const SizedBox(height: 20),
                _buildNotesCard(),

                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(backgroundColor: accentColor),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
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
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.ev_station_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pump!.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  '${_pump!.productType} Unit • ${FormatService.formatCurrency(_pump!.currentPrice)}/L',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
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
                    color: active
                        ? AppColors.primary
                        : (isCompleted
                            ? AppColors.textMuted.withValues(alpha: 0.5)
                            : AppColors.textMuted),
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

  Widget _buildAttendantPicker() {
    final attendants = context.watch<ReadingProvider>().attendants;
    if (attendants.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: DropdownButtonFormField<int>(
        value: _selectedAttendantId,
        decoration: const InputDecoration(
          labelText: 'ATTENDANT',
          labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
          border: InputBorder.none,
          fillColor: Colors.transparent,
        ),
        dropdownColor: AppColors.surface,
        hint: const Text('Select attendant (optional)',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('None')),
          ...attendants
              .where((a) => a.isActive)
              .map((a) => DropdownMenuItem<int>(
                    value: a.id,
                    child: Text(a.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  )),
        ],
        onChanged: (value) => setState(() => _selectedAttendantId = value),
      ),
    );
  }

  Widget _buildEntryCard(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SCAN INTERFACE',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_capturedImage != null) _buildImagePreview() else _buildScanButton(accentColor),
          const SizedBox(height: 20),
          TextFormField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'METER READING',
              labelStyle:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              suffixIcon: Icon(Icons.speed_rounded, color: accentColor),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'REQUIRED';
              if (double.tryParse(v) == null) return 'INVALID NUMBER';
              if (_isClosingMode && _openReading != null) {
                final input = double.tryParse(v);
                if (input != null && input < _openReading!.openingReading) {
                  return 'MUST BE >= OPENING (${FormatService.formatDecimal(_openReading!.openingReading)})';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeclaredFieldsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DECLARED AMOUNTS',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _declaredLitresController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'LITRES SOLD',
              labelStyle:
                  TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              suffixText: 'L',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'REQUIRED';
              if (double.tryParse(v) == null) return 'INVALID NUMBER';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _declaredCashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'CASH COLLECTED',
              labelStyle:
                  TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              prefixText: '₦',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'REQUIRED';
              if (double.tryParse(v) == null) return 'INVALID NUMBER';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOcrWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'LOW OCR CONFIDENCE (${_ocrConfidence!.toStringAsFixed(0)}%) — verify meter reading manually',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OPERATIONAL NOTES',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1)),
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
            Text('INITIATE OPTICAL SCAN',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(_capturedImage!, height: 140, width: double.infinity, fit: BoxFit.cover),
        ),
        if (_ocrConfidence != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (_ocrConfidence! >= 85 ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'OCR ${_ocrConfidence!.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filled(
            onPressed: () => setState(() {
              _capturedImage = null;
              _ocrConfidence = null;
            }),
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
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary, strokeWidth: 4),
              SizedBox(height: 20),
              Text('ANALYZING...',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
