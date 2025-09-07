# Y.js Dart CRDT

Y.js Dart CRDT is a pure Dart implementation of Y.js core CRDT (Conflict-free Replicated Data Type) data structures for offline-first Flutter applications. This is a library package with core CRDT types including YMap, YArray, YText, GCounter, and PNCounter.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Setup and Dependencies
- Install Dart SDK 3.5.4:
  - `wget -qO- https://storage.googleapis.com/dart-archive/channels/stable/release/3.5.4/linux_packages/dart_3.5.4-1_amd64.deb -O /tmp/dart.deb && sudo dpkg -i /tmp/dart.deb`
  - `export PATH=$PATH:/usr/lib/dart/bin` -- add to your session PATH
  - Verify installation: `dart --version`
- Install project dependencies: `dart pub get` -- takes ~4 seconds. Set timeout to 30 seconds.

### Build and Test
- **Run tests**: `dart test` -- takes ~1.2 seconds. Set timeout to 30 seconds. NEVER CANCEL.
  - Expected result: 29 tests pass, 2 tests fail (known counter serialization issues that don't affect core functionality)
- **Code analysis**: `dart analyze` -- takes ~2 seconds. Set timeout to 30 seconds.
  - Expect some warnings for unused variables/imports - these are non-critical
- **Code formatting**: `dart format --set-exit-if-changed .` -- takes ~0.5 seconds. Set timeout to 10 seconds.
  - Use `dart format .` to auto-fix formatting without failing on changes
- **View dependencies**: `dart pub deps` -- takes ~0.3 seconds

### Run Examples
- **Basic functionality**: `dart run example/main.dart` -- takes ~0.4 seconds. Shows YMap, YArray, YText usage.
- **Integration test**: `dart run example/integration_test.dart` -- takes ~0.4 seconds. Multi-client collaboration demo.
- **Counter example**: `dart run example/counter_example.dart` -- takes ~0.4 seconds. GCounter and PNCounter demo.
- **Sync example**: `dart run example/sync_example.dart` -- CURRENTLY FAILS with serialization error (known issue)

## Validation
- Always run `dart test` after making changes to verify functionality
- Always run `dart analyze` before committing to check for issues
- Always run `dart format .` before committing to maintain code style
- Run at least one example after changes: `dart run example/main.dart` to verify basic functionality
- ALWAYS ensure the main example runs without errors as validation that core CRDT operations work

## Common Tasks

### Repository Structure
```
lib/
├── src/
│   ├── content.dart      # AbstractContent and content types
│   ├── counters.dart     # GCounter and PNCounter implementations
│   ├── crdt_types.dart   # Core Doc, YMap, YArray, YText types
│   ├── encoding.dart     # Binary encoding utilities
│   └── id.dart          # ID generation and management
└── yjs_dart_crdt.dart   # Main library export file

example/
├── main.dart            # Basic usage examples
├── integration_test.dart # Multi-client collaboration demo
├── counter_example.dart # Counter CRDT examples
└── sync_example.dart    # Serialization demo (currently broken)

test/
└── yjs_dart_crdt_test.dart # All unit tests
```

### Key Classes and Usage
- **Doc**: Document container managing CRDT types and operations
  - Create: `final doc = Doc();` or `final doc = Doc(clientID: 12345);`
  - Share types: `doc.share('key', yMapInstance);`
  - Get shared: `final map = doc.get<YMap>('key');`
- **YMap**: Collaborative key-value map with last-write-wins semantics
- **YArray**: Collaborative array with insertion-order preservation
- **YText**: Collaborative text editing with character-level operations
- **GCounter**: Grow-only counter for collaborative increment operations
- **PNCounter**: Positive-negative counter supporting increment/decrement

### Common Development Patterns
- All CRDT operations are performed within a document context
- Use `doc.transact()` for batched operations
- Counters must be created and added to shared types via YMap
- Serialization is handled via `toJSON()` and `fromJSON()` methods
- Always check the main example when making changes to ensure basic workflows still function

### Known Issues and Limitations
- Two test failures related to counter serialization (non-critical for core functionality)
- Sync example fails with serialization error for counter objects
- No external dependencies - pure Dart implementation
- Focused on offline-first usage, basic network sync implemented
- Missing advanced Y.js features: rich text formatting, undo/redo, subdocuments

### Troubleshooting
- If tests fail to compile, check that Doc class has a `setClock()` method
- If examples fail, ensure all required CRDT types are properly imported
- Binary encoding issues typically require checking the `encoding.dart` file
- Serialization errors often indicate missing `toJSON()` implementations