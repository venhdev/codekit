import 'package:colored_logger/colored_logger.dart';

void main() {
  // Basic usage with predefined log levels
  ColoredLogger.info('This is an info message');
  ColoredLogger.success('Operation completed successfully');
  ColoredLogger.warning('This is a warning message');
  ColoredLogger.error('An error occurred');

  // Display ANSI support information
  showAnsiInfo();

  // Custom styling with Ansi class
  print('\n=== Custom Styling Examples ===');

  // Using ColoredLogger.colorize
  ColoredLogger.colorize(
    'Custom message with bold and cyan text',
    styles: [Ansi.bold, Ansi.cyan],
    prefix: '[STYLED] ',
  );

  // Using extension methods
  print('Hello'.red());
  print('World'.blue.bold());

  // Chaining styles
  print('Chained styles'.bold.italic.green());

  // Using 256-color support
  print('256-color text'.fg256(201)());

  // Using RGB color support
  print('RGB color text'.fgRgb(255, 100, 0)());

  // Rainbow effect
  print('Rainbow text'.rainbow());
}
