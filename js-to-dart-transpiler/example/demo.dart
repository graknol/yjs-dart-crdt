import 'dart:io';
import '../lib/transpiler.dart';

void main() async {
  print('JavaScript to Dart Transpiler Demo');
  print('=====================================');
  
  final transpiler = JavaScriptToDartTranspiler();
  
  // Example 1: Simple class transpilation
  print('\n1. Simple Class Transpilation:');
  print('-------------------------------');
  
  const simpleJs = '''
export class Counter {
  constructor(initialValue = 0) {
    this.value = initialValue;
  }
  
  increment() {
    this.value++;
    return this.value;
  }
  
  getValue() {
    return this.value;
  }
}
''';
  
  final simpleDart = transpiler.transpileCode(simpleJs);
  print('JavaScript Input:');
  print(simpleJs);
  print('\nDart Output:');
  print(simpleDart);
  
  // Example 2: Complex CRDT-like functionality
  print('\n2. CRDT-like Class Transpilation:');
  print('----------------------------------');
  
  const crdtJs = '''
import { createHash } from 'crypto';

export class YMap {
  constructor() {
    this._map = new Map();
    this._clock = 0;
  }
  
  set(key, value) {
    const id = this._generateId();
    this._map.set(key, {
      value: value,
      id: id,
      timestamp: Date.now()
    });
    
    console.log(\`Set \${key} = \${value}\`);
  }
  
  get(key) {
    const entry = this._map.get(key);
    return entry ? entry.value : undefined;
  }
  
  _generateId() {
    return createHash('sha256').update(String(this._clock++)).digest('hex');
  }
}
''';
  
  final crdtDart = transpiler.transpileCode(crdtJs);
  print('JavaScript Input:');
  print(crdtJs);
  print('\nDart Output:');
  print(crdtDart);
  
  // Example 3: Transpile sample YText file if it exists
  print('\n3. Sample YText File Transpilation:');
  print('-----------------------------------');
  
  final sampleFile = File('test/sample_ytext.js');
  if (await sampleFile.exists()) {
    print('Transpiling sample_ytext.js...');
    await transpiler.transpileFile('test/sample_ytext.js', '/tmp/sample_ytext.dart');
    
    final outputFile = File('/tmp/sample_ytext.dart');
    if (await outputFile.exists()) {
      final content = await outputFile.readAsString();
      print('Successfully transpiled! Output saved to /tmp/sample_ytext.dart');
      print('\nFirst 1000 characters of output:');
      print(content.length > 1000 ? content.substring(0, 1000) + '...' : content);
    }
  } else {
    print('Sample YText file not found.');
  }
  
  print('\n=====================================');
  print('Demo completed successfully!');
}