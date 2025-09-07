/// CRDT Counter implementations for collaborative counting
///
/// Provides GCounter (grow-only) and PNCounter (positive-negative)
/// for use in collaborative applications.

/// G-Counter (Grow-only Counter) CRDT
///
/// A counter that can only be incremented and never decremented.
/// Each client has its own increment counter, and the total value
/// is the sum of all client counters.
class GCounter {
  /// Map from client ID to their current count
  final Map<int, int> _state = {};

  /// Create a new G-Counter
  GCounter([Map<int, int>? initialState]) {
    if (initialState != null) {
      _state.addAll(initialState);
    }
  }

  /// Get the current total value
  int get value {
    return _state.values.fold(0, (sum, count) => sum + count);
  }

  /// Increment the counter for a given client
  void increment(int clientId, [int amount = 1]) {
    if (amount < 0) {
      throw ArgumentError(
          'GCounter can only increment by non-negative amounts');
    }
    _state[clientId] = (_state[clientId] ?? 0) + amount;
  }

  /// Merge with another G-Counter
  void merge(GCounter other) {
    for (final entry in other._state.entries) {
      final clientId = entry.key;
      final otherCount = entry.value;
      final currentCount = _state[clientId] ?? 0;

      // Take the maximum (grow-only property)
      _state[clientId] = currentCount > otherCount ? currentCount : otherCount;
    }
  }

  /// Get a copy of the internal state
  Map<int, int> getState() => Map.from(_state);

  /// Create a copy of this counter
  GCounter copy() => GCounter(getState());

  /// Convert to JSON representation
  Map<String, dynamic> toJSON() => {
        'type': 'GCounter',
        'state': _state,
        'value': value,
      };

  /// Create from JSON representation
  static GCounter fromJSON(Map<String, dynamic> json) {
    final state = json['state'] as Map<String, dynamic>?;
    if (state != null) {
      final intState = state.map((k, v) => MapEntry(int.parse(k), v as int));
      return GCounter(intState);
    }
    return GCounter();
  }

  @override
  String toString() => 'GCounter(value: $value, state: $_state)';

  @override
  bool operator ==(Object other) {
    if (other is! GCounter) return false;
    if (_state.length != other._state.length) return false;

    for (final entry in _state.entries) {
      if (other._state[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_state.entries);
}

/// PN-Counter (Positive-Negative Counter) CRDT
///
/// A counter that supports both increments and decrements.
/// Implemented using two G-Counters: one for increments, one for decrements.
/// The value is the difference between the two.
class PNCounter {
  /// G-Counter for positive increments
  final GCounter _positive = GCounter();

  /// G-Counter for negative increments (decrements)
  final GCounter _negative = GCounter();

  /// Create a new PN-Counter
  PNCounter([Map<int, int>? positiveState, Map<int, int>? negativeState]) {
    if (positiveState != null) {
      _positive._state.addAll(positiveState);
    }
    if (negativeState != null) {
      _negative._state.addAll(negativeState);
    }
  }

  /// Get the current value (positive - negative)
  int get value => _positive.value - _negative.value;

  /// Increment the counter for a given client
  void increment(int clientId, [int amount = 1]) {
    if (amount < 0) {
      throw ArgumentError('Use decrement() for negative amounts');
    }
    _positive.increment(clientId, amount);
  }

  /// Decrement the counter for a given client
  void decrement(int clientId, [int amount = 1]) {
    if (amount < 0) {
      throw ArgumentError('Decrement amount must be positive');
    }
    _negative.increment(clientId, amount);
  }

  /// Add a value (positive or negative) for a given client
  void add(int clientId, int amount) {
    if (amount >= 0) {
      increment(clientId, amount);
    } else {
      decrement(clientId, -amount);
    }
  }

  /// Merge with another PN-Counter
  void merge(PNCounter other) {
    _positive.merge(other._positive);
    _negative.merge(other._negative);
  }

  /// Get a copy of the internal state
  Map<String, Map<int, int>> getState() => {
        'positive': _positive.getState(),
        'negative': _negative.getState(),
      };

  /// Create a copy of this counter
  PNCounter copy() {
    final state = getState();
    return PNCounter(state['positive'], state['negative']);
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJSON() => {
        'type': 'PNCounter',
        'positive': _positive.getState(),
        'negative': _negative.getState(),
        'value': value,
      };

  /// Create from JSON representation
  static PNCounter fromJSON(Map<String, dynamic> json) {
    final positive = json['positive'] as Map<String, dynamic>?;
    final negative = json['negative'] as Map<String, dynamic>?;

    Map<int, int>? positiveState;
    Map<int, int>? negativeState;

    if (positive != null) {
      positiveState = positive.map((k, v) => MapEntry(int.parse(k), v as int));
    }
    if (negative != null) {
      negativeState = negative.map((k, v) => MapEntry(int.parse(k), v as int));
    }

    return PNCounter(positiveState, negativeState);
  }

  @override
  String toString() =>
      'PNCounter(value: $value, positive: ${_positive.value}, negative: ${_negative.value})';

  @override
  bool operator ==(Object other) {
    if (other is! PNCounter) return false;
    return _positive == other._positive && _negative == other._negative;
  }

  @override
  int get hashCode => Object.hash(_positive, _negative);
}
