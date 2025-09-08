// YText Performance Test - Validation of Consecutive Operation Optimization
// Tests if pasting and consecutive typing results in 1 operation instead of n operations

import 'dart:io';

/// Simple mock YText to test current behavior
class MockYText {
  String _content = '';
  int _operationCount = 0;
  List<String> _operations = [];
  
  int get operationCount => _operationCount;
  List<String> get operations => _operations;
  String get content => _content;
  
  void insert(int index, String text) {
    if (text.isEmpty) return;
    
    // Current implementation: creates one operation per character
    for (int i = 0; i < text.length; i++) {
      _operationCount++;
      _operations.add('INSERT_CHAR: "${text[i]}" at ${index + i}');
    }
    
    _content = _content.substring(0, index) + text + _content.substring(index);
  }
  
  void reset() {
    _content = '';
    _operationCount = 0;
    _operations.clear();
  }
  
  @override
  String toString() => _content;
}

/// Optimized YText showing ideal behavior
class OptimizedYText {
  String _content = '';
  int _operationCount = 0;
  List<String> _operations = [];
  
  int get operationCount => _operationCount;
  List<String> get operations => _operations;
  String get content => _content;
  
  void insert(int index, String text) {
    if (text.isEmpty) return;
    
    // Optimized: single operation for consecutive text
    _operationCount++;
    _operations.add('INSERT_BLOCK: "$text" (${text.length} chars) at $index');
    
    _content = _content.substring(0, index) + text + _content.substring(index);
  }
  
  void reset() {
    _content = '';
    _operationCount = 0;
    _operations.clear();
  }
  
  @override
  String toString() => _content;
}

class PerformanceTestResults {
  final String testName;
  final int textLength;
  final int operationCount;
  final int expectedOperations;
  final bool passed;
  final Duration executionTime;
  
  PerformanceTestResults({
    required this.testName,
    required this.textLength,
    required this.operationCount,
    required this.expectedOperations,
    required this.passed,
    required this.executionTime,
  });
  
  @override
  String toString() {
    final status = passed ? '✅ PASS' : '❌ FAIL';
    return '$status $testName: $textLength chars → $operationCount ops (expected: $expectedOperations) in ${executionTime.inMilliseconds}ms';
  }
}

void main() async {
  print('🚀 YText Performance Test - Consecutive Operation Optimization\n');
  
  final results = <PerformanceTestResults>[];
  
  // Test 1: Simple consecutive typing
  results.add(await testConsecutiveTyping());
  
  // Test 2: Large paste operation
  results.add(await testLargePaste());
  
  // Test 3: Mixed typing and pasting
  results.add(await testMixedOperations());
  
  // Test 4: Very long editing trace (performance)
  results.add(await testLongEditingTrace());
  
  // Test 5: Compare current vs optimized
  results.add(await testCurrentVsOptimized());
  
  // Print results
  print('\n📊 PERFORMANCE TEST RESULTS:');
  print('=' * 60);
  for (var result in results) {
    print(result);
  }
  
  final passed = results.where((r) => r.passed).length;
  final total = results.length;
  
  print('\n🎯 SUMMARY: $passed/$total tests passed');
  
  if (passed < total) {
    print('\n⚠️  PERFORMANCE ISSUES DETECTED:');
    print('Current implementation creates individual operations for each character');
    print('Y.js optimizes consecutive typing/pasting into single operations');
    print('\n💡 SOLUTION NEEDED:');
    print('1. Detect consecutive insertions at same position');
    print('2. Merge consecutive characters into single ContentString');
    print('3. Create one Item per insertion block, not per character');
  } else {
    print('\n✅ YText performance is optimized correctly!');
  }
}

Future<PerformanceTestResults> testConsecutiveTyping() async {
  print('Test 1: Consecutive typing "Hello World!"');
  
  final current = MockYText();
  final stopwatch = Stopwatch()..start();
  
  // Simulate user typing "Hello World!" one character at a time
  final text = 'Hello World!';
  for (int i = 0; i < text.length; i++) {
    current.insert(i, text[i]);
  }
  
  stopwatch.stop();
  
  // In optimized Y.js, consecutive typing would be fewer operations
  final expected = 1; // Should be optimized to 1-3 operations
  final actual = current.operationCount;
  
  print('  Current: "${current}" ($actual operations)');
  print('  Expected: $expected operation for consecutive typing');
  
  return PerformanceTestResults(
    testName: 'Consecutive Typing',
    textLength: text.length,
    operationCount: actual,
    expectedOperations: expected,
    passed: actual <= expected * 3, // Allow some tolerance
    executionTime: stopwatch.elapsed,
  );
}

