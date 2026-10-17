import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('i colori restano indipendenti durante aggiornamento', () {
    final data = Match(
      id: 'test',
      format: 2,
      names: ['A', 'B'],
      teams: [
        ['a', 'b'],
        ['c', 'd']
      ],
    ).toJson();

    final first = Match.fromJson(data);
    final second = Match.fromJson(data);
    final colors = List<int>.from(second.teamColors);

    first.teamColors.clear();
    first.teamColors.addAll(second.teamColors);

    expect(first.teamColors, colors);
    expect(second.teamColors, colors);
    expect(data['teamColors'], colors);

    first.presetIds[0] = 'preset';
    expect(second.presetIds[0], isNull);
    expect((data['presetIds'] as List)[0], isNull);
  });
}
