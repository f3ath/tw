import 'package:material_ui/material_ui.dart';
import 'package:tw_app/time/clock.dart';

/// Date picker which displays the selected date as text
class const DateFormField({
  super.key,
  super.initialValue,
  super.validator,
  super.onSaved,
  required final String Function(DateTime?) _format,
  required final DateTime _firstDate,
  required final DateTime _lastDate,
  final InputDecoration? _decoration = const InputDecoration(),
  final Clock _clock = const Clock(),
}) extends FormField<DateTime> {
  this : super(builder: _builder);

  @override
  FormFieldState<DateTime> createState() => _DateFormFieldState();

  static Widget _builder(FormFieldState<DateTime> state) =>
      (state as _DateFormFieldState)._buildInput();
}

class _DateFormFieldState extends FormFieldState<DateTime> {
  late final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget._format(value);
  }

  @override
  void didChange(DateTime? value) {
    super.didChange(value);
    _controller.text = widget._format(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    _controller.text = widget._format(value);
  }

  @override
  DateFormField get widget => super.widget as DateFormField;

  Widget _buildInput() => TextField(
    controller: _controller,
    readOnly: true,
    onTap: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: value ?? widget._clock.now(),
        firstDate: widget._firstDate,
        lastDate: widget._lastDate,
      );
      if (!mounted || selected == null) return;
      didChange(selected);
    },
    decoration: (widget._decoration ?? const InputDecoration()).copyWith(errorText: errorText),
  );
}
