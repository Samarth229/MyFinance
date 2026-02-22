class SplitService {
  double calculateEqualSplit(double totalAmount, int numberOfPeople) {
    if (numberOfPeople <= 0) {
      throw Exception("Number of people must be greater than 0");
    }

    return totalAmount / numberOfPeople;
  }

  Map<String, double> calculateCustomSplit(
    double totalAmount,
    Map<String, double> personAmounts,
  ) {
    final sumOfAssigned =
        personAmounts.values.fold(0.0, (sum, amount) => sum + amount);

    if (sumOfAssigned > totalAmount) {
      throw Exception("Assigned amount exceeds total amount");
    }

    return personAmounts;
  }

  double calculateRemainingAmount(double total, double paid) {
    final remaining = total - paid;
    return remaining < 0 ? 0 : remaining;
  }
}