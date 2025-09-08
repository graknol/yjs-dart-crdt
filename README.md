# Y.js CRDT Multi-Language Implementation

A comprehensive CRDT (Conflict-free Replicated Data Type) library inspired by Y.js, implemented in multiple languages for seamless client-server synchronization in offline-first applications.

## 🎯 Overview

This repository contains compatible implementations of Y.js core CRDT data structures in:
- **[Dart](dart/)** - Pure Dart implementation for Flutter clients and mobile apps
- **[C#](csharp/)** - .NET Standard implementation optimized for server environments
- **[JavaScript-to-Dart Transpiler](js-to-dart-transpiler/)** - **NEW**: Tool to directly convert Y.js source code to Dart

Both implementations share the same protocol, enabling seamless synchronization between Dart clients and C# servers with features like Hybrid Logical Clocks (HLC) for advanced causality tracking.

## 🚀 Key Features

- **Cross-Platform Compatibility**: Dart client ↔ C# server synchronization
- **Hybrid Logical Clocks**: Superior causality tracking with millisecond precision
- **Delta Synchronization**: Efficient incremental updates instead of full state transfer
- **Thread-Safe Operations**: C# implementation optimized for concurrent server scenarios
- **Pure Implementations**: No external dependencies beyond standard libraries
- **CRDT Types**: YMap, YArray, YText, GCounter, PNCounter
- **Protocol Compatibility**: JSON and binary serialization formats match exactly

## 📁 Repository Structure

```
yjs-dart-crdt/
├── dart/                           # Dart/Flutter implementation
│   ├── lib/                        # Dart source code
│   ├── test/                       # Dart unit tests
│   ├── example/                    # Dart examples
│   └── README.md                   # Dart-specific documentation
├── csharp/                         # C# .NET implementation
│   ├── YjsCrdtSharp/              # Core C# library
│   ├── YjsCrdtSharp.Examples/     # C# examples
│   ├── YjsCrdtSharp.Tests/        # C# unit tests
│   └── README.md                   # C#-specific documentation
├── js-to-dart-transpiler/         # **NEW**: JavaScript to Dart transpiler
│   ├── lib/                       # Transpiler source code
│   ├── bin/                       # CLI transpiler tool
│   ├── example/                   # Transpiler examples
│   └── README.md                  # Transpiler documentation
├── CSHARP_TECHNICAL_SPEC.md       # Comprehensive C# implementation guide
└── README.md                       # This file
```

## 🛠️ Quick Start

### Dart Client Setup

```bash
cd dart/
dart pub get
dart run example/main.dart
```

```dart
import 'package:yjs_dart_crdt/yjs_dart_crdt.dart';

// Create document with HLC-based node ID
final doc = Doc();

// Collaborative map
final map = YMap();
doc.share('myMap', map);
map.set('name', 'Alice');

// Collaborative counters
final progress = GCounter();
progress.increment(doc.clientID, 25);
map.set('progress', progress);

print('Progress: ${progress.value}%');
```

### C# Server Setup

```bash
cd csharp/
dotnet build
dotnet run --project YjsCrdtSharp.Examples
```

```csharp
using YjsCrdtSharp.Types;
using YjsCrdtSharp.Counters;

// Create collaborative map
var map = new YMap();
map.Set("name", "Alice");

// Collaborative counter
var progress = new GCounter();
progress.Increment(clientId: 1, amount: 25);
map.Set("progress", progress);

Console.WriteLine($"Progress: {progress.Value}%");
```

### JavaScript-to-Dart Transpiler (**NEW Approach**)

Instead of reimplementing Y.js algorithms from scratch, directly transpile the mature Y.js source code to Dart:

```bash
cd js-to-dart-transpiler/
dart pub get
dart run bin/transpiler.dart -i yjs_source.js -o output.dart
```

**Benefits:**
- ✅ **Leverage Y.js maturity**: Get battle-tested YATA algorithm, conflict resolution, and optimizations
- ✅ **Faster development**: Convert months of implementation work to weeks  
- ✅ **Automatic updates**: Transpile newer Y.js versions to stay current
- ✅ **Algorithm preservation**: Core CRDT logic stays identical to Y.js

**Example transpilation:**
```javascript
// Y.js source
export class YText {
  constructor() {
    this._content = new Map();
  }
  insert(index, text) {
    // YATA algorithm implementation...
  }
}
```

```dart
// Generated Dart
class YText {
  YText() {
    this._content = <String, dynamic>{};
  }
  void insert(int index, String text) {
    // YATA algorithm implementation... (preserved exactly)
  }
}
```

Only platform-specific functions (crypto, file I/O, etc.) need manual implementation - the complex CRDT algorithms are preserved automatically!

## 🌐 Client-Server Synchronization

### Dart Client → C# Server

```dart
// Dart client
final doc = Doc(nodeId: 'mobile-client-123');
final map = YMap();
doc.share('document', map);
map.set('clientData', 'Hello from mobile!');

// Generate update for server
final update = doc.getUpdateSince({});
// Send update to C# server via HTTP/WebSocket
```

```csharp
// C# server receives update
var serverMap = new YMap();
// Apply client update (would be implemented with full Document class)
serverMap.Set("clientData", "Hello from mobile!");

// Merge with server data
var serverProgress = new GCounter();
serverProgress.Increment(0, 50); // Server contribution
// Broadcast merged state to all clients
```

### Protocol Compatibility

Both implementations use identical:
- **JSON Serialization Format**: Exact same structure for network transfer
- **HLC Vector Synchronization**: Causality tracking across all nodes
- **Operation Ordering**: Deterministic conflict resolution
- **Delta Updates**: Minimal data transfer for synchronization

## 📊 CRDT Types

| Type | Description | Dart | C# |
|------|-------------|------|-----|
| **YMap** | Last-write-wins dictionary | ✅ | ✅ |
| **YArray** | Insertion-order preserving list | ✅ | 🚧 |
| **YText** | Character-level collaborative text | ✅ | 🚧 |
| **GCounter** | Grow-only counter | ✅ | ✅ |
| **PNCounter** | Increment/decrement counter | ✅ | ✅ |
| **HLC** | Hybrid Logical Clock | ✅ | ✅ |

Legend: ✅ Implemented | 🚧 Planned | ❌ Not planned

## 🔧 Development

### Testing Dart Implementation

```bash
cd dart/
dart test                    # Run all tests
dart analyze                 # Code analysis
dart format .                # Format code
```

### Testing C# Implementation

```bash
cd csharp/
dotnet test                  # Run unit tests
dotnet build                 # Build library
dotnet pack                  # Create NuGet package
```

### Cross-Platform Testing

The repository includes integration tests to verify protocol compatibility between Dart and C# implementations:

```bash
# Run Dart integration tests
cd dart/ && dart test test/integration_test.dart

# Run C# integration tests  
cd csharp/ && dotnet test --filter "Category=Integration"
```

## 📈 Performance Characteristics

### Dart Implementation
- **Target**: Mobile clients, Flutter apps
- **Memory**: Optimized for mobile constraints
- **Threading**: Single-threaded with async/await patterns
- **Persistence**: Local storage integration

### C# Implementation  
- **Target**: Server environments, ASP.NET Core
- **Memory**: Optimized for server workloads
- **Threading**: Thread-safe concurrent operations
- **Persistence**: Database integration ready

## 🔍 Use Cases

### Mobile-First Applications
- **Dart Client**: Offline-capable Flutter apps
- **C# Server**: Centralized state management and synchronization
- **Sync**: When online, clients sync with server using delta updates

### Collaborative Editing
- **Real-time**: Multiple clients editing shared documents
- **Conflict-free**: CRDT properties ensure consistent state
- **Offline**: Continue editing offline, sync when reconnected

### Progress Tracking Systems
- **Counters**: Team progress, resource usage, metrics
- **Multi-client**: Each client contributes to shared counters
- **Server aggregation**: C# server aggregates and persists totals

## 🤝 Contributing

Contributions are welcome for both implementations! Please:

1. **Maintain Protocol Compatibility**: Ensure changes work across both Dart and C#
2. **Add Tests**: Include unit tests and integration tests
3. **Update Documentation**: Keep both language-specific READMEs updated
4. **Follow Conventions**: Use established patterns for each language

### Protocol Compatibility Requirements

When adding features:
- JSON serialization must match between implementations
- HLC vector updates must be identical
- Operation ordering must produce same results
- Error handling should be consistent

## 📚 Documentation

- **[Dart README](dart/README.md)**: Dart-specific usage and API
- **[C# README](csharp/README.md)**: C# server implementation guide
- **[C# Technical Spec](CSHARP_TECHNICAL_SPEC.md)**: Comprehensive implementation details
- **Examples**: Working code in both `dart/example/` and `csharp/YjsCrdtSharp.Examples/`

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

- Inspired by [Y.js](https://github.com/yjs/yjs) CRDT implementation
- Based on YATA (Yet Another Transformation Approach) algorithm
- Hybrid Logical Clock implementation for distributed systems
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