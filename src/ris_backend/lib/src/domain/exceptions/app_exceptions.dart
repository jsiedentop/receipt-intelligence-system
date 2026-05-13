sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class ClientException extends AppException {
  const ClientException(super.message, {super.cause});
}

class ValidationException extends ClientException {
  const ValidationException(super.message, {super.cause});
}

class NotFoundException extends ClientException {
  const NotFoundException(super.message, {super.cause});
}

class ConflictException extends ClientException {
  const ConflictException(super.message, {super.cause});
}

class UnsupportedMediaTypeException extends ClientException {
  const UnsupportedMediaTypeException(super.message, {super.cause});
}

class ServerException extends AppException {
  const ServerException(super.message, {super.cause});
}

class MalformedMultipartRequestException extends ValidationException {
  const MalformedMultipartRequestException(super.message, {super.cause});
}

class MissingUploadFileException extends ValidationException {
  const MissingUploadFileException(super.message, {super.cause});
}

class ReceiptNotFoundException extends NotFoundException {
  const ReceiptNotFoundException(super.message, {super.cause});
}

class MerchantNotFoundException extends NotFoundException {
  const MerchantNotFoundException(super.message, {super.cause});
}

class ReceiptItemNotFoundException extends NotFoundException {
  const ReceiptItemNotFoundException(super.message, {super.cause});
}

class ReceiptMerchantConflictException extends ConflictException {
  const ReceiptMerchantConflictException(super.message, {super.cause});
}

class ConfigurationException extends ServerException {
  const ConfigurationException(super.message, {super.cause});
}

class StorageWriteException extends ServerException {
  const StorageWriteException(super.message, {super.cause});
}

class PersistenceException extends ServerException {
  const PersistenceException(super.message, {super.cause});
}

class ExtractionFailedException extends ServerException {
  const ExtractionFailedException(super.message, {super.cause});
}