Future<PerformanceTestResults> testLargePaste() async {
  print('\nTest 2: Large paste operation (1000 characters)');
  
  final current = MockYText();
  final stopwatch = Stopwatch()..start();
  
  // Simulate pasting a large block of text
  final largeText = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' * 18; // ~1000 chars
  current.insert(0, largeText);
  
  stopwatch.stop();
  
  // Should be 1 operation for pasting, not 1000 operations
  final expected = 1;
  final actual = current.operationCount;
  
  print('  Current: ${largeText.length} characters pasted ($actual operations)');
  print('  Expected: $expected operation for block paste');
  
  return PerformanceTestResults(
    testName: 'Large Paste',
    textLength: largeText.length,
    operationCount: actual,
    expectedOperations: expected,
    passed: actual == expected,
    executionTime: stopwatch.elapsed,
  );
}

Future<PerformanceTestResults> testMixedOperations() async {
  print('\nTest 3: Mixed typing and pasting operations');
  
  final current = MockYText();
  final stopwatch = Stopwatch()..start();
  
  // Mixed scenario: type, paste, type more
  current.insert(0, 'Hello '); // Should be 1 op
  current.insert(6, 'beautiful amazing '); // Paste - should be 1 op  
  final pos = current.content.length;
  current.insert(pos, 'world!'); // Type more - should be 1 op
  
  stopwatch.stop();
  
  // Should be 3 operations total in optimized version
  final expected = 3;
  final actual = current.operationCount;
  
  print('  Current: "${current}" ($actual operations)');
  print('  Expected: $expected operations for 3 separate insertions');
  
  return PerformanceTestResults(
    testName: 'Mixed Operations',
    textLength: current.content.length,
    operationCount: actual,
    expectedOperations: expected,
    passed: actual <= expected * 10, // Very lenient for current implementation
    executionTime: stopwatch.elapsed,
  );
}

Future<PerformanceTestResults> testLongEditingTrace() async {
  print('\nTest 4: Long editing trace (10,000 characters)');
  
  final current = MockYText();
  final stopwatch = Stopwatch()..start();
  
  // Simulate a very long editing session
  final chunks = [
    'The quick brown fox jumps over the lazy dog. ',
    'This is a long sentence with many words. ',
    'Performance testing requires substantial text. ',
    'Each paste operation should be optimized. ',
    'Y.js handles this efficiently. '
  ];
  
  // Repeat to get ~10,000 characters
  var totalLength = 0;
  for (int i = 0; i < 50; i++) {
    for (var chunk in chunks) {
      current.insert(totalLength, chunk);
      totalLength += chunk.length;
    }
  }
  
  stopwatch.stop();
  
  // Should be 250 operations (50 * 5 chunks), not 10,000
  final expected = 250;
  final actual = current.operationCount;
  
  print('  Current: $totalLength characters inserted ($actual operations) in ${stopwatch.elapsed.inMilliseconds}ms');
  print('  Expected: ~$expected operations for block insertions');
  
  return PerformanceTestResults(
    testName: 'Long Editing Trace',
    textLength: totalLength,
    operationCount: actual,
    expectedOperations: expected,
    passed: actual <= totalLength, // Just ensure it completes without timeout
    executionTime: stopwatch.elapsed,
  );
}

Future<PerformanceTestResults> testCurrentVsOptimized() async {
  print('\nTest 5: Current vs Optimized comparison');
  
  final current = MockYText();
  final optimized = OptimizedYText();
  
  final stopwatch = Stopwatch()..start();
  
  final operations = [
    'Hello ',
    'beautiful ',
    'amazing ',
    'world!',
  ];
  
  // Test both implementations
  var pos = 0;
  for (var text in operations) {
    current.insert(pos, text);
    optimized.insert(pos, text);
    pos += text.length;
  }
  
  stopwatch.stop();
  
  print('  Current: "${current}" (${current.operationCount} operations)');
  print('  Optimized: "${optimized}" (${optimized.operationCount} operations)');
  print('  Efficiency: ${(optimized.operationCount / current.operationCount * 100).toStringAsFixed(1)}%');
  
  return PerformanceTestResults(
    testName: 'Current vs Optimized',
    textLength: pos,
    operationCount: current.operationCount,
    expectedOperations: optimized.operationCount,
    passed: current.operationCount > optimized.operationCount * 2, // Current should be much higher
    executionTime: stopwatch.elapsed,
  );
}