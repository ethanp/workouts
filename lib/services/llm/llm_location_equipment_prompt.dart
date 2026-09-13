class const LlmLocationEquipmentPrompt({
  required final String systemPrompt,
  required final String userPrompt,
  required final bool isRevision,
}) {
  factory forLocation({
    required String locationName,
    String? currentEquipment,
  }) {
    final isRevision = currentEquipment != null && currentEquipment.isNotEmpty;

    final userPrompt = StringBuffer('Location: $locationName');
    if (isRevision) {
      userPrompt.write('\nCurrent equipment: $currentEquipment');
    }

    return LlmLocationEquipmentPrompt(
      systemPrompt: isRevision ? _reviseSystemPrompt : _generateSystemPrompt,
      userPrompt: userPrompt.toString(),
      isRevision: isRevision,
    );
  }

  static const _generateSystemPrompt = '''You are a fitness equipment expert. Given a training location name, suggest what equipment is typically available there.

Respond with valid JSON only, no markdown. Structure:
{ "equipment": "comma-separated equipment list" }''';

  static const _reviseSystemPrompt = '''You are a fitness equipment expert. The user has a training location with an equipment list they have drafted. Revise and improve it:
- Add commonly available items they may have missed
- Keep the format as a comma-separated list
- Preserve the user's existing items unless clearly wrong

Respond with valid JSON only, no markdown. Structure:
{ "equipment": "comma-separated equipment list" }''';
}
