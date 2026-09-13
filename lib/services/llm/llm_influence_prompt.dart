class const LlmInfluencePrompt({
  required final String systemPrompt,
  required final String userPrompt,
  required final bool isRevision,
}) {
  factory forName({
    required String name,
    String? currentDescription,
    List<String>? currentPrinciples,
  }) {
    final isRevision =
        (currentDescription?.isNotEmpty ?? false) ||
        (currentPrinciples?.isNotEmpty ?? false);

    final userPrompt = StringBuffer('Name: $name');
    if (currentDescription != null && currentDescription.isNotEmpty) {
      userPrompt.writeln('\n\nCurrent description: $currentDescription');
    }
    if (currentPrinciples != null && currentPrinciples.isNotEmpty) {
      userPrompt.writeln('\nCurrent principles:');
      for (final principle in currentPrinciples) {
        userPrompt.writeln('- $principle');
      }
    }

    return LlmInfluencePrompt(
      systemPrompt: isRevision ? _reviseSystemPrompt : _generateSystemPrompt,
      userPrompt: userPrompt.toString(),
      isRevision: isRevision,
    );
  }

  static const _generateSystemPrompt = '''You are an expert in longevity, posture, physical therapy, mobility, occupational therapy, strength, conditioning, and movement coaching.
Given a coach, program, book, or training philosophy name, provide:
1. A concise one-sentence description of who/what they are
2. 4-6 key training principles they are known for

Each principle should be a short sentence: a concise label, then a dash, then a brief explanation.

Respond with valid JSON only, no markdown. Structure:
{
  "description": "string",
  "principles": ["string", ...]
}''';

  static const _reviseSystemPrompt = '''You are an expert in longevity, posture, physical therapy, mobility, occupational therapy, strength, conditioning, and movement coaching.
The user has a training influence entry with a description and principles that they have drafted or edited. Revise and improve the content:
- Refine the description for clarity and accuracy (keep it one sentence)
- Improve, expand, or correct the principles (aim for 4-6 total)
- Preserve the user's intent — enhance, don't replace wholesale

Each principle should be a short sentence: a concise label, then a dash, then a brief explanation.

Respond with valid JSON only, no markdown. Structure:
{
  "description": "string",
  "principles": ["string", ...]
}''';
}
