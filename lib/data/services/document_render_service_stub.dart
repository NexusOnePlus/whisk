import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';

class DocumentRenderService {
  const DocumentRenderService();

  Future<RenderResult> render({
    required String environmentId,
    required WhiskFile file,
  }) async {
    return RenderResult.failed(
      'Local rendering is not available on this platform yet. Use the future cloud renderer for web builds.',
    );
  }
}
