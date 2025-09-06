# Y.js Dart CRDT

A pure Dart implementation of Y.js core CRDT (Conflict-free Replicated Data Type) data structures for offline-first Flutter applications.

## Features

- **YMap**: Collaborative map/dictionary with last-write-wins semantics
- **YArray**: Collaborative array with insertion-order preservation  
- **YText**: Collaborative text editing with character-level operations
- **Pure Dart**: No external dependencies, Flutter-compatible
- **Offline-first**: Local operations with built-in conflict resolution
- **Type-safe**: Full Dart generics support

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
}
```

## API Reference

### Doc

The document container that manages CRDT types and operations.

```dart
final doc = Doc(); // Creates with random client ID
final doc = Doc(clientID: 12345); // Creates with specific client ID

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

## Architecture

This implementation is based on the Y.js CRDT algorithm (YATA - Yet Another Transformation Approach) with the following key concepts:

- **Unique IDs**: Each operation has a unique ID (clientID, clock)
- **Causal ordering**: Operations are ordered based on their causal relationships
- **Conflict resolution**: Deterministic resolution using ID comparison
- **Tombstones**: Deleted items are marked but kept for conflict resolution

## Current Limitations

This is a core implementation focused on offline-first usage. The following Y.js features are not yet implemented:

- Network synchronization protocols
- Rich text formatting in YText
- Undo/Redo functionality
- Subdocuments
- Observability/events
- Persistence/serialization

## Contributing

Contributions are welcome! This implementation can be extended with:

- Network synchronization
- Rich text formatting
- Event system
- Performance optimizations
- Additional CRDT types

## License

MIT License - see LICENSE file for details.