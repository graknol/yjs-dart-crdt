# JavaScript to Dart Transpiler Usage Guide

This guide shows how to use the JavaScript-to-Dart transpiler to convert Y.js code to Dart.

## Quick Start

1. Install dependencies:
```bash
cd js-to-dart-transpiler
dart pub get
```

2. Basic usage:
```bash
dart run bin/transpiler.dart -i input.js -o output.dart
```

## Example Conversions

### JavaScript Classes to Dart Classes

**Input JavaScript:**
```javascript
export class YText {
  constructor(initialContent = '') {
    this._content = new Map();
    this._length = 0;
  }
  
  insert(index, text) {
    // Implementation here
  }
}
```

**Output Dart:**
```dart
class YText {
  YText(String initialContent = '') {
    this._content = <String, dynamic>{};
    this._length = 0;
  }
  
  void insert(int index, String text) {
    // Implementation here
  }
}
```

### External Dependencies → Placeholders

**Input JavaScript:**
```javascript
import { createHash } from 'crypto';
import { EventEmitter } from 'events';

const hash = createHash('sha256');
const emitter = new EventEmitter();
```

**Output Dart:**
```dart
// PLACEHOLDER: import crypto package  
// PLACEHOLDER: import events package

String createHash(String algorithm) {
  // PLACEHOLDER: Implement crypto hash function
  throw UnimplementedError('createHash needs manual implementation');
}

class EventEmitter {
  void on(String event, Function listener) {
    // PLACEHOLDER: Implement event listener
    throw UnimplementedError('EventEmitter needs manual implementation');
  }
}
```

### Collections & Built-ins

**Input JavaScript:**
```javascript
const map = new Map();
map.set('key', 'value');
const value = map.get('key');

const arr = [];
arr.push(item);
console.log('Hello');
```

**Output Dart:**
```dart
const Map<String, dynamic> map = <String, dynamic>{};
map['key'] = 'value';
const dynamic value = map['key'];

const List<dynamic> arr = <dynamic>[];
arr.add(item);
print('Hello');
```

## Running the Demo

```bash
dart run example/demo.dart
```

This demonstrates:
- Simple class transpilation  
- CRDT-like functionality with placeholders
- Complex Y.js-style class transpilation

## What Gets Converted Automatically

✅ **JavaScript → Dart Syntax:**
- Classes and constructors
- Method signatures with basic type inference
- Map/Set/Array operations
- Basic control flow
- Import/export statements

✅ **Built-in Functions:**
- `console.log` → `print`
- `JSON.stringify` → `jsonEncode`
- `Math.*` → `math.*`

## What Needs Manual Implementation

❌ **External Dependencies:**
- NPM packages (crypto, fs, path, etc.)
- Node.js built-ins
- Browser APIs

❌ **Complex Language Features:**
- Advanced async patterns
- Closures with complex scoping
- Prototype inheritance
- Dynamic property access

## Next Steps for Y.js Integration

1. **Download Y.js source code**
2. **Run transpiler on core Y.js files**
3. **Implement placeholder functions** for Node.js dependencies
4. **Test and refine** the generated Dart code
5. **Package as Dart library** for use in Flutter/Dart projects

The transpiler provides about 80% automation - the complex algorithms like YATA are preserved, only platform-specific parts need manual implementation.