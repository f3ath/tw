import 'package:flutter/material.dart';

import 'app/composition.dart';
import 'app/torque_wrench_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TorqueWrenchApp(composition: Composition.local()));
}
