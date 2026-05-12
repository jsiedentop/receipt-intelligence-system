import 'dart:convert';

import '../ids/extract_request_id.dart';

typedef JsonMap = Map<String, dynamic>;

class ExtractResponse {
  const ExtractResponse({
    required this.requestId,
    required this.source,
    required this.warnings,
    required this.ocr,
    required this.metadata,
  });

  final ExtractRequestId requestId;
  final ExtractSource source;
  final List<Object?> warnings;
  final ExtractOcr ocr;
  final ExtractMetadata metadata;

  factory ExtractResponse.fromJson(JsonMap json) {
    return ExtractResponse(
      requestId: ExtractRequestId(json['requestId'] as String),
      source: ExtractSource.fromJson(_asJsonMap(json['source'], 'source')),
      warnings: List<Object?>.from(json['warnings'] as List? ?? const <Object?>[]),
      ocr: ExtractOcr.fromJson(_asJsonMap(json['ocr'], 'ocr')),
      metadata: ExtractMetadata.fromJson(
        _asJsonMap(json['metadata'], 'metadata'),
      ),
    );
  }

  factory ExtractResponse.fromJsonString(String source) {
    return ExtractResponse.fromJson(
      _asJsonMap(jsonDecode(source), 'extract response'),
    );
  }

  JsonMap toJson() {
    return {
      'requestId': requestId.value,
      'source': source.toJson(),
      'warnings': warnings,
      'ocr': ocr.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}

class ExtractSource {
  const ExtractSource({
    required this.fileName,
    required this.filePath,
    required this.mimeType,
  });

  final String fileName;
  final String filePath;
  final String mimeType;

  factory ExtractSource.fromJson(JsonMap json) {
    return ExtractSource(
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      mimeType: json['mimeType'] as String,
    );
  }

  JsonMap toJson() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'mimeType': mimeType,
    };
  }
}

class ExtractOcr {
  const ExtractOcr({
    required this.rawText,
    required this.blocks,
    required this.lines,
  });

  final String rawText;
  final List<OcrElement> blocks;
  final List<OcrElement> lines;

  factory ExtractOcr.fromJson(JsonMap json) {
    return ExtractOcr(
      rawText: json['rawText'] as String,
      blocks: _parseOcrElements(json['blocks']),
      lines: _parseOcrElements(json['lines']),
    );
  }

  JsonMap toJson() {
    return {
      'rawText': rawText,
      'blocks': blocks.map((element) => element.toJson()).toList(),
      'lines': lines.map((element) => element.toJson()).toList(),
    };
  }
}

class OcrElement {
  const OcrElement({
    required this.text,
    required this.confidence,
    required this.boundingBox,
    required this.polygon,
  });

  final String text;
  final double confidence;
  final BoundingBox boundingBox;
  final List<Point> polygon;

  factory OcrElement.fromJson(JsonMap json) {
    return OcrElement(
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: BoundingBox.fromJson(
        _asJsonMap(json['boundingBox'], 'boundingBox'),
      ),
      polygon: _parsePoints(json['polygon']),
    );
  }

  JsonMap toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'boundingBox': boundingBox.toJson(),
      'polygon': polygon.map((point) => point.toJson()).toList(),
    };
  }
}

class BoundingBox {
  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory BoundingBox.fromJson(JsonMap json) {
    return BoundingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  JsonMap toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

class Point {
  const Point({required this.x, required this.y});

  final double x;
  final double y;

  factory Point.fromJson(JsonMap json) {
    return Point(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  JsonMap toJson() {
    return {
      'x': x,
      'y': y,
    };
  }
}

class ExtractMetadata {
  const ExtractMetadata({
    required this.extractor,
    required this.version,
    required this.models,
    required this.runtime,
  });

  final String extractor;
  final String version;
  final ExtractModels models;
  final ExtractRuntime runtime;

  factory ExtractMetadata.fromJson(JsonMap json) {
    return ExtractMetadata(
      extractor: json['extractor'] as String,
      version: json['version'] as String,
      models: ExtractModels.fromJson(_asJsonMap(json['models'], 'models')),
      runtime: ExtractRuntime.fromJson(_asJsonMap(json['runtime'], 'runtime')),
    );
  }

  JsonMap toJson() {
    return {
      'extractor': extractor,
      'version': version,
      'models': models.toJson(),
      'runtime': runtime.toJson(),
    };
  }
}

class ExtractModels {
  const ExtractModels({required this.ocr});

  final ExtractOcrModel ocr;

  factory ExtractModels.fromJson(JsonMap json) {
    return ExtractModels(
      ocr: ExtractOcrModel.fromJson(_asJsonMap(json['ocr'], 'models.ocr')),
    );
  }

  JsonMap toJson() {
    return {
      'ocr': ocr.toJson(),
    };
  }
}

class ExtractOcrModel {
  const ExtractOcrModel({
    required this.name,
    required this.textDetectionModel,
    required this.textRecognitionModel,
    required this.status,
  });

  final String name;
  final String textDetectionModel;
  final String textRecognitionModel;
  final String status;

  factory ExtractOcrModel.fromJson(JsonMap json) {
    return ExtractOcrModel(
      name: json['name'] as String,
      textDetectionModel: json['textDetectionModel'] as String,
      textRecognitionModel: json['textRecognitionModel'] as String,
      status: json['status'] as String,
    );
  }

  JsonMap toJson() {
    return {
      'name': name,
      'textDetectionModel': textDetectionModel,
      'textRecognitionModel': textRecognitionModel,
      'status': status,
    };
  }
}

class ExtractRuntime {
  const ExtractRuntime({required this.python, required this.platform});

  final String python;
  final String platform;

  factory ExtractRuntime.fromJson(JsonMap json) {
    return ExtractRuntime(
      python: json['python'] as String,
      platform: json['platform'] as String,
    );
  }

  JsonMap toJson() {
    return {
      'python': python,
      'platform': platform,
    };
  }
}

List<OcrElement> _parseOcrElements(Object? value) {
  final list = value as List? ?? const <Object?>[];
  return list
      .map((element) => OcrElement.fromJson(_asJsonMap(element, 'ocr element')))
      .toList(growable: false);
}

List<Point> _parsePoints(Object? value) {
  final list = value as List? ?? const <Object?>[];
  return list
      .map((element) => Point.fromJson(_asJsonMap(element, 'point')))
      .toList(growable: false);
}

JsonMap _asJsonMap(Object? value, String fieldName) {
  if (value is JsonMap) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
  }

  throw FormatException('Expected $fieldName to be a JSON object.');
}
