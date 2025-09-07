/// Pure Dart implementation of Y.js CRDT data structures
/// 
/// This library provides core CRDT (Conflict-free Replicated Data Type) 
/// implementations inspired by Y.js for offline-first Flutter applications.
library yjs_dart_crdt;

// Core exports
export 'src/crdt_types.dart' show Doc, Transaction, AbstractType, YMap, YArray, YText;
export 'src/id.dart' show ID, createID;
export 'src/counters.dart' show GCounter, PNCounter;