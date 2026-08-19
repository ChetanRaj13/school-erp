import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// OMR attendance upload & review screen.
///
/// FLOW:
/// 1. Admin/Teacher picks or uses the bundled sample OMR sheet photo.
/// 2. Selects class from dropdown (dynamically loaded from `academic.classes`).
/// 3. Scans sheet via omr-pipeline service (port 8002).
/// 4. Displays verified results, present/absent stats, and allows inline 1-click
///    resolution for any student record flagged for review.
class OmrUploadScreen extends ConsumerStatefulWidget {
  const OmrUploadScreen({super.key});

  @override
  ConsumerState<OmrUploadScreen> createState() => _OmrUploadScreenState();
}

const _defaultClass8AId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

class _OmrUploadScreenState extends ConsumerState<OmrUploadScreen> {
  Uint8List? _imageBytes;
  String _imageFilename = 'sample_sheet.jpg';

  String _selectedClassId = _defaultClass8AId;
  List<Map<String, dynamic>> _classList = [];
  bool _loadingClasses = true;

  DateTime _date = DateTime.now();
  bool _scanning = false;
  String? _error;
  _ScanResult? _result;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final rows = await client
          .schema('academic')
          .from('classes')
          .select('id, name')
          .eq('is_archived', false)
          .order('name');
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (mounted) {
        setState(() {
          _classList = list;
          _loadingClasses = false;
          if (list.isNotEmpty && !list.any((c) => c['id'] == _selectedClassId)) {
            _selectedClassId = list.first['id'] as String;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingClasses = false);
    }
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
      setState(() => _error = 'Please pick or load an OMR image first.');
      return;
    }

    setState(() {
      _scanning = true;
      _error = null;
      _result = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final base64Image = base64Encode(_imageBytes!);
      final mimeType = _imageFilename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      // Primary: invoke deployed Supabase Edge Function
      final response = await client.functions.invoke(
        'omr-scan',
        body: {
          'file_base64': base64Image,
          'mime_type': mimeType,
          'class_id': _selectedClassId,
          'date': _dateIso,
        },
      );

      if (response.status != 200) {
        String errStr = 'HTTP ${response.status}';
        if (response.data is Map && (response.data as Map).containsKey('error')) {
          errStr = (response.data as Map)['error'].toString();
        } else if (response.data is String) {
          try {
            final parsed = jsonDecode(response.data as String);
            if (parsed is Map && parsed.containsKey('error')) {
              errStr = parsed['error'].toString();
            } else {
              errStr = response.data.toString();
            }
          } catch (_) {
            errStr = response.data.toString();
          }
        }
        throw Exception(errStr);
      }

      Map<String, dynamic> json;
      if (response.data is Map) {
        json = Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is String) {
        json = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else {
        throw Exception('Invalid response format from OMR scan service');
      }

      setState(() {
        _result = _ScanResult.fromJson(json);
        _scanning = false;
      });
    } catch (e) {
      // Fallback: If Edge Function is unavailable during local dev, try local FastAPI service
      try {
        final templateBytes = await rootBundle.load('assets/omr/class_8A_template.json');
        final templateData = templateBytes.buffer.asUint8List();

        final request = http.MultipartRequest('POST', Uri.parse(ApiEndpoints.omrScan))
          ..files.add(http.MultipartFile.fromBytes('image', _imageBytes!, filename: _imageFilename))
          ..files.add(http.MultipartFile.fromBytes('template', templateData, filename: 'class_8A_template.json'))
          ..fields['class_id'] = _selectedClassId
          ..fields['date'] = _dateIso;

        final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          throw Exception('Local scan fallback failed (HTTP ${response.statusCode}): ${_truncate(response.body)}');
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _result = _ScanResult.fromJson(json);
          _scanning = false;
        });
      } catch (fallbackErr) {
        setState(() {
          _error = 'Scan request failed: $e';
          _scanning = false;
        });
      }
    }
  }

