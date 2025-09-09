import 'package:test/test.dart';
import '../lib/transpiler.dart';
import 'dart:io';

void main() {
  group('JavaScript to Dart Transpiler Tests', () {
    late JavaScriptToDartTranspiler transpiler;
    
    setUp(() {
      transpiler = JavaScriptToDartTranspiler();
    });
    
    test('transpiles simple JavaScript class to Dart', () {
      const jsCode = '''
export class SimpleClass {
  constructor(name) {
    this.name = name;
  }
  
  getName() {
    return this.name;
  }
}
''';
      
      final dartCode = transpiler.transpileCode(jsCode);
      
      expect(dartCode, contains('class SimpleClass'));
      expect(dartCode, contains('SimpleClass('));
      expect(dartCode, contains('String getName()'));
    });
    
    test('transpiles JavaScript Map operations to Dart', () {
      const jsCode = '''
const map = new Map();
map.set('key', 'value');
const value = map.get('key');
''';
      
      final dartCode = transpiler.transpileCode(jsCode);
      
      expect(dartCode, contains('<String, dynamic>{}'));
      expect(dartCode, contains("['key'] = 'value'"));
      expect(dartCode, contains("['key']"));
    });
    
    test('creates placeholders for external dependencies', () {
      const jsCode = '''
import { createHash } from 'crypto';
import { EventEmitter } from 'events';

const hash = createHash('sha256');
''';
      
      final dartCode = transpiler.transpileCode(jsCode);
      
      expect(dartCode, contains('PLACEHOLDER'));
      expect(dartCode, contains('crypto'));
      expect(dartCode, contains('events'));
    });
    
    test('transpiles async functions correctly', () {
      const jsCode = '''
async function fetchData() {
  const response = await fetch('/api/data');
  return response.json();
}
''';
      
      final dartCode = transpiler.transpileCode(jsCode);
      
      expect(dartCode, contains('Future<'));
      expect(dartCode, contains('async'));
      expect(dartCode, contains('await'));
    });
    
    test('converts JavaScript array methods to Dart', () {
      const jsCode = '''
const arr = [];
arr.push(item);
const last = arr.pop();
''';
      
      final dartCode = transpiler.transpileCode(jsCode);
      
      expect(dartCode, contains('<dynamic>[]'));
      expect(dartCode, contains('.add('));
      expect(dartCode, contains('.removeLast()'));
    });
    
    test('handles YText-like class transpilation', () async {
      // Test with the sample YText file
      final sampleFile = File('test/sample_ytext.js');
      if (await sampleFile.exists()) {
        await transpiler.transpileFile('test/sample_ytext.js', '/tmp/ytext_output.dart');
        
        final outputFile = File('/tmp/ytext_output.dart');
        expect(await outputFile.exists(), isTrue);
        
        final dartCode = await outputFile.readAsString();
        expect(dartCode, contains('class YText'));
        expect(dartCode, contains('void insert('));
        expect(dartCode, contains('String toString()'));
        expect(dartCode, contains('PLACEHOLDER'));
      }
    });
  });
}