import 'dart:math';

/// Hybrid Logical Clock implementation
/// 
/// Combines physical time (wall clock) with logical counter and node ID
/// to provide better ordering and causality detection than pure vector clocks.
/// 
/// Format: (physical_time_ms, logical_counter, node_id)
class HLC {
  /// Physical timestamp in milliseconds since Unix epoch
  final int physicalTime;
  
  /// Logical counter for events within the same millisecond
  final int logicalCounter;
  
  /// Node identifier - GUID v4 for users, hardcoded for services
  final String nodeId;

  const HLC({
    required this.physicalTime,
    required this.logicalCounter,
    required this.nodeId,
  });

  /// Create HLC with current wall clock time
  factory HLC.now(String nodeId) {
    return HLC(
      physicalTime: DateTime.now().millisecondsSinceEpoch,
      logicalCounter: 0,
      nodeId: nodeId,
    );
  }

  /// Create HLC from another HLC, incrementing logical counter
  HLC increment() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    if (currentTime > physicalTime) {
      // Wall clock advanced, reset logical counter
      return HLC(
        physicalTime: currentTime,
        logicalCounter: 0,
        nodeId: nodeId,
      );
    } else {
      // Same millisecond, increment logical counter
      return HLC(
        physicalTime: physicalTime,
        logicalCounter: logicalCounter + 1,
        nodeId: nodeId,
      );
    }
  }

  /// Update HLC when receiving an event from another node
  HLC receiveEvent(HLC remoteHLC) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final newPhysicalTime = max(currentTime, max(physicalTime, remoteHLC.physicalTime));
    
    int newLogicalCounter;
    if (newPhysicalTime == remoteHLC.physicalTime && newPhysicalTime == physicalTime) {
      // All times equal, take max of logical counters and increment
      newLogicalCounter = max(logicalCounter, remoteHLC.logicalCounter) + 1;
    } else if (newPhysicalTime == remoteHLC.physicalTime) {
      // Remote time equals new time, increment remote logical counter
      newLogicalCounter = remoteHLC.logicalCounter + 1;
    } else if (newPhysicalTime == physicalTime) {
      // Local time equals new time, increment local logical counter
      newLogicalCounter = logicalCounter + 1;
    } else {
      // Physical time advanced beyond both, reset logical counter
      newLogicalCounter = 0;
    }

    return HLC(
      physicalTime: newPhysicalTime,
      logicalCounter: newLogicalCounter,
      nodeId: nodeId,
    );
  }

  /// Compare HLC for happens-before relationship
  /// Returns negative if this < other, positive if this > other, 0 if concurrent
  int compareTo(HLC other) {
    // First compare physical time
    final timeDiff = physicalTime.compareTo(other.physicalTime);
    if (timeDiff != 0) return timeDiff;
    
    // If physical time is equal, compare logical counter
    final logicalDiff = logicalCounter.compareTo(other.logicalCounter);
    if (logicalDiff != 0) return logicalDiff;
    
    // If both are equal, compare node IDs for deterministic ordering
    return nodeId.compareTo(other.nodeId);
  }

  /// Check if this HLC happens before another HLC
  bool happensBefore(HLC other) => compareTo(other) < 0;

  /// Check if this HLC happens after another HLC
  bool happensAfter(HLC other) => compareTo(other) > 0;

  /// Check if two HLCs are concurrent (neither happens before the other in a meaningful way)
  bool isConcurrentWith(HLC other) {
    return physicalTime == other.physicalTime && 
           logicalCounter == other.logicalCounter &&
           nodeId != other.nodeId;
  }

  /// Check if two HLCs represent the same logical time
  bool isEquivalentTo(HLC other) {
    return physicalTime == other.physicalTime &&
           logicalCounter == other.logicalCounter &&
           nodeId == other.nodeId;
  }

  @override
  bool operator ==(Object other) {
    return other is HLC && 
           other.physicalTime == physicalTime &&
           other.logicalCounter == logicalCounter &&
           other.nodeId == nodeId;
  }

  @override
  int get hashCode => Object.hash(physicalTime, logicalCounter, nodeId);

  @override
  String toString() => 'HLC($physicalTime:$logicalCounter@$nodeId)';

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'physicalTime': physicalTime,
      'logicalCounter': logicalCounter,
      'nodeId': nodeId,
    };
  }

  /// Create HLC from JSON
  static HLC fromJson(Map<String, dynamic> json) {
    return HLC(
      physicalTime: json['physicalTime'] as int,
      logicalCounter: json['logicalCounter'] as int,
      nodeId: json['nodeId'] as String,
    );
  }

  /// Create a copy of this HLC with different values
  HLC copyWith({
    int? physicalTime,
    int? logicalCounter,
    String? nodeId,
  }) {
    return HLC(
      physicalTime: physicalTime ?? this.physicalTime,
      logicalCounter: logicalCounter ?? this.logicalCounter,
      nodeId: nodeId ?? this.nodeId,
    );
  }
}

/// Generate a GUID v4 string for node identification
String generateGuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  
  // Set version (4) and variant bits according to RFC 4122
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant bits
  
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}