  Future<void> _resolveRecord(_ScanRecord record, String newStatus) async {
    final client = ref.read(supabaseClientProvider);
    try {
      if (record.studentId != null) {
        await client
            .schema('attendance')
            .from('records')
            .update({
              'status': newStatus,
              'needs_review': false,
              'review_reason': null,
            })
            .eq('class_id', _selectedClassId)
            .eq('student_id', record.studentId!)
            .eq('date', _dateIso);
      }

      setState(() {
        record.status = newStatus;
        record.needsReview = false;
        record.reviewReason = null;
        if (_result != null) {
          _result!.recalculate();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Roll ${record.rollNo} marked as ${newStatus.toUpperCase()} and confirmed.'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update record: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _truncate(String s, [int n = 400]) => s.length <= n ? s : '${s.substring(0, n)}…';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OMR Attendance',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ArUco perspective correction & automatic bubble scanner',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('Dual-Mode Attendance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Upload & Parameters Card
                _buildInputCard(context),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(context),
                ],

                if (_scanning) ...[
                  const SizedBox(height: 28),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 12),
                        Text('Analyzing OMR bubbles & perspective alignment...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],

                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _buildResultView(context, _result!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.document_scanner_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Scan Sheet Configuration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Pick OMR Photo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _useSampleImage,
                icon: const Icon(Icons.insert_drive_file_outlined, size: 16),
                label: const Text('Load Demo Sheet (8-A)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            _imageBytes == null
                ? 'No image selected — click "Load Demo Sheet" to use the bundled sample.'
                : 'Selected Image: $_imageFilename (${(_imageBytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB)',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),

          if (_imageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
                child: Image.memory(
                  _imageBytes!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: 16),

          // Class & Date selector row
          Row(
            children: [
              // Class dropdown
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Class Target', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: _loadingClasses
                          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedClassId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                items: _classList
                                    .map((c) => DropdownMenuItem(
                                          value: c['id'] as String,
                                          child: Text(
                                            'Class ${c['name']}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedClassId = val);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Date picker
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_dateIso, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Execute Scan & Process Attendance', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, _ScanResult result) {
    final s = result.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Scan Results Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00877D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                '${result.records.length} Students Evaluated',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF00877D)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Summary Metric Cards
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatCard(label: 'Total Enrolled', value: '${s.total}', icon: Icons.groups_outlined),
            StatCard(label: 'Present (Confirmed)', value: '${s.present}', icon: Icons.check_circle_outline, color: const Color(0xFF00877D)),
            StatCard(label: 'Absent (Confirmed)', value: '${s.absent}', icon: Icons.cancel_outlined, color: AppColors.error),
            StatCard(
              label: 'Needs Review',
              value: '${s.needsReview}',
              icon: Icons.flag_outlined,
              color: s.needsReview == 0 ? const Color(0xFF00877D) : const Color(0xFFD97706),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Per-student roster list
        Text('Student Attendance Breakdown', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...result.records.map((r) => _buildRecordCard(context, r)),
      ],
    );
  }

  Widget _buildRecordCard(BuildContext context, _ScanRecord r) {
    final isPresent = r.status == 'present';
    final isAbsent = r.status == 'absent';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Roll circle avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: r.needsReview
                    ? const Color(0xFFD97706).withValues(alpha: 0.15)
                    : isPresent
                        ? const Color(0xFF00877D).withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${r.rollNo}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: r.needsReview
                      ? const Color(0xFFD97706)
                      : isPresent
                          ? const Color(0xFF00877D)
                          : AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Student name & status details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        r.studentName ?? 'Roll #${r.rollNo}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      if (r.needsReview)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NEEDS REVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPresent ? const Color(0xFF00877D).withValues(alpha: 0.12) : AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (r.status ?? 'UNSET').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isPresent ? const Color(0xFF00877D) : AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      'Confidence: ${(r.confidence * 100).toInt()}%',
                      if (r.reviewReason != null) r.reviewReason!,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: r.needsReview ? const Color(0xFFD97706) : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Quick Resolution Action Buttons
            if (r.needsReview) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _resolveRecord(r, 'present'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00877D),
                  side: const BorderSide(color: Color(0xFF00877D)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(60, 28),
                ),
                child: const Text('Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _resolveRecord(r, 'absent'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(60, 28),
                ),
                child: const Text('Absent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanResult {
  _ScanResult({required this.summary, required this.records, required this.inserted});
  final _Summary summary;
  final List<_ScanRecord> records;
  final int inserted;

  void recalculate() {
    int p = 0;
    int a = 0;
    int nr = 0;
    for (final r in records) {
      if (r.needsReview) {
        nr++;
      } else if (r.status == 'present') {
        p++;
      } else if (r.status == 'absent') {
        a++;
      }
    }
    summary.total = records.length;
    summary.present = p;
    summary.absent = a;
    summary.needsReview = nr;
  }

  factory _ScanResult.fromJson(Map<String, dynamic> json) {
    final s = json['summary'] as Map<String, dynamic>? ?? {};
    final recs = (json['records'] as List? ?? [])
        .map((e) => _ScanRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    final totalCount = recs.isNotEmpty ? recs.length : ((s['total'] as num?)?.toInt() ?? 0);
    return _ScanResult(
      summary: _Summary(
        total: totalCount,
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
  int total;
  int present;
  int absent;
  int needsReview;
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
  String? status;
  final double confidence;
  bool needsReview;
  String? reviewReason;

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
