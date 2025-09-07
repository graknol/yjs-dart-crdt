/// Pure Dart implementation of Y.js CRDT data structures with Hybrid Logical Clocks
/// 
/// This library provides core CRDT (Conflict-free Replicated Data Type) 
/// implementations inspired by Y.js for offline-first Flutter applications.
/// 
/// Features Hybrid Logical Clocks (HLC) for better causality tracking and
/// server synchronization with millisecond precision physical time,
/// logical counters, and configurable node IDs (GUID v4 or hardcoded).
library yjs_dart_crdt;

// Core exports
export 'src/crdt_types.dart' show Doc, Transaction, AbstractType, YMap, YArray, YText;
export 'src/id.dart' show ID, createID, createIDLegacy;
export 'src/hlc.dart' show HLC, generateGuidV4;
export 'src/counters.dart' show GCounter, PNCounter;
export 'src/encoding.dart' show BinaryEncoder;