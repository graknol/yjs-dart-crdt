# JavaScript to Dart Transpiler

A transpiler designed to convert Y.js JavaScript code to Dart, enabling direct usage of Y.js's mature CRDT implementations in Dart/Flutter applications.

## Overview

Instead of reimplementing Y.js's complex algorithms (YATA, conflict resolution, etc.), this transpiler converts the JavaScript source directly to Dart syntax while preserving the core logic.

## Features

- **Syntax Conversion**: Handles JavaScript to Dart syntax differences
- **Placeholder Generation**: Creates placeholder functions for external dependencies
- **Type Inference**: Adds basic Dart type annotations where possible
- **Import/Export Translation**: Converts JS modules to Dart imports
- **Built-in Function Mapping**: Maps JavaScript built-ins to Dart equivalents

## Architecture

- `transpiler.dart` - Main transpiler logic
- `ast_parser.dart` - JavaScript AST parsing utilities  
- `dart_generator.dart` - Dart code generation
- `conversion_rules.dart` - Language-specific conversion rules
- `placeholders.dart` - External dependency placeholder generation

## Usage

```bash
dart run bin/transpiler.dart <input-js-file> <output-dart-file>
```

## Conversion Examples

### JavaScript to Dart Syntax

**JavaScript:**
```javascript
export class YText {
  constructor() {
    this._content = new Map();
  }
  
  insert(index, text) {
    // Implementation
  }
}
```

**Dart:**
```dart
class YText {
  YText() {
    this._content = <String, dynamic>{};
  }
  
  void insert(int index, String text) {
    // Implementation
  }
}
```

### External Dependencies

**JavaScript:**
```javascript
import { createHash } from 'crypto';
const hash = createHash('sha256');
```

**Dart:**
```dart
// PLACEHOLDER: import crypto package
String createHash(String algorithm) {
  // PLACEHOLDER: Implement crypto hash function
  throw UnimplementedError('createHash needs manual implementation');
}
```

## Manual Implementation Required

The transpiler creates placeholders for:
- NPM package functions
- Node.js built-ins
- Browser-specific APIs
- Platform-specific optimizations

These placeholders need manual Dart implementation after transpilation.