import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/pump.dart';
import '../models/reading.dart';
import '../providers/reading_provider.dart';
import '../services/ocr_service.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';

/// Arguments passed to the [CaptureScreen].
///
/// When [openReading] is provided, the screen opens in "closing" mode
/// to submit the closing value against the existing reading.
/// Otherwise it opens in "opening" mode to create a new reading.
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

  /// true = closing mode (updating existing), false = opening mode (creating new)
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
      context.read<ReadingProvider>().loadPumps();
    });
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ── OCR ──────────────────────────────────────────────

  Future<void> _processImageWithOcr(File imageFile) async {
    setState(() => _isProcessingOcr = true);

    try {
      final numbers = await _ocrService.extractAllNumbers(imageFile);
      if (!mounted) return;

      if (numbers.isEmpty) {
        setState(() => _isProcessingOcr = false);
        _showSnack('No numbers detected. Please enter manually.',
            AppColors.warning);
        return;
      }

      if (numbers.length > 1) {
        setState(() => _isProcessingOcr = false);
        _showNumberPicker(numbers);
      } else {
        _valueController.text = numbers.first.value.toStringAsFixed(1);
        setState(() => _isProcessingOcr = false);
        _showSnack(
            'Detected: ${numbers.first.value.toStringAsFixed(1)} L',
            AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
        _showSnack('OCR failed. Please enter manually.', AppColors.warning);
      }
    }
  }

  void _showNumberPicker(List<RecognizedNumber> numbers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            _handle(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Detected Number',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            Divider(height: 1, color: AppColors.surfaceBorder),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: numbers.length,
                itemBuilder: (_, i) {
                  final n = numbers[i];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    title: Text(n.value.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    subtitle: Text('From: "${n.text}"',
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                    onTap: () {
                      _valueController.text =
                          n.value.toStringAsFixed(1);
                      Navigator.pop(ctx);
                      _showSnack(
                          'Detected: ${n.value.toStringAsFixed(1)} L',
                          AppColors.success);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image Capture ────────────────────────────────────

  Future<void> _captureAndProcess(ImageSource source) async {
    final XFile? photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: 2048,
      maxHeight: 2048,
    );

    if (photo != null) {
      final originalFile = File(photo.path);
      setState(() => _isCompressing = true);

      try {
        final category = _isClosingMode ? 'closing' : 'opening';
        final compressedFile =
            await _imageService.compressAndPersist(originalFile, category);

        final stats = await _imageService.getCompressionStats(
            originalFile, compressedFile);

        setState(() {
          _capturedImage = compressedFile;
          _isCompressing = false;
        });

        if (mounted) {
          _showSnack(
              'Compressed: ${stats['originalSizeMB']}MB → ${stats['compressedSizeMB']}MB',
              AppColors.info);
        }

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

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(),
              ListTile(
                leading: _iconBox(
                    Icons.camera_alt_outlined, AppColors.primary),
                title: const Text('Take Photo',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Auto-detect meter reading',
                    style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndProcess(ImageSource.camera);
                },
              ),
              ListTile(
                leading: _iconBox(
                    Icons.photo_library_outlined, AppColors.info),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Auto-detect meter reading',
                    style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndProcess(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit ───────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pump == null) {
      _showSnack('Please select a pump', AppColors.error);
      return;
    }

    setState(() => _isSubmitting = true);

    bool success;

    if (_isClosingMode) {
      // Update existing reading with closing value
      success = await context.read<ReadingProvider>().submitClosingReading(
            readingId: _openReading!.id,
            closingReading: double.parse(_valueController.text),
            notes: _notesController.text.isNotEmpty
                ? _notesController.text
                : null,
            closingImage: _capturedImage,
          );
    } else {
      // Create new reading with opening value
      success = await context.read<ReadingProvider>().submitOpeningReading(
            pumpId: _pump!.id,
            pumpName: _pump!.name,
            openingReading: double.parse(_valueController.text),
            shift: _selectedShift,
            notes: _notesController.text.isNotEmpty
                ? _notesController.text
                : null,
            openingImage: _capturedImage,
          );
    }

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        _showSnack(
            _isClosingMode
                ? 'Closing reading saved!'
                : 'Opening reading saved!',
            AppColors.success);
        Navigator.of(context).pop(true); // return true to trigger refresh
      } else {
        final error = context.read<ReadingProvider>().error;
        _showSnack(error ?? 'Failed to submit', AppColors.error);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final readingProvider = context.watch<ReadingProvider>();
    final hasValue = _valueController.text.isNotEmpty;
    final accentColor =
        _isClosingMode ? AppColors.warning : AppColors.success;
    final modeLabel = _isClosingMode ? 'Closing' : 'Opening';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('$modeLabel Reading'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // ── Pump Header ─────────────────────
                if (_pump != null)
                  _buildPumpHeader()
                else
                  _buildPumpDropdown(readingProvider),

                const SizedBox(height: 16),

                // ── Opening info (in closing mode) ──
                if (_isClosingMode) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Opening: ${_openReading!.openingReading.toStringAsFixed(1)} L',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Shift (opening mode only) ───────
                if (!_isClosingMode) ...[
                  Row(
                    children: [
                      for (final shift in AppConfig.shifts) ...[
                        _buildShiftChip(
                            shift.name,
                            _getShiftIcon(shift.name),
                            shift.name.toLowerCase()),
                        if (shift != AppConfig.shifts.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Scan Card ───────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  hasValue ? AppColors.success : accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scan $modeLabel Meter',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (hasValue)
                            const Icon(Icons.check_circle,
                                color: AppColors.success, size: 18),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Image preview or scan button
                      if (_capturedImage != null)
                        _buildImagePreview(accentColor)
                      else
                        _buildScanButton(accentColor),

                      const SizedBox(height: 12),

                      // Value field
                      TextFormField(
                        controller: _valueController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Meter Value',
                          suffixText: 'L',
                          prefixIcon: hasValue
                              ? const Icon(Icons.auto_awesome,
                                  color: AppColors.primary, size: 18)
                              : const Icon(Icons.speed_outlined,
                                  size: 18),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final v = double.tryParse(value);
                          if (v == null) return 'Enter a valid number';
                          if (_isClosingMode &&
                              v < _openReading!.openingReading) {
                            return 'Must be ≥ opening (${_openReading!.openingReading.toStringAsFixed(1)})';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Volume Preview (closing mode) ───
                if (_isClosingMode && hasValue)
                  Builder(builder: (_) {
                    final closing =
                        double.tryParse(_valueController.text) ?? 0;
                    final volume =
                        closing - _openReading!.openingReading;
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: volume >= 0
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_gas_station,
                              color: volume >= 0
                                  ? AppColors.success
                                  : AppColors.error),
                          const SizedBox(width: 10),
                          Text(
                            '${volume.toStringAsFixed(1)} L sold',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: volume >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // ── Notes ───────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    style:
                        const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Submit ──────────────────────────
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    disabledBackgroundColor: AppColors.surfaceLight,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Save $modeLabel Reading',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Processing Overlay
          if (_isCompressing || _isProcessingOcr)
            Container(
              color: AppColors.overlay,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: _isCompressing
                            ? AppColors.info
                            : AppColors.primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isCompressing
                            ? 'Compressing image...'
                            : 'Reading meter...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isCompressing
                            ? 'Optimizing for upload'
                            : 'Detecting numbers in the image',
                        style: const TextStyle(
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────

  Widget _buildPumpHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.local_gas_station_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pump!.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_pump!.productType} · ₦${_pump!.currentPrice.toStringAsFixed(0)}/L',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_isClosingMode)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text('Closing',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildPumpDropdown(ReadingProvider readingProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonFormField<Pump>(
        initialValue: _pump,
        dropdownColor: AppColors.surfaceLight,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Select a pump to start',
          prefixIcon: Icon(Icons.local_gas_station_outlined),
        ),
        items: readingProvider.pumps
            .map((pump) => DropdownMenuItem(
                  value: pump,
                  child: Text('${pump.name} (${pump.productType})'),
                ))
            .toList(),
        onChanged: (pump) => setState(() => _pump = pump),
        validator: (value) =>
            value == null ? 'Please select a pump' : null,
      ),
    );
  }

  IconData _getShiftIcon(String shiftName) {
    switch (shiftName.toLowerCase()) {
      case 'morning':
        return Icons.wb_sunny_outlined;
      case 'afternoon':
        return Icons.wb_twilight_outlined;
      case 'night':
        return Icons.nightlight_outlined;
      default:
        return Icons.schedule;
    }
  }

  Widget _buildShiftChip(String label, IconData icon, String value) {
    final selected = _selectedShift == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedShift = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton(Color accentColor) {
    return GestureDetector(
      onTap: _showImageOptions,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 28, color: accentColor),
              const SizedBox(height: 6),
              Text(
                'Scan Meter',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(Color accentColor) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.file(
            _capturedImage!,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 36,
            decoration: const BoxDecoration(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
              color: AppColors.overlay,
            ),
          ),
        ),
        Positioned(
          top: 6,
          left: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.white, size: 12),
                SizedBox(width: 3),
                Text('Scanned',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 8,
          child: Row(
            children: [
              _miniButton(Icons.refresh, AppColors.surfaceLight,
                  _showImageOptions),
              const SizedBox(width: 4),
              _miniButton(Icons.close, AppColors.error, () {
                setState(() {
                  _capturedImage = null;
                  _valueController.clear();
                });
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _handle() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.surfaceBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
