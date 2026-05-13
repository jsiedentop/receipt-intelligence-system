import 'dart:convert';

import '../ids/extract_request_id.dart';

typedef JsonMap = Map<String, dynamic>;

class ExtractResponse {
  const ExtractResponse({
    required this.requestId,
    required this.source,
    required this.warnings,
    required this.ocr,
    required this.structured,
    required this.metadata,
  });

  final ExtractRequestId requestId;
  final ExtractSource source;
  final List<Object?> warnings;
  final ExtractOcr ocr;
  final ExtractStructured structured;
  final ExtractMetadata metadata;

  factory ExtractResponse.fromJson(JsonMap json) {
    return ExtractResponse(
      requestId: ExtractRequestId(json['requestId'] as String),
      source: ExtractSource.fromJson(_asJsonMap(json['source'], 'source')),
      warnings: List<Object?>.from(json['warnings'] as List? ?? const <Object?>[]),
      ocr: ExtractOcr.fromJson(_asJsonMap(json['ocr'], 'ocr')),
      structured: ExtractStructured.fromJson(
        _asJsonMap(json['structured'] ?? const <String, Object?>{}, 'structured'),
      ),
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
      'structured': structured.toJson(),
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

class ExtractStructured {
  const ExtractStructured({
    required this.lineItems,
    required this.merchantInfo,
    required this.qrcodeTseData,
  });

  final ExtractLineItems? lineItems;
  final ExtractMerchantInfo? merchantInfo;
  final ExtractQrcodeTseData? qrcodeTseData;

  factory ExtractStructured.fromJson(JsonMap json) {
    return ExtractStructured(
      lineItems: json['lineItems'] == null
          ? null
          : ExtractLineItems.fromJson(_asJsonMap(json['lineItems'], 'structured.lineItems')),
      merchantInfo: json['merchantInfo'] == null
          ? null
          : ExtractMerchantInfo.fromJson(
              _asJsonMap(json['merchantInfo'], 'structured.merchantInfo'),
            ),
      qrcodeTseData: json['qrcode_tse_data'] == null
          ? null
          : ExtractQrcodeTseData.fromJson(
              _asJsonMap(json['qrcode_tse_data'], 'structured.qrcode_tse_data'),
            ),
    );
  }

  JsonMap toJson() {
    return {
      'lineItems': lineItems?.toJson(),
      'merchantInfo': merchantInfo?.toJson(),
      'qrcode_tse_data': qrcodeTseData?.toJson(),
    };
  }
}

class ExtractLineItems {
  const ExtractLineItems({
    required this.totalAmount,
    required this.currency,
    required this.items,
  });

  final double? totalAmount;
  final String? currency;
  final List<ExtractLineItem> items;

  factory ExtractLineItems.fromJson(JsonMap json) {
    final items = json['items'] as List? ?? const <Object?>[];
    return ExtractLineItems(
      totalAmount: _asNullableDouble(json['total_amount']),
      currency: json['currency'] as String?,
      items: items
          .map(
            (entry) => ExtractLineItem.fromJson(
              _asJsonMap(entry, 'structured.lineItems.items[]'),
            ),
          )
          .toList(growable: false),
    );
  }

  JsonMap toJson() {
    return {
      'total_amount': totalAmount,
      'currency': currency,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class ExtractLineItem {
  const ExtractLineItem({
    required this.name,
    required this.totalPrice,
    required this.category,
    required this.itemNumber,
    required this.quantity,
  });

  final String? name;
  final double? totalPrice;
  final String? category;
  final String? itemNumber;
  final int? quantity;

  factory ExtractLineItem.fromJson(JsonMap json) {
    return ExtractLineItem(
      name: json['name'] as String?,
      totalPrice: _asNullableDouble(json['total_price']),
      category: json['category'] as String?,
      itemNumber: json['item_number'] as String?,
      quantity: json['quantity'] as int?,
    );
  }

  JsonMap toJson() {
    return {
      'name': name,
      'total_price': totalPrice,
      'category': category,
      'item_number': itemNumber,
      'quantity': quantity,
    };
  }
}

class ExtractMerchantInfo {
  const ExtractMerchantInfo({
    required this.city,
    required this.postCode,
    required this.street,
    required this.ustid,
    required this.tseSerialNumber,
    required this.dateTime,
  });

  final String? city;
  final String? postCode;
  final String? street;
  final String? ustid;
  final String? tseSerialNumber;
  final String? dateTime;

  factory ExtractMerchantInfo.fromJson(JsonMap json) {
    return ExtractMerchantInfo(
      city: json['city'] as String?,
      postCode: json['post_code'] as String?,
      street: json['street'] as String?,
      ustid: json['ustid'] as String?,
      tseSerialNumber: json['tse_serial_number'] as String?,
      dateTime: json['datetime'] as String?,
    );
  }

  JsonMap toJson() {
    return {
      'city': city,
      'post_code': postCode,
      'street': street,
      'ustid': ustid,
      'tse_serial_number': tseSerialNumber,
      'datetime': dateTime,
    };
  }
}

class ExtractQrcodeTseData {
  const ExtractQrcodeTseData({
    required this.rawText,
    required this.format,
    required this.isTseQr,
    required this.parsed,
  });

  final String rawText;
  final String format;
  final bool isTseQr;
  final ExtractParsedQrcodeTseData? parsed;

  factory ExtractQrcodeTseData.fromJson(JsonMap json) {
    return ExtractQrcodeTseData(
      rawText: json['raw_text'] as String,
      format: json['format'] as String,
      isTseQr: json['is_tse_qr'] as bool,
      parsed: json['parsed'] == null
          ? null
          : ExtractParsedQrcodeTseData.fromJson(
              _asJsonMap(json['parsed'], 'structured.qrcode_tse_data.parsed'),
            ),
    );
  }

  JsonMap toJson() {
    return {
      'raw_text': rawText,
      'format': format,
      'is_tse_qr': isTseQr,
      'parsed': parsed?.toJson(),
    };
  }
}

class ExtractParsedQrcodeTseData {
  const ExtractParsedQrcodeTseData({
    required this.version,
    required this.tssSerialNumber,
    required this.receiptType,
    required this.processData,
    required this.transactionNumber,
    required this.signatureCounter,
    required this.timeStart,
    required this.timeEnd,
    required this.signatureAlgorithm,
    required this.timestampFormat,
    required this.signature,
    required this.publicKey,
  });

  final String version;
  final String tssSerialNumber;
  final String receiptType;
  final String processData;
  final String transactionNumber;
  final String signatureCounter;
  final String timeStart;
  final String timeEnd;
  final String signatureAlgorithm;
  final String timestampFormat;
  final String signature;
  final String publicKey;

  factory ExtractParsedQrcodeTseData.fromJson(JsonMap json) {
    return ExtractParsedQrcodeTseData(
      version: json['version'] as String,
      tssSerialNumber: json['tss_serial_number'] as String,
      receiptType: json['receipt_type'] as String,
      processData: json['process_data'] as String,
      transactionNumber: json['transaction_number'] as String,
      signatureCounter: json['signature_counter'] as String,
      timeStart: json['time_start'] as String,
      timeEnd: json['time_end'] as String,
      signatureAlgorithm: json['signature_algorithm'] as String,
      timestampFormat: json['timestamp_format'] as String,
      signature: json['signature'] as String,
      publicKey: json['public_key'] as String,
    );
  }

  JsonMap toJson() {
    return {
      'version': version,
      'tss_serial_number': tssSerialNumber,
      'receipt_type': receiptType,
      'process_data': processData,
      'transaction_number': transactionNumber,
      'signature_counter': signatureCounter,
      'time_start': timeStart,
      'time_end': timeEnd,
      'signature_algorithm': signatureAlgorithm,
      'timestamp_format': timestampFormat,
      'signature': signature,
      'public_key': publicKey,
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
  final double? confidence;
  final BoundingBox boundingBox;
  final List<Point> polygon;

  factory OcrElement.fromJson(JsonMap json) {
    return OcrElement(
      text: json['text'] as String,
      confidence: _asNullableDouble(json['confidence']),
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
  const ExtractModels({required this.ocr, required this.llm});

  final ExtractOcrModel ocr;
  final ExtractLlmModel? llm;

  factory ExtractModels.fromJson(JsonMap json) {
    return ExtractModels(
      ocr: ExtractOcrModel.fromJson(_asJsonMap(json['ocr'], 'models.ocr')),
      llm: json['llm'] == null
          ? null
          : ExtractLlmModel.fromJson(_asJsonMap(json['llm'], 'models.llm')),
    );
  }

  JsonMap toJson() {
    return {
      'ocr': ocr.toJson(),
      'llm': llm?.toJson(),
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

class ExtractLlmModel {
  const ExtractLlmModel({
    required this.provider,
    required this.model,
    required this.status,
  });

  final String provider;
  final String model;
  final String status;

  factory ExtractLlmModel.fromJson(JsonMap json) {
    return ExtractLlmModel(
      provider: json['provider'] as String,
      model: json['model'] as String,
      status: json['status'] as String,
    );
  }

  JsonMap toJson() {
    return {
      'provider': provider,
      'model': model,
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

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  throw FormatException('Expected numeric value or null.');
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
