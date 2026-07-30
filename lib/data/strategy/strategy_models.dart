class StrategyArticle {
  const StrategyArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.tags,
    required this.problem,
    required this.whyImportant,
    required this.corePrinciples,
    required this.sotongwareApplication,
    required this.scenario,
    required this.options,
    required this.reviewQuestions,
    required this.monthActions,
    required this.conclusion,
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final List<String> tags;
  final String problem;
  final String whyImportant;
  final String corePrinciples;
  final String sotongwareApplication;
  final String scenario;
  final List<StrategyOption> options;
  final List<String> reviewQuestions;
  final List<String> monthActions;
  final String conclusion;
}

class StrategyOption {
  const StrategyOption({
    required this.title,
    required this.description,
    required this.pros,
    required this.risks,
  });

  final String title;
  final String description;
  final String pros;
  final String risks;
}
