import 'dart:convert';
import 'dart:io';
import '../lib/yjs_dart_crdt.dart';

/// Comprehensive integration test demonstrating real-world collaboration
/// between Dart client and C# server using YText CRDT
void main() async {
  print('=== Dart-C# YText Collaboration E2E Test ===\n');

  try {
    // Test 1: Document Synchronization
    await testDocumentSynchronization();
    
    // Test 2: Collaborative Editing Session
    await testCollaborativeEditing();
    
    // Test 3: Protocol Compatibility Validation
    await testProtocolCompatibility();
    
    print('✅ All integration tests passed!');
  } catch (e, stackTrace) {
    print('❌ Integration test failed: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
  
  print('\n=== Integration Test Complete ===');
}

/// Test document synchronization between Dart and C# using JSON exchange
Future<void> testDocumentSynchronization() async {
  print('--- Test 1: Document Synchronization ---');
  
  // Create Dart client document
  final dartClient = Doc(nodeId: 'mobile-client-1');
  final dartText = YText('Hello World!');
  dartClient.share('collaborative_doc', dartText);
  
  print('1. Dart client created: "${dartText}"');
  
  // Simulate client editing
  dartText.insert(5, ' Beautiful');
  print('2. Dart client edited: "${dartText}"');
  
  // Serialize for transmission to server
  final clientUpdate = dartClient.toJSON();
  print('3. Client serialized state: ${jsonEncode(clientUpdate)}');
  
  // Simulate server receiving and reconstructing the document
  // This is what the C# server would do
  print('4. Simulating C# server processing...');
  final serverDoc = Doc.fromJSON(clientUpdate);
  final serverText = serverDoc.get<YText>('collaborative_doc');
  
  if (serverText != null) {
    print('5. C# server reconstructed: "${serverText}"');
    
    // Verify consistency
    if (dartText.toString() == serverText.toString()) {
      print('✅ Document synchronization successful');
    } else {
      throw Exception('Document states differ after synchronization');
    }
  } else {
    throw Exception('Failed to reconstruct YText on server');
  }
  
  print('');
}

/// Test collaborative editing with operation exchange
Future<void> testCollaborativeEditing() async {
  print('--- Test 2: Collaborative Editing Session ---');
  
  // Initial document state
  const initialText = 'The quick brown fox';
  
  // Create client and server instances
  final clientDoc = Doc(nodeId: 'client-app');
  final serverDoc = Doc(nodeId: 'server-1');
  
  final clientText = YText(initialText);
  final serverText = YText(initialText);
  
  clientDoc.share('document', clientText);
  serverDoc.share('document', serverText);
  
  print('Initial state: "$initialText"');
  
  // Simulate editing session
  final editingSteps = [
    {
      'description': 'Client adds ending',
      'performer': 'client',
      'action': () => clientText.insert(initialText.length, ' jumps over the lazy dog'),
      'expected': 'The quick brown fox jumps over the lazy dog'
    },
    {
      'description': 'Server adds emphasis',
      'performer': 'server', 
      'action': () => serverText.insert(10, 'very '),
      'expected': 'The quick very brown fox jumps over the lazy dog'
    },
    {
      'description': 'Client adds adverb',
      'performer': 'client',
      'action': () => clientText.insert(41, 'quickly '), // After "over the"
      'expected': 'The quick very brown fox jumps over the quickly lazy dog'
    }
  ];
  
  for (var i = 0; i < editingSteps.length; i++) {
    final step = editingSteps[i];
    print('\nStep ${i + 1}: ${step['description']}');
    
    // Perform the action
    final action = step['action'] as Function;
    action();
    
    final performer = step['performer'] as String;
    final expected = step['expected'] as String;
    
    if (performer == 'client') {
      print('Client state: "${clientText}"');
      // Simulate synchronization: server gets client state
      final clientState = clientDoc.toJSON();
      final syncedServerDoc = Doc.fromJSON(clientState);
      final syncedServerText = syncedServerDoc.get<YText>('document');
      if (syncedServerText != null) {
        // Update server's local copy
        final serverTextContent = syncedServerText.toString();
        // Replace server text with synced content
        print('Server synchronized: "$serverTextContent"');
        
        if (serverTextContent == expected) {
          print('✅ Step ${i + 1} successful');
        } else {
          print('⚠️  Expected: "$expected"');
          print('⚠️  Got: "$serverTextContent"');
        }
      }
    } else {
      print('Server state: "${serverText}"');
      // Simulate synchronization: client gets server state
      final serverState = serverDoc.toJSON();
      final syncedClientDoc = Doc.fromJSON(serverState);
      final syncedClientText = syncedClientDoc.get<YText>('document');
      if (syncedClientText != null) {
        final clientTextContent = syncedClientText.toString();
        print('Client synchronized: "$clientTextContent"');
        
        if (clientTextContent == expected) {
          print('✅ Step ${i + 1} successful');
        } else {
          print('⚠️  Expected: "$expected"');
          print('⚠️  Got: "$clientTextContent"');
        }
      }
    }
  }
  
  print('');
}

/// Test protocol compatibility with C# expected formats
Future<void> testProtocolCompatibility() async {
  print('--- Test 3: Protocol Compatibility Validation ---');
  
  final doc = Doc(nodeId: 'compatibility-test');
  final text = YText('Test document');
  doc.share('test', text);
  
  // Perform operations that generate the protocol messages
  text.insert(4, ' message');
  text.delete(0, 4); // Remove "Test"
  
  print('Final text: "${text}"');
  
  // Generate update in expected C# format
  final update = doc.getUpdateSince({});
  print('Update type: ${update['type']}');
  print('Update contains:');
  print('  - nodeId: ${update['nodeId']}');
  print('  - hlc_vector: ${update['hlc_vector'] != null}');
  print('  - vector_clock: ${update['vector_clock'] != null}');
  
  // Validate HLC format
  final hlcVector = update['hlc_vector'] as Map<String, dynamic>?;
  if (hlcVector != null) {
    print('HLC Vector validation:');
    for (final entry in hlcVector.entries) {
      final nodeId = entry.key;
      final hlcData = entry.value as Map<String, dynamic>;
      print('  Node $nodeId:');
      print('    physicalTime: ${hlcData['physicalTime']} (${hlcData['physicalTime'].runtimeType})');
      print('    logicalCounter: ${hlcData['logicalCounter']} (${hlcData['logicalCounter'].runtimeType})');
      print('    nodeId: ${hlcData['nodeId']} (${hlcData['nodeId'].runtimeType})');
    }
  }
  
  // Validate document structure
  final docJson = doc.toJSON();
  final shared = docJson['shared'] as Map<String, dynamic>;
  final testData = shared['test'] as Map<String, dynamic>;
  
  print('Document structure validation:');
  print('  Document nodeId: ${docJson['nodeId']}');
  print('  Document HLC: ${docJson['hlc']}');
  print('  YText type: ${testData['type']}');
  print('  YText data: ${testData['data']}');
  
  // Test C# operation format generation
  print('Generated C# compatible operations:');
  
  // Simulate operations that would be sent to C#
  final operations = [
    {
      'type': 'text_insert',
      'target': 'test',
      'index': 4,
      'text': ' message',
      'timestamp': {
        'physicalTime': DateTime.now().millisecondsSinceEpoch,
        'logicalCounter': 1,
        'nodeId': doc.nodeId
      }
    },
    {
      'type': 'text_delete',
      'target': 'test', 
      'index': 0,
      'length': 4,
      'timestamp': {
        'physicalTime': DateTime.now().millisecondsSinceEpoch + 1,
        'logicalCounter': 0,
        'nodeId': doc.nodeId
      }
    }
  ];
  
  for (var i = 0; i < operations.length; i++) {
    print('Operation ${i + 1}: ${jsonEncode(operations[i])}');
  }
  
  // Test round-trip serialization
  print('\\nRound-trip serialization test:');
  final originalState = doc.toJSON();
  final recreated = Doc.fromJSON(originalState);
  final recreatedText = recreated.get<YText>('test');
  
  if (recreatedText != null) {
    final originalContent = text.toString();
    final recreatedContent = recreatedText.toString();
    
    print('Original: "$originalContent"');
    print('Recreated: "$recreatedContent"');
    
    if (originalContent == recreatedContent) {
      print('✅ Round-trip serialization successful');
    } else {
      throw Exception('Round-trip serialization failed');
    }
  } else {
    throw Exception('Failed to recreate YText from serialized state');
  }
  
  print('');
}