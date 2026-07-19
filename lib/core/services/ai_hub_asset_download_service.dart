import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/model_spec.dart';

typedef AssetDownloadProgress =
    void Function(int downloadedBytes, int totalBytes);

/// Downloads Qualcomm AI Hub's published device-specific release archives.
class AiHubAssetDownloadService {
  AiHubAssetDownloadService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<bool> isDownloaded(ModelSpec model) async {
    final file = await _destinationFor(model);
    return (await file.exists()) && await file.length() > 0;
  }

  Future<void> download(
    ModelSpec model, {
    required AssetDownloadProgress onProgress,
  }) async {
    final url = model.directAssetUrl;
    if (url == null) {
      throw StateError('${model.title} has no downloadable AI Hub asset.');
    }
    final destination = await _destinationFor(model);
    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.part');
    final request = http.Request('GET', Uri.parse(url));
    final existingBytes = await temporary.exists()
        ? await temporary.length()
        : 0;
    if (existingBytes > 0) {
      request.headers[HttpHeaders.rangeHeader] = 'bytes=$existingBytes-';
    }
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw HttpException(
        'AI Hub asset request failed (${response.statusCode}).',
      );
    }
    final total = _totalBytes(response, existingBytes);
    final sink = temporary.openWrite(
      mode:
          existingBytes > 0 && response.statusCode == HttpStatus.partialContent
          ? FileMode.append
          : FileMode.write,
    );
    var downloaded = response.statusCode == HttpStatus.partialContent
        ? existingBytes
        : 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloaded += chunk.length;
      onProgress(downloaded, total);
    }
    await sink.close();
    if (total > 0 && downloaded != total) {
      throw HttpException('AI Hub asset download was incomplete.');
    }
    await temporary.rename(destination.path);
  }

  Future<File> _destinationFor(ModelSpec model) async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}/ai_hub_models/${model.name.replaceAll('/', '_')}.zip',
    );
  }

  int _totalBytes(http.StreamedResponse response, int existingBytes) {
    final range = response.headers[HttpHeaders.contentRangeHeader];
    final rangeTotal = range == null
        ? null
        : int.tryParse(range.split('/').last);
    return rangeTotal ?? ((response.contentLength ?? 0) + existingBytes);
  }
}
