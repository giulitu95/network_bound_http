import 'package:lcov_parser/lcov_parser.dart';

const excludePaths = [];
const filename = 'coverage/lcov.info';
void main(List<String> args) async {
  try {
    final records = await Parser.parse(filename);
    var totalHits = 0;
    var totalFinds = 0;
    for (final rec in records) {
      var exclude = false;
      for (final path in excludePaths) {
        if (RegExp(path).hasMatch(rec.file?.replaceAll('\\', '/') ?? '')) {
          exclude = true;
          break;
        }
      }
      if (!exclude) {
        totalFinds += rec.lines?.found ?? 0;
        totalHits += rec.lines?.hit ?? 0;
      }
    }
    final coverage = (totalHits / totalFinds) * 100;
    print('Coverage: ${coverage.toStringAsFixed(2)}%');
  } on FileMustBeProvided {
    print('No lcov.info file found. Run "flutter test --coverage" first');
  } catch (e) {
    print(e);
  }
}
