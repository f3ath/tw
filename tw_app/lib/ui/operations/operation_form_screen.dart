import 'package:material_ui/material_ui.dart';
import 'package:tw_app/app/operation_repo.dart';
import 'package:tw_app/app/repository_provider.dart';
import 'package:tw_app/app/vehicle_service.dart';
import 'package:tw_app/ui/form/form_submission_controller.dart';

class const OperationFormScreen({super.key, required final VehicleService vehicleService})
    extends StatefulWidget {
  static const nameFieldKey = ValueKey('operation-name-field');
  static const detailsFieldKey = ValueKey('operation-details-field');
  static const saveButtonKey = ValueKey('operation-save-button');
  static const errorSnackBarKey = ValueKey('operation-save-error-snackbar');

  @override
  State<OperationFormScreen> createState() => _OperationFormScreenState();
}

class _OperationFormScreenState extends State<OperationFormScreen> {
  late final OperationRepo _repo = RepositoryProvider.read(context).operationRepo;
  final _formKey = GlobalKey<FormState>();
  final _submission = FormSubmissionController();
  var _name = '';
  var _details = '';

  @override
  void dispose() {
    _submission.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _submission,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('New Operation')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              Text(
                widget.vehicleService.vehicle.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                MaterialLocalizations.of(context)
                    .formatShortDate(widget.vehicleService.service.date),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: OperationFormScreen.nameFieldKey,
                enabled: !_submission.isSubmitting,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Please name the operation' : null,
                onSaved: (value) => _name = value!.trim(),
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                key: OperationFormScreen.detailsFieldKey,
                enabled: !_submission.isSubmitting,
                onSaved: (value) => _details = value?.trim() ?? '',
                decoration: const InputDecoration(labelText: 'Details (optional)'),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: OperationFormScreen.saveButtonKey,
                onPressed: _submission.isSubmitting ? null : _saveForm,
                child: Text(_submission.isSubmitting ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _saveForm() async {
    if (_submission.isSubmitting) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    final saved = await _submission.submit(_persistOperation);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else if (_submission.hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: OperationFormScreen.errorSnackBarKey,
            content: Text('Save failed. Please try again.'),
          ),
        );
    }
  }

  Future<void> _persistOperation() =>
      _repo.create(widget.vehicleService.service.id, name: _name, details: _details);
}
