/// Core ID system for CRDT operations
///
/// Based on Lamport timestamps with clientID and logical clock
class ID {
  final int client;
  final int clock;

  const ID(this.client, this.clock);

  @override
  bool operator ==(Object other) {
    return other is ID && other.client == client && other.clock == clock;
  }

  @override
  int get hashCode => Object.hash(client, clock);

  @override
  String toString() => 'ID($client:$clock)';

  /// Compare two IDs for ordering
  int compareTo(ID other) {
    final clockDiff = clock.compareTo(other.clock);
    if (clockDiff != 0) return clockDiff;
    return client.compareTo(other.client);
  }
}

/// Creates a new ID
ID createID(int client, int clock) => ID(client, clock);

/// Compare two IDs for equality
bool compareIDs(ID? a, ID? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a == b;
}
