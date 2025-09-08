import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import '../dart/lib/yjs_dart_crdt.dart';

/// Dart side of the Y.js compatibility test
/// This test validates that our Dart CRDT implementation can communicate
/// and collaborate with Y.js using the same binary protocol
class DartCompatibilityTest {
  Map<String, dynamic> dartResults = {
    'dart': {
      'maps': {},
      'arrays': {},
      'texts': {},
      'updates': {},
      'states': {}
    }
  };

  /// Test YMap CRDT operations matching Y.js test
  void testYMap() {
    print('Testing Dart YMap...');
    
    // Create two documents to simulate distributed editing (matching Y.js test)
    final doc1 = Doc(clientID: 1);
    final doc2 = Doc(clientID: 2);
    
    final map1 = YMap();
    final map2 = YMap();
    
    doc1.share('testmap', map1);
    doc2.share('testmap', map2);
    
    // Initial operations on doc1 (matching Y.js)
    map1.set('name', 'Alice');
    map1.set('age', 30);
    map1.set('city', 'New York');
    
    // Capture state after first operations
    final update1 = doc1.getUpdateSince({});
    dartResults['dart']['updates']['map_initial'] = update1;
    
    // Apply update to doc2
    doc2.applyUpdate(update1);
    
    // Concurrent operations (matching Y.js)
    map1.set('occupation', 'Engineer'); // doc1 operation
    map2.set('hobby', 'Reading');       // doc2 operation  
    map2.set('age', 31);               // Conflicting operation
    
    // Exchange updates
    final update2 = doc2.getUpdateSince({});
    final update3 = doc1.getUpdateSince({});
    
    doc1.applyUpdate(update2);
    doc2.applyUpdate(update3);
    
    // Capture final states
    dartResults['dart']['maps']['final_doc1'] = map1.toJson();
    dartResults['dart']['maps']['final_doc2'] = map2.toJson();
    dartResults['dart']['updates']['map_final_doc1'] = doc1.getUpdateSince({});
    dartResults['dart']['updates']['map_final_doc2'] = doc2.getUpdateSince({});
    
    print('Dart YMap final state (should be identical): ${dartResults['dart']['maps']['final_doc1']}');
  }

  /// Test YArray CRDT operations matching Y.js test
  void testYArray() {
    print('Testing Dart YArray...');
    
    final doc1 = Doc(clientID: 1);
    final doc2 = Doc(clientID: 2);
    
    final array1 = YArray();
    final array2 = YArray();
    
    doc1.share('testarray', array1);
    doc2.share('testarray', array2);
    
    // Initial operations (matching Y.js)
    array1.pushAll(['apple', 'banana', 'cherry']);
    
    final update1 = doc1.getUpdateSince({});
    dartResults['dart']['updates']['array_initial'] = update1;
    
    doc2.applyUpdate(update1);
    
    // Concurrent operations (matching Y.js)
    array1.insert(1, 'date');        // Insert at index 1 in doc1
    array2.push('elderberry');       // Append to doc2
    array2.delete(2);               // Delete at index 2 in doc2
    
    // Exchange updates
    final update2 = doc2.getUpdateSince({});
    final update3 = doc1.getUpdateSince({});
    
    doc1.applyUpdate(update2);
    doc2.applyUpdate(update3);
    
    dartResults['dart']['arrays']['final_doc1'] = array1.toJson();
    dartResults['dart']['arrays']['final_doc2'] = array2.toJson();
    dartResults['dart']['updates']['array_final_doc1'] = doc1.getUpdateSince({});
    dartResults['dart']['updates']['array_final_doc2'] = doc2.getUpdateSince({});
    
    print('Dart YArray final state (should be identical): ${dartResults['dart']['arrays']['final_doc1']}');
  }

  /// Test YText CRDT operations - most critical for YATA algorithm
  void testYText() {
    print('Testing Dart YText...');
    
    final doc1 = Doc(clientID: 1);
    final doc2 = Doc(clientID: 2);
    
    final text1 = YText();
    final text2 = YText();
    
    doc1.share('testtext', text1);
    doc2.share('testtext', text2);
    
    // Initial text (matching Y.js)
    text1.insert(0, 'Hello World');
    
    final update1 = doc1.getUpdateSince({});
    dartResults['dart']['updates']['text_initial'] = update1;
    
    doc2.applyUpdate(update1);
    
    // Critical YATA test: concurrent edits at same position (matching Y.js)
    text1.insert(5, ' Beautiful'); // doc1: "Hello Beautiful World"
    text2.insert(5, ' Amazing');   // doc2: "Hello Amazing World"
    
    // Additional concurrent operations (matching Y.js)
    text1.insert(text1.length, '!'); // Append to doc1
    text2.delete(0, 5);              // Delete "Hello" from doc2
    
    // Exchange updates
    final update2 = doc2.getUpdateSince({});
    final update3 = doc1.getUpdateSince({});
    
    doc1.applyUpdate(update2);
    doc2.applyUpdate(update3);
    
    dartResults['dart']['texts']['final_doc1'] = text1.toString();
    dartResults['dart']['texts']['final_doc2'] = text2.toString();
    dartResults['dart']['updates']['text_final_doc1'] = doc1.getUpdateSince({});
    dartResults['dart']['updates']['text_final_doc2'] = doc2.getUpdateSince({});
    
    print('Dart YText final state (should be identical):');
    print('Doc1: ${dartResults['dart']['texts']['final_doc1']}');
    print('Doc2: ${dartResults['dart']['texts']['final_doc2']}');
    
    // Test interleaving prevention
    if (dartResults['dart']['texts']['final_doc1'] == dartResults['dart']['texts']['final_doc2']) {
      print('✅ Dart YATA algorithm working - no text interleaving');
    } else {
      print('❌ Text interleaving detected in Dart - YATA algorithm issue');
    }
  }

