import 'package:file_picker/file_picker.dart';

import 'api_client.dart';
import 'config.dart';

/// Abre el selector del sistema limitado a los formatos que acepta la API. `null` si se cancela.
Future<AudioUpload?> pickAudioFile() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: AppConfig.allowedExtensions);
  if (file == null) return null;
  return AudioUpload(name: file.name, sizeBytes: await file.length() ?? 0, open: () => file.xFile.openRead());
}
