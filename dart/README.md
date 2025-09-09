# Y.js Dart CRDT

A pure Dart implementation of Y.js core CRDT (Conflict-free Replicated Data Type) data structures for offline-first Flutter applications. Features Hybrid Logical Clocks for enhanced server synchronization and causality tracking.

## Features

- **YMap**: Collaborative map/dictionary with last-write-wins semantics
- **YArray**: Collaborative array with insertion-order preservation  
- **YText**: Collaborative text editing with character-level operations
- **GCounter**: Grow-only counter for collaborative increment operations
- **PNCounter**: Positive-negative counter supporting increment/decrement
- **Hybrid Logical Clocks**: Advanced causality tracking with millisecond precision
- **Delta Synchronization**: Efficient incremental updates instead of full document state
- **Node ID Support**: GUID v4 for users, configurable hardcoded IDs for services  
- **Serialization**: Document state export/import with JSON and binary formats
- **Server Integration Ready**: HLC-based synchronization for multi-client coordination
- **Pure Dart**: No external dependencies, Flutter-compatible
- **Offline-first**: Local operations with built-in conflict resolution
- **Type-safe**: Full Dart generics support
- **Backward Compatible**: Legacy clientID support for existing implementations

## Quick Start

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  yjs_dart_crdt: ^0.1.0
```

### Basic Usage

```dart
import 'package:yjs_dart_crdt/yjs_dart_crdt.dart';

void main() {
  // Create a document
  final doc = Doc();
  
  // Create and use a YMap
  final map = YMap();
  doc.share('myMap', map);
  
  map.set('name', 'Alice');
  map.set('age', 30);
  print(map.toJSON()); // {name: Alice, age: 30}
  
  // Create and use a YArray
  final array = YArray<String>();
  doc.share('myArray', array);
  
  array.push('apple');
  array.insert(0, 'banana');
  print(array.toList()); // [banana, apple]
  
  // Create and use YText
  final text = YText('Hello');
  doc.share('myText', text);
  
  text.insert(5, ' World!');
  print(text.toString()); // Hello World!
  
  // Use counters for collaborative progress tracking
  final progress = GCounter();
  progress.increment(doc.clientID, 25); // 25% progress
  map.set('progress', progress);
  
  final hours = PNCounter();
  hours.increment(doc.clientID, 8);  // 8 hours worked
  hours.decrement(doc.clientID, 1);  // Correction: -1 hour
  map.set('hours_logged', hours);
  
  print('Progress: ${progress.value}%'); // 25%
  print('Hours: ${hours.value}');       // 7
}
```

## API Reference

### Doc

The document container that manages CRDT types and operations.

```dart
final doc = Doc(); // Creates with GUID v4 node ID
final doc = Doc(clientID: 12345); // Legacy: converts to 'legacy-12345' node ID  
final doc = Doc(nodeId: 'server-1'); // Custom node ID (for services)

// Share a CRDT type
doc.share('key', yMapInstance);

// Get shared type
final sharedMap = doc.get<YMap>('key');

// Execute operations in a transaction
doc.transact((transaction) {
  map.set('key1', 'value1');
  map.set('key2', 'value2');
});
```

### Hybrid Logical Clocks

Advanced causality tracking for server synchronization.

```dart
// Create HLC with current time
final hlc = HLC.now('client-1');
print(hlc); // HLC(1234567890:0@client-1)

// HLC operations
final nextHLC = hlc.increment();
final receivedHLC = hlc.receiveEvent(remoteHLC);

// Causality comparison
if (hlc1.happensBefore(hlc2)) {
  print('hlc1 happened before hlc2');
}

// Document HLC integration
final doc = Doc(nodeId: 'server-1');
final syncState = doc.getSyncState();
print(syncState['hlc']); // Current HLC state
print(syncState['hlc_vector']); // HLC vector for all known nodes

// Generate GUID v4 node IDs
final nodeId = generateGuidV4();
final doc = Doc(nodeId: nodeId);
```

### Delta Synchronization with HLC

Efficient incremental updates using HLC-based causality.

```dart
// Server setup
final server = Doc(nodeId: 'server');
final serverMap = YMap();
server.share('document', serverMap);

// Client setup  
final client = Doc(nodeId: generateGuidV4());

// Initial sync - client gets full state
final initialUpdate = server.getUpdateSince({});
client.applyUpdate(initialUpdate);

// Client makes changes
final clientMap = client.get<YMap>('document')!;
clientMap.set('clientData', 'hello from client');

// Delta sync - only sends changes since server's known state
final serverState = server.getVectorClock(); // Legacy compatibility
final deltaUpdate = client.getUpdateSince(serverState);
print(deltaUpdate['type']); // 'delta_update'

// Server applies delta
server.applyUpdate(deltaUpdate);

// HLC vectors track causality across all nodes
final hlcVector = server.getSyncState()['hlc_vector'];
print(hlcVector.keys); // ['server', 'client-guid-here']
```

### YMap

Collaborative key-value map with last-write-wins conflict resolution.

```dart
final map = YMap();

