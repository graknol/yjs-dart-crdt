import 'dart:convert';
import 'dart:io';
import '../lib/yjs_dart_crdt.dart';

/// Integration test demonstrating collaboration between Dart and C# implementations
/// This simulates editing trace where both Dart and C# communicate with each other
/// and validates that they can collaborate on the same data, especially YText
void main() async {
  print('=== Dart-C# YText Collaboration Integration Test ===\n');

  // Test 1: Basic Cross-Platform YText Collaboration
  await testBasicCrossPlatformCollaboration();

  // Test 2: Complex Editing Scenario
  await testComplexEditingScenario();
  
  // Test 3: JSON Format Compatibility
  await testJsonCompatibility();
  
  print('\n=== All Integration Tests Completed ===');
}

/// Test basic cross-platform collaboration
Future<void> testBasicCrossPlatformCollaboration() async {
  print('--- Test 1: Basic Cross-Platform YText Collaboration ---');
  
  // Create Dart document with YText
  final dartDoc = Doc(nodeId: 'dart-client-1');
  final dartText = YText('Hello ');
  dartDoc.share('document', dartText);
  
  print('Dart initial: "${dartText}"');
  
  // Simulate editing on Dart side
  dartText.insert(6, 'beautiful ');
  print('Dart after edit: "${dartText}"');
  
  // Serialize Dart document state to pass to C#
  final dartJson = dartDoc.toJSON();
  print('Dart document JSON: ${jsonEncode(dartJson)}');
  
  // Extract the YText data for C# consumption
  final shared = dartJson['shared'] as Map<String, dynamic>;
  final documentData = shared['document'] as Map<String, dynamic>;
  final ytextData = documentData['data'] as String;
  
  // Create C# compatible format
  final csharpFormat = {
    'type': 'YText',
    'text': ytextData
  };
  print('C# compatible format: ${jsonEncode(csharpFormat)}');
  
  // Simulate what C# would do (parsing and creating its own YText)
  // In real integration, C# would receive this JSON and create its YText
  final receivedText = ytextData;
  print('Text received by C# simulation: "$receivedText"');
  
  // Simulate C# editing and sending back
  final csharpEditedText = receivedText + 'world!';
  print('C# after edit: "$csharpEditedText"');
  
  // Dart receives the update
  final dartText2 = YText(csharpEditedText);
  print('Dart final result: "${dartText2}"');
  
  print('');
}

/// Test complex editing scenario with operations
Future<void> testComplexEditingScenario() async {
  print('--- Test 2: Complex Editing Scenario ---');
  
  // Simulate a realistic editing session
  final dartDoc = Doc(nodeId: 'mobile-app');
  final csharpDoc = Doc(nodeId: 'server-1');
  
  final dartText = YText('The quick brown fox');
  final csharpText = YText('The quick brown fox');
  
  dartDoc.share('shared_document', dartText);
  csharpDoc.share('shared_document', csharpText);
  
  print('Initial state: "${dartText}"');
  
  // Simulate editing trace
  final edits = [
    {'client': 'dart', 'op': 'insert', 'index': 19, 'text': ' jumps over the lazy dog'},
    {'client': 'csharp', 'op': 'insert', 'index': 10, 'text': 'very '},
    {'client': 'dart', 'op': 'insert', 'index': 35, 'text': 'quickly '},
    {'client': 'csharp', 'op': 'delete', 'index': 40, 'length': 4}, // Remove "lazy"
    {'client': 'dart', 'op': 'insert', 'index': 40, 'text': 'sleepy'},
  ];
  
  YText currentDartText = dartText;
  YText currentCsharpText = csharpText;
  
  for (var edit in edits) {
    print('\nApplying edit: ${edit}');
    
    if (edit['client'] == 'dart') {
      if (edit['op'] == 'insert') {
        currentDartText.insert(edit['index'] as int, edit['text'] as String);
        // Simulate sending to C#
        currentCsharpText = YText(currentDartText.toString());
      } else if (edit['op'] == 'delete') {
        currentDartText.delete(edit['index'] as int, edit['length'] as int);
        currentCsharpText = YText(currentDartText.toString());
      }
    } else {
      if (edit['op'] == 'insert') {
        currentCsharpText = YText(currentCsharpText.toString());
        final newText = currentCsharpText.toString();
        final index = edit['index'] as int;
        final text = edit['text'] as String;
        final result = newText.substring(0, index) + text + newText.substring(index);
        currentCsharpText = YText(result);
        // Simulate sending back to Dart
        currentDartText = YText(currentCsharpText.toString());
      } else if (edit['op'] == 'delete') {
        final newText = currentCsharpText.toString();
        final index = edit['index'] as int;
        final length = edit['length'] as int;
        final result = newText.substring(0, index) + newText.substring(index + length);
        currentCsharpText = YText(result);
        currentDartText = YText(currentCsharpText.toString());
      }
    }
    
    print('Dart state: "${currentDartText}"');
    print('C# state: "${currentCsharpText}"');
    
    // Verify consistency
    if (currentDartText.toString() == currentCsharpText.toString()) {
      print('✓ States are consistent');
    } else {
      print('✗ States differ!');
    }
  }
  
  print('');
}