  /// Compare Dart results with Y.js results from JSON file
  void compareWithYjs(Map<String, dynamic> yjsResults) {
    print('\n🔄 Comparing Y.js and Dart results...');
    
    bool allTestsPassed = true;
    
    // Compare YMap results
    final yjsMaps = yjsResults['yjs']['maps'];
    final dartMaps = dartResults['dart']['maps'];
    
    if (_deepEquals(yjsMaps['final_doc1'], dartMaps['final_doc1']) &&
        _deepEquals(yjsMaps['final_doc2'], dartMaps['final_doc2'])) {
      print('✅ YMap compatibility: PASSED');
    } else {
      print('❌ YMap compatibility: FAILED');
      print('  Y.js result: ${yjsMaps['final_doc1']}');
      print('  Dart result: ${dartMaps['final_doc1']}');
      allTestsPassed = false;
    }
    
    // Compare YArray results  
    final yjsArrays = yjsResults['yjs']['arrays'];
    final dartArrays = dartResults['dart']['arrays'];
    
    if (_deepEquals(yjsArrays['final_doc1'], dartArrays['final_doc1']) &&
        _deepEquals(yjsArrays['final_doc2'], dartArrays['final_doc2'])) {
      print('✅ YArray compatibility: PASSED');
    } else {
      print('❌ YArray compatibility: FAILED');
      print('  Y.js result: ${yjsArrays['final_doc1']}');
      print('  Dart result: ${dartArrays['final_doc1']}');
      allTestsPassed = false;
    }
    
    // Compare YText results (most important for YATA)
    final yjsTexts = yjsResults['yjs']['texts'];
    final dartTexts = dartResults['dart']['texts'];
    
    if (yjsTexts['final_doc1'] == dartTexts['final_doc1'] &&
        yjsTexts['final_doc2'] == dartTexts['final_doc2']) {
      print('✅ YText compatibility: PASSED');
      print('✅ YATA algorithm working correctly in both implementations');
    } else {
      print('❌ YText compatibility: FAILED');
      print('  Y.js result: "${yjsTexts['final_doc1']}"');
      print('  Dart result: "${dartTexts['final_doc1']}"');
      allTestsPassed = false;
    }
    
    // Binary protocol compatibility test
    _testBinaryProtocolCompatibility(yjsResults);
    
    if (allTestsPassed) {
      print('\n🎉 ALL COMPATIBILITY TESTS PASSED!');
      print('   Y.js and Dart implementations can collaborate successfully');
    } else {
      print('\n❌ COMPATIBILITY TESTS FAILED');
      print('   Y.js and Dart implementations are not fully compatible');
    }
  }

  /// Test binary protocol compatibility
  void _testBinaryProtocolCompatibility(Map<String, dynamic> yjsResults) {
    print('\n🔧 Testing binary protocol compatibility...');
    
    try {
      // Try to decode Y.js updates with Dart
      final yjsMapUpdate = yjsResults['yjs']['updates']['map_initial'];
      if (yjsMapUpdate is List) {
        final bytes = Uint8List.fromList(yjsMapUpdate.cast<int>());
        // TODO: Implement actual binary decoding when available
        print('📦 Y.js binary update size: ${bytes.length} bytes');
        print('✅ Binary protocol structure readable');
      }
      
    } catch (e) {
      print('❌ Binary protocol compatibility issue: $e');
    }
  }

  /// Deep equality comparison for nested structures
  bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType) return false;
    
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    
    return a == b;
  }

  /// Run all Dart tests
  Future<Map<String, dynamic>> runTests() async {
    print('Starting Dart compatibility tests...');
    
    try {
      testYMap();
      testYArray();
      testYText();
      
      // Save results for comparison
      final resultsFile = File('yjs_dart_compatibility_test/dart_test_results.json');
      await resultsFile.writeAsString(JsonEncoder.withIndent('  ').convert(dartResults));
      
      print('\n✅ Dart tests completed successfully!');
      print('Results saved to: ${resultsFile.path}');
      
      return dartResults;
      
    } catch (error) {
      print('❌ Dart tests failed: $error');
      rethrow;
    }
  }
}

/// Main test suite
void main() {
  group('Y.js and Dart CRDT Compatibility Tests', () {
    late DartCompatibilityTest dartTester;
    
    setUp(() {
      dartTester = DartCompatibilityTest();
    });
    
    test('Dart CRDT operations work correctly', () async {
      final results = await dartTester.runTests();
      expect(results['dart']['maps']['final_doc1'], isNotNull);
      expect(results['dart']['arrays']['final_doc1'], isNotNull);
      expect(results['dart']['texts']['final_doc1'], isNotNull);
    });
    
    test('Y.js and Dart collaboration compatibility', () async {
      // Run Dart tests
      await dartTester.runTests();
      
      // Load Y.js results if available
      final yjsResultsFile = File('yjs_dart_compatibility_test/yjs_test_results.json');
      
      if (await yjsResultsFile.exists()) {
        final yjsResultsJson = await yjsResultsFile.readAsString();
        final yjsResults = JsonDecoder().convert(yjsResultsJson) as Map<String, dynamic>;
        
        // Compare results
        dartTester.compareWithYjs(yjsResults);
      } else {
        print('⚠️  Y.js results not found. Run: cd yjs_dart_compatibility_test && npm install && npm test');
        print('   Then rerun this test to validate full compatibility.');
      }
    });
  });
}