// Basic operations
map.set('key', 'value');
final value = map.get('key');
final exists = map.has('key');
map.delete('key');

// Bulk operations
map.clear();

// Inspection
print(map.size);
print(map.keys);
print(map.values);
print(map.entries);

// Conversion
final jsonMap = map.toJSON();
```

### YArray

Collaborative array that preserves insertion order.

```dart
final array = YArray<String>();

// Creating from existing data
final array = YArray.from(['a', 'b', 'c']);

// Basic operations  
array.push('item');
array.insert(0, 'first');
array.delete(1, 2); // Delete 2 items starting at index 1

// Access
final item = array.get(0);
final item = array[0]; // Alternative syntax
array[0] = 'new value'; // Replace item

// Bulk operations
array.pushAll(['x', 'y', 'z']);
array.insertAll(1, ['a', 'b']);

// Iteration
array.forEach((item, index) {
  print('$index: $item');
});

final mapped = array.map((item, index) => item.toUpperCase());

// Conversion
final list = array.toList();
final json = array.toJSON();
```

### YText

Collaborative text with character-level editing.

```dart
final text = YText('Initial text');

// Text operations
text.insert(7, ' inserted');
text.delete(0, 5); // Delete first 5 characters

// Access
print(text.toString());
print(text.length);
final char = text.charAt(5);
final substr = text.substring(0, 5);

// Conversion
final jsonText = text.toJSON(); // Returns string
```

### GCounter

Grow-only counter for collaborative increment operations. Perfect for tracking progress, usage counts, or any value that only increases.

```dart
final counter = GCounter();

// Increment operations (only positive values allowed)
counter.increment(clientID, 5); // Add 5 to this client's counter
counter.increment(clientID, 3); // Add 3 more

print(counter.value); // Total value across all clients

// Merge with another counter (CRDT operation)
final otherCounter = GCounter();
otherCounter.increment(otherClientID, 7);
counter.merge(otherCounter); // Combines both counters

// Serialization
final json = counter.toJSON();
final restored = GCounter.fromJSON(json);
```

### PNCounter

Positive-negative counter supporting both increment and decrement operations. Ideal for tracking balances, material usage, or any value that can go up or down.

```dart
final counter = PNCounter();

// Increment and decrement operations
counter.increment(clientID, 10); // Add 10
counter.decrement(clientID, 3);  // Subtract 3
counter.add(clientID, -2);       // Subtract 2 (negative add)
counter.add(clientID, 5);        // Add 5 (positive add)

print(counter.value); // Net value: 10 - 3 - 2 + 5 = 10

// Merge with other counters
final otherCounter = PNCounter();
otherCounter.increment(otherClientID, 15);
counter.merge(otherCounter); // Combines state from both

// Serialization
final json = counter.toJSON();
final restored = PNCounter.fromJSON(json);
```

### Document Serialization and Synchronization

Export and import document state for server synchronization.

```dart
final doc = Doc(clientID: 12345);
final map = YMap();
doc.share('data', map);

// Make some changes
map.set('progress', GCounter()..increment(12345, 25));
map.set('name', 'Project Alpha');

// Serialize entire document
final json = doc.toJSON();
final binaryData = BinaryEncoder.encodeDocument(doc);

// Restore from serialized state
final restoredDoc = Doc.fromJSON(json);
final restoredFromBinary = BinaryEncoder.decodeDocument(binaryData);

// Generate updates for synchronization
final update = doc.getUpdateSince(remoteState);

// Apply updates from other clients
doc.applyUpdate(receivedUpdate);

// Compare encoding sizes
final sizes = BinaryEncoder.compareSizes(doc);
print('Binary: ${sizes['binary']} bytes');
print('JSON: ${sizes['json']} bytes');
```

## Architecture

This implementation is based on the Y.js CRDT algorithm (YATA - Yet Another Transformation Approach) with the following key concepts:

- **Unique IDs**: Each operation has a unique ID (clientID, clock)
- **Causal ordering**: Operations are ordered based on their causal relationships
- **Conflict resolution**: Deterministic resolution using ID comparison
- **Tombstones**: Deleted items are marked but kept for conflict resolution

## Current Limitations

This is a core implementation focused on offline-first usage. The following Y.js features are not yet implemented:

- Advanced network synchronization protocols (basic sync implemented)
- Rich text formatting in YText
- Undo/Redo functionality
- Subdocuments
- Observability/events
- Advanced conflict resolution (beyond basic CRDT merging)

## Contributing

Contributions are welcome! This implementation can be extended with:

- Advanced network synchronization protocols
- Rich text formatting
- Event system and observability
- Performance optimizations
- Additional CRDT types (e.g., OR-Sets, LWW-Sets)
- Undo/Redo functionality
- More efficient binary encoding

## License

MIT License - see LICENSE file for details.