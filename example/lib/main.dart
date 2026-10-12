import 'package:flutter/widgets.dart';

import 'qa_app.dart';
import 'qa_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await QaServices.create();
  runApp(QaApp(services: services));
}
