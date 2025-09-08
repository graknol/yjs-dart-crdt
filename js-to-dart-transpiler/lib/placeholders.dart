/// Generates placeholder functions for external dependencies that need manual implementation
class PlaceholderGenerator {
  final Map<String, List<String>> _externalDependencies = {};
  final Set<String> _generatedPlaceholders = {};
  
  /// Add an external dependency that needs a placeholder
  void addExternalDependency(String packageName, List<String> imports) {
    _externalDependencies[packageName] = imports;
  }
  
  /// Generate placeholder file content
  String generatePlaceholderFile() {
    final buffer = StringBuffer();
    
    buffer.writeln('// Generated placeholder functions for external dependencies');
    buffer.writeln('// These functions need manual Dart implementation');
    buffer.writeln();
    buffer.writeln("import 'dart:convert';");
    buffer.writeln("import 'dart:async';");
    buffer.writeln("import 'dart:math' as math;");
    buffer.writeln();
    
    for (final entry in _externalDependencies.entries) {
      final packageName = entry.key;
      final imports = entry.value;
      
      buffer.writeln('// Placeholders for $packageName');
      for (final importName in imports) {
        final placeholder = _generatePlaceholderFunction(packageName, importName);
        if (placeholder != null && !_generatedPlaceholders.contains(importName)) {
          buffer.writeln(placeholder);
          buffer.writeln();
          _generatedPlaceholders.add(importName);
        }
      }
    }
    
    return buffer.toString();
  }
  
  String? _generatePlaceholderFunction(String packageName, String functionName) {
    // Generate common Node.js built-in placeholders
    if (packageName == 'crypto') {
      return _generateCryptoPlaceholder(functionName);
    } else if (packageName == 'fs') {
      return _generateFsPlaceholder(functionName);
    } else if (packageName == 'path') {
      return _generatePathPlaceholder(functionName);
    } else if (packageName == 'util') {
      return _generateUtilPlaceholder(functionName);
    } else if (packageName == 'events') {
      return _generateEventsPlaceholder(functionName);
    } else if (packageName == 'buffer') {
      return _generateBufferPlaceholder(functionName);
    }
    
    // Generic placeholder for unknown packages
    return _generateGenericPlaceholder(packageName, functionName);
  }
  
  String _generateCryptoPlaceholder(String functionName) {
    switch (functionName) {
      case 'createHash':
        return '''/// PLACEHOLDER: Implement crypto hash function
/// Consider using package:crypto from pub.dev
String createHash(String algorithm) {
  // TODO: Implement hash function
  // Example: return sha256.convert(utf8.encode(data)).toString();
  throw UnimplementedError('createHash needs manual implementation');
}''';
      
      case 'randomBytes':
        return '''/// PLACEHOLDER: Generate random bytes
/// Consider using dart:math Random or package:crypto
List<int> randomBytes(int size) {
  // TODO: Implement random bytes generation
  throw UnimplementedError('randomBytes needs manual implementation');
}''';
      
      default:
        return _generateGenericPlaceholder('crypto', functionName);
    }
  }
  
  String _generateFsPlaceholder(String functionName) {
    switch (functionName) {
      case 'readFileSync':
        return '''/// PLACEHOLDER: Read file synchronously
/// Use dart:io File.readAsStringSync()
String readFileSync(String path, [String encoding = 'utf8']) {
  // TODO: Implement file reading
  // Example: return File(path).readAsStringSync();
  throw UnimplementedError('readFileSync needs manual implementation');
}''';
      
      case 'writeFileSync':
        return '''/// PLACEHOLDER: Write file synchronously
/// Use dart:io File.writeAsStringSync()
void writeFileSync(String path, String data, [String encoding = 'utf8']) {
  // TODO: Implement file writing
  // Example: File(path).writeAsStringSync(data);
  throw UnimplementedError('writeFileSync needs manual implementation');
}''';
      
      case 'existsSync':
        return '''/// PLACEHOLDER: Check if file exists
/// Use dart:io File.existsSync()
bool existsSync(String path) {
  // TODO: Implement file existence check
  // Example: return File(path).existsSync();
  throw UnimplementedError('existsSync needs manual implementation');
}''';
      
      default:
        return _generateGenericPlaceholder('fs', functionName);
    }
  }
  
