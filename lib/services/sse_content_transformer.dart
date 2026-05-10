import 'dart:async';
import 'dart:convert';

/// Transforms a raw SSE byte stream into content-token strings.
/// Each emitted string is the content delta from one SSE chunk.
/// Closes when `[DONE]` is received.
class SseContentTransformer extends StreamTransformerBase<List<int>, String> {
  @override
  Stream<String> bind(Stream<List<int>> byteStream) {
    final controller = StreamController<String>();
    final lineBuffer = StringBuffer();

    byteStream
        .transform(utf8.decoder)
        .listen(
          (textChunk) {
            lineBuffer.write(textChunk);
            final buffered = lineBuffer.toString();
            final lines = buffered.split('\n');

            lineBuffer.clear();
            lineBuffer.write(lines.last);

            for (var i = 0; i < lines.length - 1; i++) {
              final line = lines[i].trim();
              if (line.isEmpty) continue;
              if (!line.startsWith('data: ')) continue;

              final payload = line.substring(6);
              if (payload == '[DONE]') {
                controller.close();
                return;
              }

              try {
                final json = jsonDecode(payload) as Map<String, dynamic>;
                final choices = json['choices'] as List<dynamic>?;
                if (choices == null || choices.isEmpty) continue;
                final delta = choices[0]['delta'] as Map<String, dynamic>?;
                if (delta == null) continue;
                final content = delta['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  controller.add(content);
                }
              } catch (_) {
                // Skip malformed SSE chunks
              }
            }
          },
          onError: controller.addError,
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
        );

    return controller.stream;
  }
}
