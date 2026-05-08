/// Canonical season-points computation for the RHBL system.
///
/// Each tournament awards points using `teamCount - placement + 1`
/// (see `tournament_results_screen._calculatePoints`). A team's
/// season total is the sum of its best-N (default 3) tournament results
/// from its `pointsHistory` list.
int computeBest3Points(
  List<Map<String, dynamic>> pointsHistory, {
  int bestN = 3,
}) {
  final sortedPoints = List<Map<String, dynamic>>.from(pointsHistory);
  sortedPoints.sort((a, b) {
    final pointsA = a['points'] as int? ?? 0;
    final pointsB = b['points'] as int? ?? 0;
    return pointsB.compareTo(pointsA);
  });

  return sortedPoints
      .take(bestN)
      .fold<int>(0, (sum, entry) => sum + (entry['points'] as int? ?? 0));
}
