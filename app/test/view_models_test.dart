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
        items: [
          const Schedule(
            id: 'oil',
            vehicleId: 'v',
            name: 'Oil',
            intervalMonths: 1,
            details: '',
            intervalDistance: null,
          ),
        ],
      );
      final vm = ServiceFormViewModel(repo, vehicle, DateTime(2026, 10, 25));
      expect(vm.odometer, isEmpty);
      expect(vm.suggestions.single.id, 'oil');
      expect(vm.selected, isEmpty);
      vm.toggle('oil', true);
      vm.custom.add(OperationDraft('custom', name: 'Custom'));
      vm.date = '2026-10-24';
      vm.changed();
      expect(vm.suggestions, isEmpty);
      expect(vm.selected, {'oil'});
      expect(vm.custom.map((draft) => draft.name), ['Custom']);
      vm.selected.clear();
      vm.custom.clear();
      vm.odometer = '100';
      expect(await vm.save(), isTrue);
      expect(repo.savedOperations, isEmpty);
      expect(vm.dirty, isFalse);
      vm.dispose();
    },
  );
  test(
    'validation and connectivity failures preserve draft and map actionable field errors',
    () async {
      final repo = FakeMaintenanceRepository();
      final vm = ServiceFormViewModel(repo, repo.data.vehicle('v'), DateTime(2026, 10, 25));
      vm.odometer = '1.5';
      vm.changed();
      expect(await vm.save(), isFalse);
      expect(vm.error('mileage'), isNotNull);
      vm.odometer = '100';
      repo.error = const AppFailure(FailureKind.connectivity, 'Connect and retry.');
      expect(await vm.save(), isFalse);
      expect(vm.odometer, '100');
      expect(vm.dirty, isTrue);
      expect(vm.busy, isFalse);
      repo.error = null;
      expect(await vm.save(), isTrue);
      vm.dispose();
    },
  );
  test('editing retains operation IDs, archived selections, and custom name/details', () async {
    final repo = FakeMaintenanceRepository();
    final service = Service(
      'existing',
      vehicleId: 'v',
      date: DateTime(2026, 10, 24),
      odometer: 100,
      details: 'Retained',
    );
    repo.data = repo.data.copy(
      items: [
        const Schedule(
          id: 'oil',
          vehicleId: 'v',
          name: 'Oil',
          details: 'Schedule details',
          intervalDistance: 5000,
          intervalMonths: null,
          isArchived: true,
        ),
      ],
      services: [service],
      operations: [
        const Operation(
          'linked',
          serviceId: 'existing',
          scheduleId: 'oil',
          name: 'Oil',
          details: '',
        ),
        const Operation('custom', serviceId: 'existing', name: 'Wash car', details: 'Old details'),
      ],
    );
    final vm = ServiceFormViewModel(
      repo,
      repo.data.vehicle('v'),
      DateTime(2026, 10, 25),
      original: service,
    );
    expect(vm.selected, {'oil'});
    expect(vm.others.single.isArchived, isTrue);
    expect(vm.custom.single.details, 'Old details');
    vm.custom.single.name = 'Hand wash';
    vm.custom.single.details = 'Use soap';
    vm.custom.add(OperationDraft('blank', name: '  ', details: 'Ignored'));
    expect(await vm.save(), isTrue);
    expect(repo.saved!.id, service.id);
    expect(repo.saved!.details, 'Retained');
    expect(repo.savedOperations.map((operation) => operation.id), ['linked', 'custom']);
    expect(repo.savedOperations.first.details, 'Schedule details');
    expect(repo.savedOperations.last.name, 'Hand wash');
    expect(repo.savedOperations.last.details, 'Use soap');
    vm.dispose();
  });
}
