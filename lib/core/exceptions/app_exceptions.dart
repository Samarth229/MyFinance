abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(String message) : super(message);
}

class NotFoundException extends AppException {
  const NotFoundException(String message) : super(message);
}

class AppDatabaseException extends AppException {
  const AppDatabaseException(String message) : super(message);
}

class BusinessLogicException extends AppException {
  const BusinessLogicException(String message) : super(message);
}