import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// OMR attendance upload screen.
///
/// FLOW: admin picks (or uses the bundled sample) photo of a filled OMR sheet, the
/// template is loaded from the bundled class_8A asset by default, then POSTs a multipart
/// form to the omr-pipeline service's real `POST /scan` (port 8002). The service runs the
/// ArUco-based scanner + writes results to attendance.records (service-role, bypasses
/// RLS) — so this screen is upload -> scan -> show results. It does NOT itself commit; the
/// human-in-the-loop part is that any row the scanner flagged `needs_review:true` (ambiguous
/// bubble fill, or no roster match) is surfaced with an amber chip + reason text for the
/// admin to correct in the (separate) attendance review flow.
///
/// Endpoint shape confirmed against services/omr-pipeline/main.py (not guessed):
///   multipart fields: image (file), template (file), class_id (str), date (str, optional)
///   response: {summary:{total,present,absent,needs_review}, records:[{roll_no,student_id,
///             student_name,status,confidence,needs_review,review_reason}], inserted}
class OmrUploadScreen extends ConsumerStatefulWidget {
  const OmrUploadScreen({super.key});

  @override
  ConsumerState<OmrUploadScreen> createState() => _OmrUploadScreenState();
}

// Class 8-A — the one class with a seeded roster (Aarav=roll1, Diya=roll2) from earlier
// sessions. The bundled template is for this class.
const _class8AId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

class _OmrUploadScreenState extends ConsumerState<OmrUploadScreen> {
  // The chosen image: null bytes means "no image selected yet".
  Uint8List? _imageBytes;
  String _imageFilename = 'sample_sheet.jpg';
  // class_id is editable but defaults to 8-A (only seeded class).
  late final TextEditingController _classIdController =
      TextEditingController(text: _class8AId);
  DateTime _date = DateTime.now();

  bool _scanning = false;
  String? _error;
  _ScanResult? _result;