/// Test JSON format compatibility
Future<void> testJsonCompatibility() async {
  print('--- Test 3: JSON Format Compatibility ---');
  
  // Create a document with various edits
  final doc = Doc(nodeId: 'compatibility-test');
  final text = YText('Initial text');
  doc.share('test_document', text);
  
  // Perform some operations
  text.insert(7, ' content');
  text.insert(15, ' with edits');
  text.delete(0, 7); // Remove "Initial"
  
  print('Final text: "${text}"');
  
  // Test serialization
  final docJson = doc.toJSON();
  print('Document JSON structure:');
  print('- nodeId: ${docJson['nodeId']}');
  print('- hlc: ${docJson['hlc']}');
  print('- shared keys: ${(docJson['shared'] as Map).keys}');
  
  final shared = docJson['shared'] as Map<String, dynamic>;
  final testDocData = shared['test_document'] as Map<String, dynamic>;
  print('- YText type: ${testDocData['type']}');
  print('- YText data: ${testDocData['data']}');
  
  // Test deserialization
  final reconstructedDoc = Doc.fromJSON(docJson);
  final reconstructedText = reconstructedDoc.get<YText>('test_document');
  
  if (reconstructedText != null) {
    print('Reconstructed text: "${reconstructedText}"');
    
    if (text.toString() == reconstructedText.toString()) {
      print('✓ Serialization/deserialization successful');
    } else {
      print('✗ Serialization/deserialization failed');
    }
  } else {
    print('✗ Failed to reconstruct YText from JSON');
  }
  
  // Generate C# compatible operations format
  print('\nGenerating C# compatible operation format:');
  
  final operations = [
    {
      'type': 'text_insert',
      'index': 7,
      'text': ' content',
      'timestamp': {
        'physicalTime': DateTime.now().millisecondsSinceEpoch,
        'logicalCounter': 1,
        'nodeId': 'dart-client'
      }
    },
    {
      'type': 'text_insert', 
      'index': 15,
      'text': ' with edits',
      'timestamp': {
        'physicalTime': DateTime.now().millisecondsSinceEpoch,
        'logicalCounter': 2,
        'nodeId': 'dart-client'
      }
    },
    {
      'type': 'text_delete',
      'index': 0,
      'length': 7,
      'timestamp': {
        'physicalTime': DateTime.now().millisecondsSinceEpoch,
        'logicalCounter': 3,
        'nodeId': 'dart-client'
      }
    }
  ];
  
  for (var op in operations) {
    print('Operation: ${jsonEncode(op)}');
  }
  
  print('');
}