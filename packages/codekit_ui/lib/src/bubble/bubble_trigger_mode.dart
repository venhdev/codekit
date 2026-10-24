/// Defines how the diagnostic bubble reveals itself when [CodeKitBubble.enabled] is true.
enum BubbleTriggerMode {
  /// Bubble is immediately visible on screen as long as enabled is true.
  immediate('Immediate'),

  /// Bubble starts hidden; shaking the device toggles its visibility.
  shakeToToggle('Shake to toggle');

  const BubbleTriggerMode(this.label);

  /// Human-readable display label.
  final String label;

  /// Whether this mode starts with the bubble hidden until a shake event occurs.
  bool get startsHidden => this == BubbleTriggerMode.shakeToToggle;
}
