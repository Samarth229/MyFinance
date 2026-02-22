import '../exceptions/app_exceptions.dart';

class SplitService {
  double calculateEqualSplit(double totalAmount, int numberOfPeople) {
    if (totalAmount <= 0) {
      throw const ValidationException(
          "Total amount must be greater than 0");
    }

    if (numberOfPeople <= 0) {
      throw const ValidationException(
          "Number of people must be greater than 0");
    }

    return totalAmount / numberOfPeople;
  }

  Map<String, double> calculateCustomSplit(
      double totalAmount,
      Map<String, double> personAmounts) {
    if (totalAmount <= 0) {
      throw const ValidationException(
          "Total amount must be greater than 0");
    }

    if (personAmounts.isEmpty) {
      throw const ValidationException(
          "Custom split cannot be empty");
    }

    final sumOfAssigned =
        personAmounts.values.fold(0.0, (sum, amount) => sum + amount);

    if (sumOfAssigned > totalAmount) {
      throw const BusinessLogicException(
          "Assigned amount exceeds total amount");
    }

    return personAmounts;
  }

  double calculateRemainingAmount(double total, double paid) {
    if (total < 0 || paid < 0) {
      throw const ValidationException(
          "Amounts cannot be negative");
    }

    final remaining = total - paid;

    return remaining < 0 ? 0 : remaining;
  }
}