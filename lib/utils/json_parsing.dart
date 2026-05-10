import 'dart:convert';

List<String> stringListFromJsonText(String? jsonText) {
  if (jsonText == null || jsonText.isEmpty) return const [];

  try {
    final decodedList = jsonDecode(jsonText);
    return stringListFromObject(decodedList);
  } catch (_) {
    return const [];
  }
}

List<String> stringListFromObject(Object? maybeList) {
  if (maybeList is! List) return const [];
  return maybeList.whereType<String>().toList();
}

Map<String, dynamic>? jsonMapFromObject(Object? maybeMap) {
  if (maybeMap is Map<String, dynamic>) return maybeMap;
  if (maybeMap is Map) {
    try {
      return Map<String, dynamic>.from(maybeMap);
    } catch (_) {
      return null;
    }
  }
  return null;
}
