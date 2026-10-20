class OverlayFields {
  const OverlayFields({
    this.value = true,
    this.perKm = true,
    this.perHour = true,
    this.perMinute = true,
    this.distance = true,
    this.time = true,
    this.category = true,
    this.origin = true,
    this.destination = true,
  });

  final bool value;
  final bool perKm;
  final bool perHour;
  final bool perMinute;
  final bool distance;
  final bool time;
  final bool category;
  final bool origin;
  final bool destination;

  factory OverlayFields.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    bool read(String key) => source[key] is bool ? source[key] as bool : true;
    return OverlayFields(
      value: read('value'),
      perKm: read('perKm'),
      perHour: read('perHour'),
      perMinute: read('perMinute'),
      distance: read('distance'),
      time: read('time'),
      category: read('category'),
      origin: read('origin'),
      destination: read('destination'),
    );
  }

  Map<String, bool> toMap() => {
        'value': value,
        'perKm': perKm,
        'perHour': perHour,
        'perMinute': perMinute,
        'distance': distance,
        'time': time,
        'category': category,
        'origin': origin,
        'destination': destination,
      };

  OverlayFields copyWith({
    bool? value,
    bool? perKm,
    bool? perHour,
    bool? perMinute,
    bool? distance,
    bool? time,
    bool? category,
    bool? origin,
    bool? destination,
  }) =>
      OverlayFields(
        value: value ?? this.value,
        perKm: perKm ?? this.perKm,
        perHour: perHour ?? this.perHour,
        perMinute: perMinute ?? this.perMinute,
        distance: distance ?? this.distance,
        time: time ?? this.time,
        category: category ?? this.category,
        origin: origin ?? this.origin,
        destination: destination ?? this.destination,
      );
}
