import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when uploading or extracting an admission form fails.
class DocumentExtractionException implements Exception {
  final String message;

  DocumentExtractionException(this.message);

  @override
  String toString() => message;
}

/// Result returned after successfully uploading and extracting an admission form.
class DocumentExtractionResult {
  final String formId;
  final Map<String, dynamic> fields;
  final List<String> uncertainFields;
  final String modelUsed;

  DocumentExtractionResult({
    required this.formId,
    required this.fields,
    required this.uncertainFields,
    required this.modelUsed,
  });
}

/// Uploads an admission form image byte array to the document-extraction-trigger
/// Supabase Edge Function and returns the extracted result draft.
Future<DocumentExtractionResult> uploadAndExtractForm({
  required SupabaseClient client,
  required Uint8List fileBytes,
  required String mimeType,
  String? fileName,
}) async {
  try {
    final base64File = base64Encode(fileBytes);
    final response = await client.functions.invoke(
      'document-extraction-trigger',
      body: {
        'file_base64': base64File,
        'mime_type': mimeType,
        if (fileName != null) 'file_name': fileName,
      },
    );

    if (response.status != 200) {
      String errStr = 'HTTP ${response.status}';
      if (response.data != null) {
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
      }
      throw DocumentExtractionException(errStr);
    }

    Map<String, dynamic> json;
    if (response.data is Map) {
      json = Map<String, dynamic>.from(response.data as Map);
    } else if (response.data is String) {
      json = jsonDecode(response.data as String) as Map<String, dynamic>;
    } else {
      throw DocumentExtractionException('Invalid response format from extraction service');
    }

    if (json.containsKey('error')) {
      throw DocumentExtractionException(json['error'].toString());
    }

    final formId = json['form_id'] as String?;
    if (formId == null) {
      throw DocumentExtractionException('Response missing form_id');
    }

    final fields = json['fields'] is Map
        ? Map<String, dynamic>.from(json['fields'] as Map)
        : <String, dynamic>{};
    final uncertainRaw = json['uncertain_fields'];
    final uncertainFields = uncertainRaw is List
        ? uncertainRaw.map((e) => e.toString()).toList()
        : <String>[];
    final modelUsed = json['model_used'] as String? ?? 'unknown';

    return DocumentExtractionResult(
      formId: formId,
      fields: fields,
      uncertainFields: uncertainFields,
      modelUsed: modelUsed,
    );
  } on DocumentExtractionException {
    rethrow;
  } catch (e) {
    throw DocumentExtractionException('Upload and extraction failed: $e');
  }
}
