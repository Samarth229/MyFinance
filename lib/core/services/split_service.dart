class SplitService {
  double calculateEqualSplit(double totalAmount, int numberOfPeople) {
    if (totalAmount <= 0) {
      throw Exception("Total amount must be greater than 0");
    }

    if (numberOfPeople <= 0) {
      throw Exception("Number of people must be greater than 0");
    }

    return totalAmount / numberOfPeople;
  }

  Map<String, double> calculateCustomSplit(
    double totalAmount,
    Map<String, double> personAmounts,
  ) {
    if (totalAmount <= 0) {
      throw Exception("Total amount must be greater than 0");
    }

    if (personAmounts.isEmpty) {
      throw Exception("At least one person must be assigned");
    }

    final sumOfAssigned =
        personAmounts.values.fold(0.0, (sum, amount) {
      if (amount <= 0) {
        throw Exception("Assigned amounts must be greater than 0");
      }
      return sum + amount;
    });

    if (sumOfAssigned > totalAmount) {
      throw Exception("Assigned amount exceeds total amount");
    }

    return personAmounts;
  }

  double calculateRemainingAmount(double total, double paid) {
    if (total < 0 || paid < 0) {
      throw Exception("Amounts cannot be negative");
    }

    final remaining = total - paid;
    return remaining < 0 ? 0 : remaining;
  }
}