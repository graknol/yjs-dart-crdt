import 'hlc.dart';

/// Core ID system for CRDT operations
/// 
/// Based on Hybrid Logical Clocks for better causality tracking
class ID {
  final HLC hlc;

  const ID(this.hlc);

  /// Legacy constructor support - converts client+clock to HLC
  factory ID.legacy(int client, int clock) {
    // Convert legacy integer client ID to string node ID
    final nodeId = 'legacy-$client';
    return ID(HLC(
      physicalTime: clock * 1000, // Convert logical clock to fake milliseconds
      logicalCounter: 0,
      nodeId: nodeId,
    ));
  }

  /// Convenience getters for backward compatibility
  String get client => hlc.nodeId;
  int get clock => hlc.physicalTime;

  @override
  bool operator ==(Object other) {
    return other is ID && other.hlc == hlc;
  }

  @override
  int get hashCode => hlc.hashCode;

  @override
  String toString() => 'ID(${hlc.toString()})';

  /// Compare two IDs for ordering using HLC comparison
  int compareTo(ID other) {
    return hlc.compareTo(other.hlc);
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {'hlc': hlc.toJson()};
  }

  /// Create ID from JSON
  static ID fromJson(Map<String, dynamic> json) {
    return ID(HLC.fromJson(json['hlc'] as Map<String, dynamic>));
  }
}

/// Creates a new ID with HLC
ID createID(HLC hlc) => ID(hlc);

/// Creates a new ID with legacy support
ID createIDLegacy(int client, int clock) => ID.legacy(client, clock);

/// Compare two IDs for equality
bool compareIDs(ID? a, ID? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a == b;
}