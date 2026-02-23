abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

class BusinessLogicException extends AppException {
  const BusinessLogicException(super.message);
}

class AppDatabaseException extends AppException {
  const AppDatabaseException(super.message);
}