  @override
  void dispose() {
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFilename = xfile.name;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not pick image: $e');
    }
  }

  Future<void> _useSampleImage() async {
    try {
      final bytes = await rootBundle.load('assets/omr/sample_sheet.jpg');
      setState(() {
        _imageBytes = bytes.buffer.asUint8List();
        _imageFilename = 'sample_sheet.jpg';
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not load sample image: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String get _dateIso =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _scan() async {
    if (_imageBytes == null) {
      setState(() => _error = 'Pick or load an image first.');
      return;
    }
    final classId = _classIdController.text.trim();
    if (classId.isEmpty) {
      setState(() => _error = 'Class ID is required.');
      return;
    }

    setState(() {
      _scanning = true;
      _error = null;
      _result = null;
    });

    try {
      // Load the bundled template asset as the template multipart file (default). The
      // /scan endpoint requires both an image file and a template file.
      final templateBytes = await rootBundle.load('assets/omr/class_8A_template.json');
      final templateData = templateBytes.buffer.asUint8List();

      final request = http.MultipartRequest('POST', Uri.parse(ApiEndpoints.omrScan))
        ..files.add(http.MultipartFile.fromBytes('image', _imageBytes!,
            filename: _imageFilename))
        ..files.add(http.MultipartFile.fromBytes('template', templateData,
            filename: 'class_8A_template.json'))
        ..fields['class_id'] = classId
        ..fields['date'] = _dateIso;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Scan failed (HTTP ${response.statusCode}): '
              '${_truncate(response.body)}';
          _scanning = false;
        });
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _result = _ScanResult.fromJson(json, response.body);
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Scan request failed: $e\n\n'
            'Is the omr-pipeline service running on port ${ApiEndpoints.omrPort}? '
            '(uvicorn main:app --port ${ApiEndpoints.omrPort})';
        _scanning = false;
      });
    }
  }

  String _truncate(String s, [int n = 400]) =>
      s.length <= n ? s : '${s.substring(0, n)}…';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OMR Attendance', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                _inputCard(context),
                const SizedBox(height: 16),
                if (_error != null) _errorCard(context),
                if (_scanning)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                if (_result != null) _resultView(context, _result!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scan an OMR sheet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Pick photo'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _useSampleImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Use sample'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _imageBytes == null
                  ? 'No image selected — tap "Use sample" to load the bundled demo photo.'
                  : 'Image: $_imageFilename (${(_imageBytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB)',
              style: theme.textTheme.bodySmall,
            ),
            if (_imageBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_imageBytes!,
                      height: 160, fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _classIdController,
              decoration: const InputDecoration(
                labelText: 'Class ID',
                helperText: 'academic.classes.id — defaults to Class 8-A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Date: '),
                TextButton(
                  onPressed: _pickDate,
                  child: Text(_dateIso),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan sheet'),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: scanning writes attendance.records via the service (service-role). '
              'Rows flagged needs_review must be corrected manually in the attendance review flow.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultView(BuildContext context, _ScanResult result) {
    final theme = Theme.of(context);
    final s = result.summary;
    // Raw detection breakdown of the flagged rows, for context. The summary's
    // present/absent are CONFIRMED counts (status set AND not needs_review); these are
    // the raw provisional statuses the scanner actually saw among the flagged rows, so an
    // admin can see "the scanner read 36 present bubbles but only 2 were trusted" without
    // digging through 38 individual rows. Computed from the records already in the
    // response — no extra query.
    final flagged = result.records.where((r) => r.needsReview);
    final detectedPresent =
        flagged.where((r) => r.status == 'present').length;
    final detectedAbsent =
        flagged.where((r) => r.status == 'absent').length;
    final unmatched =
        flagged.where((r) => r.studentId == null).length;
    final breakdownSub = s.needsReview == 0
        ? null
        : '$detectedPresent detected present, $detectedAbsent detected absent, '
            '$unmatched unmatched — pending confirmation';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scan results', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount:
              MediaQuery.of(context).size.width >= 900 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            StatCard(label: 'Total', value: '${s.total}', icon: Icons.groups_outlined),
            StatCard(
                label: 'Present (confirmed)',
                value: '${s.present}',
                icon: Icons.check_circle_outline,
                color: Colors.green),
            StatCard(
                label: 'Absent (confirmed)',
                value: '${s.absent}',
                icon: Icons.cancel_outlined,
                color: Colors.red),
            StatCard(
                label: 'Needs review',
                value: '${s.needsReview}',
                icon: Icons.flag_outlined,
                color: Colors.amber.shade700),
          ],
        ),
        if (breakdownSub != null) ...[
          const SizedBox(height: 8),
          // Raw detection breakdown of the flagged rows, shown under the stat cards. The
          // confirmed present/absent counts above exclude needs_review rows; this line
          // surfaces what the scanner actually saw among those flagged rows so the admin
          // doesn't have to dig through them one by one.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(breakdownSub,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.amber.shade900)),
          ),
        ],
        const SizedBox(height: 8),
        Text('Inserted ${result.inserted} rows into attendance.records.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Text('Per-student breakdown', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...result.records.map((r) => _recordTile(context, r)),
      ],
    );
  }

  Widget _recordTile(BuildContext context, _ScanRecord r) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: r.needsReview
              ? Colors.amber.shade100
              : (r.status == 'present'
                  ? Colors.green.shade100
                  : Colors.red.shade100),
          child: Text('${r.rollNo}'),
        ),
        title: Row(
          children: [
            Text(r.studentName ?? 'Unmatched roll'),
            const SizedBox(width: 8),
            if (r.needsReview)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('REVIEW',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.amber.shade900)),
              ),
          ],
        ),
        subtitle: Text([
          if (r.status != null) 'status: ${r.status}',
          'confidence: ${r.confidence.toStringAsFixed(2)}',
          if (r.reviewReason != null) r.reviewReason!,
        ].join(' · ')),
      ),
    );
  }
}

class _ScanResult {
  _ScanResult({required this.summary, required this.records, required this.inserted});
  final _Summary summary;
  final List<_ScanRecord> records;
  final int inserted;

  factory _ScanResult.fromJson(Map<String, dynamic> json, String rawBody) {
    final s = json['summary'] as Map<String, dynamic>? ?? {};
    final recs = (json['records'] as List? ?? [])
        .map((e) => _ScanRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return _ScanResult(
      summary: _Summary(
        total: (s['total'] as num?)?.toInt() ?? 0,
        present: (s['present'] as num?)?.toInt() ?? 0,
        absent: (s['absent'] as num?)?.toInt() ?? 0,
        needsReview: (s['needs_review'] as num?)?.toInt() ?? 0,
      ),
      records: recs,
      inserted: (json['inserted'] as num?)?.toInt() ?? 0,
    );
  }
}

class _Summary {
  _Summary({required this.total, required this.present, required this.absent, required this.needsReview});
  final int total;
  final int present;
  final int absent;
  final int needsReview;
}

class _ScanRecord {
  _ScanRecord({
    required this.rollNo,
    this.studentId,
    this.studentName,
    this.status,
    required this.confidence,
    required this.needsReview,
    this.reviewReason,
  });
  final int rollNo;
  final String? studentId;
  final String? studentName;
  final String? status;
  final double confidence;
  final bool needsReview;
  final String? reviewReason;

  factory _ScanRecord.fromJson(Map<String, dynamic> j) => _ScanRecord(
        rollNo: (j['roll_no'] as num?)?.toInt() ?? 0,
        studentId: j['student_id'] as String?,
        studentName: j['student_name'] as String?,
        status: j['status'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        needsReview: j['needs_review'] as bool? ?? false,
        reviewReason: j['review_reason'] as String?,
      );
}
