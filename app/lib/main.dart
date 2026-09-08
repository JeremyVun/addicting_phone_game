import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await bootstrap();
  final controller = AppController(services);
  await controller.start();
  runApp(SettleApp(controller));
}
