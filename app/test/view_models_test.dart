import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models.dart';
import 'package:app/ui/forms/form_view_models.dart';

import 'support/fakes.dart';

void main() {
  test(
    'service drafts hide past suggestions, retain selections/custom rows and save mileage only',
    () async {
      final repo = FakeMaintenanceRepository();
      final vehicle = repo.data.vehicle('v');
      repo.data = repo.data.copy(
        items: [const MaintenanceItem(id: 'oil', vehicleId: 'v', description: 'Oil', months: 1)],
      );
      final vm = ServiceFormViewModel(repo, vehicle, DateTime(2026, 10, 25));
      expect(vm.mileage, isEmpty);
      expect(vm.suggestions.single.id, 'oil');
      expect(vm.selected, isEmpty);
      vm.toggle('oil', true);
      vm.custom.add('Custom');
      vm.date = '2026-10-24';
      vm.changed();
      expect(vm.suggestions, isEmpty);
      expect(vm.selected, {'oil'});
      expect(vm.custom, ['Custom']);
      vm.selected.clear();
      vm.custom.clear();
      vm.mileage = '100';
      expect(await vm.save(), isTrue);
      expect(repo.saved!.links, isEmpty);
      expect(repo.saved!.custom, isEmpty);
      expect(vm.dirty, isFalse);
      vm.dispose();
    },
  );
  test(
    'validation and connectivity failures preserve draft and map actionable field errors',
    () async {
      final repo = FakeMaintenanceRepository();
      final vm = ServiceFormViewModel(repo, repo.data.vehicle('v'), DateTime(2026, 10, 25));
      vm.mileage = '1.5';
      vm.changed();
      expect(await vm.save(), isFalse);
      expect(vm.error('mileage'), isNotNull);
      vm.mileage = '100';
      repo.error = const AppFailure(FailureKind.connectivity, 'Connect and retry.');
      expect(await vm.save(), isFalse);
      expect(vm.mileage, '100');
      expect(vm.dirty, isTrue);
      expect(vm.busy, isFalse);
      repo.error = null;
      expect(await vm.save(), isTrue);
      vm.dispose();
    },
  );
}
