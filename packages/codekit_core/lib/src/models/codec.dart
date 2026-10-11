import 'dart:convert';
import 'dart:typed_data';

import 'records.dart';

enum RecordDecodeStatus { success, invalid, unsupportedVersion }

class RecordDecodeResult {
  final RecordDecodeStatus status;
  final DiagnosticRecord? record;
  const RecordDecodeResult(this.status, [this.record]);
}

class DiagnosticRecordCodec {
  const DiagnosticRecordCodec();
  Uint8List encode(DiagnosticRecord record) =>
      Uint8List.fromList(utf8.encode(jsonEncode(record.toJson())));
  RecordDecodeResult decode(List<int> bytes) {
    try {
      final m = jsonMap(jsonDecode(utf8.decode(bytes)));
      final version = m['schemaVersion'];
      if (version is! int) {
        return const RecordDecodeResult(RecordDecodeStatus.invalid);
      }
      if (version != 1) {
        return const RecordDecodeResult(RecordDecodeStatus.unsupportedVersion);
      }
      return RecordDecodeResult(
        RecordDecodeStatus.success,
        DiagnosticRecord.fromJson(m),
      );
    } catch (_) {
      return const RecordDecodeResult(RecordDecodeStatus.invalid);
    }
  }
}
