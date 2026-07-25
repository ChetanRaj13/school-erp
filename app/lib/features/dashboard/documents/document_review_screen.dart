import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Document (admission-form) review queue.
///
/// Lists documents.admission_forms rows with status='pending_review' (read from Supabase
/// directly, like every other dashboard — NOT via the FastAPI service). Each row shows the
/// Vision-LLM-extracted fields from extracted_json, with any field named in
/// uncertain_fields flagged amber (human-in-the-loop: the LLM itself signalled low
/// confidence on those). The admin can edit the prefilled values and Approve & Commit,
/// which calls the real `POST /documents/commit` (port 8003, service-role, bypasses RLS) —
/// that endpoint persists the confirmed fields to public.students, links the student_id
/// back onto the form, and marks it status='verified'. Nothing here auto-commits.
///
/// Commit request shape confirmed against services/document-extraction/main.py:
///   {form_id, full_name?, admission_number?, guardian_contact?, student_id?}
///   response: {status:"committed", student_id, form_id, reviewed_at}
class DocumentReviewScreen extends ConsumerStatefulWidget {
  const DocumentReviewScreen({super.key});

  @override
  ConsumerState<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends ConsumerState<DocumentReviewScreen> {
  late Future<List<_PendingForm>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPending(ref.read(supabaseClientProvider));
  }

  void _refresh() {
    setState(() {
      _future = _loadPending(ref.read(supabaseClientProvider));
    });
  }

  Future<List<_PendingForm>> _loadPending(SupabaseClient client) async {
    final rows = await client
        .schema('documents')
        .from('admission_forms')
        .select('id, extracted_json, uncertain_fields, created_at')
        .eq('status', 'pending_review')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _PendingForm.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<List<_PendingForm>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load pending forms:\n${snapshot.error}',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              final forms = snapshot.data!;
              if (forms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 48),
                      const SizedBox(height: 12),
                      const Text('No forms awaiting review.'),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Document Review', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('${forms.length} pending',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...forms.map((f) => _FormCard(form: f, onCommitted: _refresh)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatefulWidget {
  const _FormCard({required this.form, required this.onCommitted});
  final _PendingForm form;
  final VoidCallback onCommitted;

  @override
  State<_FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<_FormCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _admissionCtrl;
  late final TextEditingController _guardianCtrl;
  bool _expanded = false;
  bool _committing = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    // extracted_json stores each field as {"value": "...", "confidence": 0..1} (the real
    // shape produced by services/document-extraction/extractor.py + main.py /extract).
    // Fall back to a flat string if a row was hand-seeded without the nested envelope.
    _nameCtrl = TextEditingController(text: _fieldValue('full_name'));
    _admissionCtrl = TextEditingController(text: _fieldValue('admission_number'));
    _guardianCtrl = TextEditingController(text: _fieldValue('guardian_contact'));
  }

  String _fieldValue(String key) {
    final v = widget.form.fields[key];
    if (v is Map) {
      final inner = v['value'];
      return inner == null ? '' : inner.toString();
    }
    return v == null ? '' : v.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _admissionCtrl.dispose();
    _guardianCtrl.dispose();
    super.dispose();
  }

  bool _isUncertain(String key) => widget.form.uncertainFields.contains(key);

  Future<void> _commit() async {
    setState(() {
      _committing = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.docCommit),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'form_id': widget.form.id,
              'full_name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
              'admission_number': _admissionCtrl.text.trim().isEmpty
                  ? null
                  : _admissionCtrl.text.trim(),
              'guardian_contact': _guardianCtrl.text.trim().isEmpty
                  ? null
                  : _guardianCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Commit failed (HTTP ${response.statusCode}): '
              '${response.body}';
          _committing = false;
        });
        return;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _success = 'Committed. student_id: ${json['student_id']}';
        _committing = false;
      });
      // Give the UI a beat to show success, then refresh the parent list.
      await Future.delayed(const Duration(milliseconds: 600));
      widget.onCommitted();
    } catch (e) {
      setState(() {
        _error = 'Commit request failed: $e\n\n'
            'Is the document-extraction service running on port ${ApiEndpoints.docPort}? '
            '(uvicorn main:app --port ${ApiEndpoints.docPort})';
        _committing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nameCtrl.text.isEmpty
                        ? 'Untitled form'
                        : _nameCtrl.text,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? 'Hide' : 'Review'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Form ${widget.form.shortId} · ${widget.form.createdLabel}',
                style: theme.textTheme.bodySmall),
            if (widget.form.uncertainFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final f in widget.form.uncertainFields)
                    Chip(
                      label: Text('$f (low confidence)',
                          style: theme.textTheme.labelSmall),
                      backgroundColor: Colors.amber.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (_expanded) ...[
              const SizedBox(height: 12),
              _field('Full name', _nameCtrl, uncertain: _isUncertain('full_name')),
              const SizedBox(height: 8),
              _field('Admission number', _admissionCtrl,
                  uncertain: _isUncertain('admission_number')),
              const SizedBox(height: 8),
              _field('Guardian contact', _guardianCtrl,
                  uncertain: _isUncertain('guardian_contact')),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              if (_success != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_success!, style: TextStyle(color: Colors.green)),
                ),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _committing ? null : _commit,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve & Commit'),
                  ),
                  if (_committing)
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {required bool uncertain}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: uncertain ? 'LLM flagged this field as low-confidence — verify.' : null,
        helperStyle: TextStyle(color: Colors.amber.shade800),
        focusedBorder: uncertain
            ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.amber.shade700, width: 2))
            : null,
      ),
    );
  }
}

class _PendingForm {
  _PendingForm({
    required this.id,
    required this.fields,
    required this.uncertainFields,
    required this.createdAt,
  });

  final String id;
  final Map<String, dynamic> fields;
  final List<String> uncertainFields;
  final DateTime createdAt;

  String get shortId {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  String get createdLabel =>
      '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  factory _PendingForm.fromJson(Map<String, dynamic> j) {
    final extracted = j['extracted_json'];
    Map<String, dynamic> fields;
    if (extracted is Map) {
      fields = Map<String, dynamic>.from(extracted);
    } else if (extracted is String) {
      fields = (jsonDecode(extracted) as Map).cast<String, dynamic>();
    } else {
      fields = {};
    }
    final uncertainRaw = j['uncertain_fields'];
    final uncertain = uncertainRaw is List
        ? uncertainRaw.map((e) => e.toString()).toList()
        : <String>[];
    final created = j['created_at'] is String
        ? (DateTime.tryParse(j['created_at']) ?? DateTime.now())
        : DateTime.now();
    return _PendingForm(
      id: j['id'] as String,
      fields: fields,
      uncertainFields: uncertain,
      createdAt: created,
    );
  }
}
