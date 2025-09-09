#!/usr/bin/env dart

/// Focused YATA test for concurrent editing
import '../lib/yjs_dart_crdt.dart';

void main() {
  print('=== Focused YATA Concurrent Editing Test ===\n');
  
  testSimpleConcurrentEdits();
}

/// Test two clients making concurrent edits to the same position
void testSimpleConcurrentEdits() {
  print('--- Simple Concurrent Edit Test ---');
  
  // Create two separate documents
  final client1 = Doc(nodeId: 'client-1');
  final client2 = Doc(nodeId: 'client-2');
  
  // Client 1 creates the initial document
  final text1 = YText('AB');
  client1.share('text', text1);
  
  // Client 2 gets the initial state via JSON serialization
  final initialState = client1.toJSON();
  final client2Recreated = Doc.fromJSON(initialState);
  
  // Get Client 2's text reference
  final text2 = client2Recreated.get<YText>('text')!;
  
  print('Initial state:');
  print('  Client 1: "${text1.toString()}"');
  print('  Client 2: "${text2.toString()}"');
  
  if (text1.toString() != text2.toString()) {
    print('❌ Initial synchronization failed');
    return;
  }
  
  // Both clients make concurrent edits at position 1 (between A and B)
  text1.insert(1, 'X'); // Client 1: A[X]B -> AXB
  text2.insert(1, 'Y'); // Client 2: A[Y]B -> AYB (concurrent)
  
  print('\nAfter concurrent edits:');
  print('  Client 1: "${text1.toString()}"');
  print('  Client 2: "${text2.toString()}"');
  
  // Get updates from each client
  final update1to2 = client1.getUpdateSince({});  
  final update2to1 = client2Recreated.getUpdateSince({});
  
  print('\nSynchronizing...');
  print('Update 1->2 type: ${update1to2['type']}');
  print('Update 2->1 type: ${update2to1['type']}');
  
  // Apply updates to achieve convergence
  if (update1to2['type'] != 'no_changes') {
    client2Recreated.applyUpdate(update1to2);
  }
  
  if (update2to1['type'] != 'no_changes') {
    client1.applyUpdate(update2to1);
  }
  
  print('\nAfter synchronization:');
  print('  Client 1: "${text1.toString()}"');
  print('  Client 2: "${text2.toString()}"');
  
  final result1 = text1.toString();
  final result2 = text2.toString();
  
  if (result1 == result2) {
    print('✅ YATA convergence achieved: "$result1"');
    
    // Check for proper structure
    if (result1.length == 4 && result1.startsWith('A') && result1.endsWith('B')) {
      print('✅ Structure preserved (A...B)');
      
      final middle = result1.substring(1, 3);
      if (middle == 'XY' || middle == 'YX') {
        print('✅ Concurrent characters properly ordered: $middle');
      } else {
        print('⚠️  Unexpected character ordering: $middle');
      }
    } else {
      print('⚠️  Unexpected result structure: $result1 (expected A?B with length 4)');
    }
  } else {
    print('❌ YATA convergence failed');
    print('  Client 1 result: "$result1"');  
    print('  Client 2 result: "$result2"');
  }
  
  print('');
}