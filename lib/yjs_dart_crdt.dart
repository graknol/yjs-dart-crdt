/// Pure Dart implementation of Y.js CRDT data structures
/// 
/// This library provides core CRDT (Conflict-free Replicated Data Type) 
/// implementations inspired by Y.js for offline-first Flutter applications.
library yjs_dart_crdt;

// Core exports
export 'src/structs.dart' show Doc, Transaction, AbstractType;
export 'src/id.dart' show ID, createID;

// CRDT types
export 'src/y_map.dart';
export 'src/y_array.dart';
export 'src/y_text.dart';