  String _generatePathPlaceholder(String functionName) {
    switch (functionName) {
      case 'join':
        return '''/// PLACEHOLDER: Join path segments
/// Use package:path from pub.dev
String join(String part1, [String? part2, String? part3, String? part4]) {
  // TODO: Implement path joining
  // Example: return p.join(part1, part2, part3, part4);
  throw UnimplementedError('path.join needs manual implementation');
}''';
      
      case 'resolve':
        return '''/// PLACEHOLDER: Resolve absolute path
/// Use package:path from pub.dev
String resolve(String path) {
  // TODO: Implement path resolution
  // Example: return p.absolute(path);
  throw UnimplementedError('path.resolve needs manual implementation');
}''';
      
      default:
        return _generateGenericPlaceholder('path', functionName);
    }
  }
  
  String _generateUtilPlaceholder(String functionName) {
    switch (functionName) {
      case 'inherits':
        return '''/// PLACEHOLDER: Class inheritance helper
/// Dart has native class inheritance with 'extends'
void inherits(Type constructor, Type superConstructor) {
  // TODO: This is typically not needed in Dart
  // Use 'class Child extends Parent' instead
  throw UnimplementedError('util.inherits not applicable in Dart');
}''';
      
      case 'isDeepStrictEqual':
        return '''/// PLACEHOLDER: Deep equality comparison
/// Consider using package:collection DeepCollectionEquality
bool isDeepStrictEqual(dynamic a, dynamic b) {
  // TODO: Implement deep equality check
  // Example: return DeepCollectionEquality().equals(a, b);
  throw UnimplementedError('isDeepStrictEqual needs manual implementation');
}''';
      
      default:
        return _generateGenericPlaceholder('util', functionName);
    }
  }
  
  String _generateEventsPlaceholder(String functionName) {
    switch (functionName) {
      case 'EventEmitter':
        return '''/// PLACEHOLDER: Event emitter implementation
/// Consider creating a custom event system or using streams
class EventEmitter {
  final Map<String, List<Function>> _listeners = {};
  
  void on(String event, Function listener) {
    // TODO: Implement event listener registration
    throw UnimplementedError('EventEmitter needs manual implementation');
  }
  
  void emit(String event, [dynamic data]) {
    // TODO: Implement event emission
    throw UnimplementedError('EventEmitter needs manual implementation');
  }
}''';
      
      default:
        return _generateGenericPlaceholder('events', functionName);
    }
  }
  
  String _generateBufferPlaceholder(String functionName) {
    switch (functionName) {
      case 'Buffer':
        return '''/// PLACEHOLDER: Buffer implementation
/// Use dart:typed_data Uint8List
class Buffer {
  static Uint8List from(List<int> data) {
    // TODO: Implement buffer creation
    // Example: return Uint8List.fromList(data);
    throw UnimplementedError('Buffer.from needs manual implementation');
  }
  
  static Uint8List alloc(int size) {
    // TODO: Implement buffer allocation
    // Example: return Uint8List(size);
    throw UnimplementedError('Buffer.alloc needs manual implementation');
  }
}''';
      
      default:
        return _generateGenericPlaceholder('buffer', functionName);
    }
  }
  
  String _generateGenericPlaceholder(String packageName, String functionName) {
    return '''/// PLACEHOLDER: Function from package '$packageName'
/// Manual implementation required
dynamic ${functionName}_PLACEHOLDER([dynamic args]) {
  throw UnimplementedError('$functionName from $packageName needs manual implementation');
}''';
  }
  
  /// Get a summary of all placeholder dependencies
  Map<String, List<String>> getPlaceholderSummary() {
    return Map.unmodifiable(_externalDependencies);
  }
  
  /// Clear all stored dependencies
  void clear() {
    _externalDependencies.clear();
    _generatedPlaceholders.clear();
  }
}