import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/models/collection_progress.dart';
import 'package:profesor_go/core/repositories/professor_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('offline collection progress stays within its account', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProfessorCache(userId: 'student-one');
    await first.saveProgress(const CollectionProgress(
      captured: 3, total: 10, completed: false,
    ));

    final second = ProfessorCache(userId: 'student-two');
    await second.ensureLoaded();
    expect(second.progress, isNull);

    final firstReopened = ProfessorCache(userId: 'student-one');
    await firstReopened.ensureLoaded();
    expect(firstReopened.progress?.captured, 3);
    await firstReopened.clear();
    final afterLogout = ProfessorCache(userId: 'student-one');
    await afterLogout.ensureLoaded();
    expect(afterLogout.progress, isNull);
  });
}
