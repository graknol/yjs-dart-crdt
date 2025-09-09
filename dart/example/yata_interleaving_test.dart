#!/usr/bin/env dart

/// Comprehensive test for YATA algorithm and text interleaving prevention
/// Tests that concurrent text edits don't result in character interleaving
/// and that proper conflict resolution is achieved using YATA origins.

import 'dart:math';
import '../lib/yjs_dart_crdt.dart';

void main() {
  print('=== YATA Text Interleaving Prevention Test ===\n');
  
  // Test 1: Basic concurrent insertions at same position
  testBasicConcurrentInsertions();
  
  // Test 2: Character interleaving prevention
  testCharacterInterleavingPrevention();
  
  // Test 3: Complex collaboration scenario
  testComplexCollaboration();
  
  // Test 4: Operation ordering with YATA origins
  testYataOriginOrdering();
  
  print('\n=== All YATA Tests Complete ===');
}

/// Test concurrent insertions at the same logical position
void testBasicConcurrentInsertions() {
  print('--- Test 1: Basic Concurrent Insertions ---');
  
  // Create two clients with shared initial document
  final client1 = Doc(nodeId: 'client-1');
  final client2 = Doc(nodeId: 'client-2');
  
  // Initialize only one client with text, then sync to the other
  final text1 = YText('Hello World');
  client1.share('doc', text1);
  
  // Sync initial state to client2
  final initialSync = client1.getUpdateSince({});
  client2.applyUpdate(initialSync);
  final text2 = client2.get<YText>('doc')!;
  
  print('Initial state: "${text1.toString()}"');
  
  // Client 1 inserts at position 6 (after "Hello ")
  text1.insert(6, 'beautiful ');
  print('Client 1 adds "beautiful ": "${text1.toString()}"');
  
  // Client 2 inserts at same position 6 - concurrent edit
  text2.insert(6, 'wonderful ');
  print('Client 2 adds "wonderful ": "${text2.toString()}"');
  
  // Simulate synchronization - Client 1 receives Client 2's changes
  final update2to1 = client2.getUpdateSince({});
  if (update2to1['type'] == 'delta_update' || update2to1['type'] == 'full_state') {
    client1.applyUpdate(update2to1);
    print('Client 1 after sync: "${text1.toString()}"');
  }
  
  // Simulate synchronization - Client 2 receives Client 1's changes  
  final update1to2 = client1.getUpdateSince({});
  if (update1to2['type'] == 'delta_update' || update1to2['type'] == 'full_state') {
    client2.applyUpdate(update1to2);
    print('Client 2 after sync: "${text2.toString()}"');
  }
  
  // Validate both clients converged to same state
  final final1 = text1.toString();
  final final2 = text2.toString();
  
  if (final1 == final2) {
    print('✅ Convergence successful: "$final1"');
  } else {
    print('❌ Convergence failed!');
    print('  Client 1: "$final1"');
    print('  Client 2: "$final2"');
  }
  
  print('');
}

/// Test that characters from same operation stay together (no interleaving)
void testCharacterInterleavingPrevention() {
  print('--- Test 2: Character Interleaving Prevention ---');
  
  final client1 = Doc(nodeId: 'alice');
  final client2 = Doc(nodeId: 'bob');
  
  // Initialize from one client
  final text1 = YText('cat');
  client1.share('doc', text1);
  
  // Sync to second client
  final initialSync = client1.getUpdateSince({});
  client2.applyUpdate(initialSync);
  final text2 = client2.get<YText>('doc')!;
  
  print('Initial state: "${text1.toString()}"');
  
  // Alice adds 'big ' before 'cat'
  text1.insert(0, 'big ');
  print('Alice adds "big ": "${text1.toString()}"');
  
  // Bob adds 'black ' before 'cat' at same time (concurrent)
  text2.insert(0, 'black ');
  print('Bob adds "black ": "${text2.toString()}"');
  
  // Cross-synchronization
  final updateB2A = client2.getUpdateSince({});
  final updateA2B = client1.getUpdateSince({});
  
  if (updateB2A['type'] != 'no_changes') {
    client1.applyUpdate(updateB2A);
  }
  
  if (updateA2B['type'] != 'no_changes') {
    client2.applyUpdate(updateA2B);
  }
  
  final result1 = text1.toString();
  final result2 = text2.toString();
  
  print('Final Alice: "$result1"');
  print('Final Bob: "$result2"');
  
  // Check for convergence
  if (result1 == result2) {
    print('✅ Convergence achieved: "$result1"');
    
    // Check that words didn't interleave (e.g., not "blbigack cat" or "bbilagck cat")
    final hasProperWords = (result1.contains('big') && result1.contains('black')) ||
                           result1 == 'big cat' || result1 == 'black cat';
    
    if (hasProperWords) {
      print('✅ No character interleaving detected');
    } else {
      print('⚠️  Possible character interleaving: "$result1"');
    }
  } else {
    print('❌ No convergence achieved');
  }
  
  print('');
}

/// Test complex multi-step collaboration scenario
void testComplexCollaboration() {
  print('--- Test 3: Complex Collaboration Scenario ---');
  
  final server = Doc(nodeId: 'server-1');
  final mobile = Doc(nodeId: 'mobile-client');
  final web = Doc(nodeId: 'web-client');
  
  // All start with same document
  final serverText = YText('The quick brown fox');
  final mobileText = YText('The quick brown fox');
  final webText = YText('The quick brown fox');
  
  server.share('collaborative_doc', serverText);
  mobile.share('collaborative_doc', mobileText);
  web.share('collaborative_doc', webText);
  
  print('Initial: "${serverText.toString()}"');
  
  // Step 1: Mobile adds ending
  mobileText.insert(mobileText.length, ' jumps over the lazy dog');
  print('Mobile adds ending: "${mobileText.toString()}"');
  
  // Step 2: Web adds emphasis (concurrent with mobile)
  webText.insert(10, 'very '); // After "The quick "
  print('Web adds emphasis: "${webText.toString()}"');
  
  // Step 3: Server adds adverb (concurrent)
  serverText.insert(serverText.length - 3, ' quickly'); // Before "fox"
  print('Server adds adverb: "${serverText.toString()}"');
  
  // Multi-way synchronization
  print('\nSynchronizing all clients...');
  
  // Mobile -> Server
  final mobileUpdate = mobile.getUpdateSince({});
  if (mobileUpdate['type'] != 'no_changes') {
    server.applyUpdate(mobileUpdate);
    print('Server after receiving mobile: "${serverText.toString()}"');
  }
  
  // Web -> Server
  final webUpdate = web.getUpdateSince({});
  if (webUpdate['type'] != 'no_changes') {
    server.applyUpdate(webUpdate);
    print('Server after receiving web: "${serverText.toString()}"');
  }
  
  // Server -> Mobile
  final serverToMobile = server.getUpdateSince({});
  if (serverToMobile['type'] != 'no_changes') {
    mobile.applyUpdate(serverToMobile);
    print('Mobile after receiving server: "${mobileText.toString()}"');
  }
  
  // Server -> Web
  final serverToWeb = server.getUpdateSince({});
  if (serverToWeb['type'] != 'no_changes') {
    web.applyUpdate(serverToWeb);
    print('Web after receiving server: "${webText.toString()}"');
  }
  
  // Check final convergence
  final serverFinal = serverText.toString();
  final mobileFinal = mobileText.toString();
  final webFinal = webText.toString();
  
  print('\nFinal states:');
  print('Server: "$serverFinal"');
  print('Mobile: "$mobileFinal"');
  print('Web: "$webFinal"');
  
  if (serverFinal == mobileFinal && mobileFinal == webFinal) {
    print('✅ All clients converged successfully!');
    
    // Validate expected components are present
    final hasAll = serverFinal.contains('quick') && 
                   serverFinal.contains('brown') && 
                   serverFinal.contains('fox') &&
                   serverFinal.contains('jumps over the lazy dog');
    
    if (hasAll) {
      print('✅ All expected text components preserved');
    } else {
      print('⚠️  Some text components may be missing');
    }
  } else {
    print('❌ Clients did not converge');
  }
  
  print('');
}

/// Test YATA origin tracking and ordering
void testYataOriginOrdering() {
  print('--- Test 4: YATA Origin Ordering ---');
  
  final doc1 = Doc(nodeId: 'node-1');
  final doc2 = Doc(nodeId: 'node-2');
  
  final text1 = YText('AB');
  final text2 = YText('AB');
  
  doc1.share('test', text1);
  doc2.share('test', text2);
  
  print('Initial: "${text1.toString()}"');
  
  // Both clients insert between A and B concurrently
  text1.insert(1, 'X'); // Insert X between A and B
  text2.insert(1, 'Y'); // Insert Y between A and B  
  
  print('Doc1 inserts X: "${text1.toString()}"');
  print('Doc2 inserts Y: "${text2.toString()}"');
  
  // Synchronize both ways
  final update1to2 = doc1.getUpdateSince({});
  final update2to1 = doc2.getUpdateSince({});
  
  if (update1to2['type'] != 'no_changes') {
    doc2.applyUpdate(update1to2);
  }
  
  if (update2to1['type'] != 'no_changes') {
    doc1.applyUpdate(update2to1);
  }
  
  final result1 = text1.toString();
  final result2 = text2.toString();
  
  print('Final Doc1: "$result1"');
  print('Final Doc2: "$result2"');
  
  if (result1 == result2) {
    print('✅ YATA ordering converged: "$result1"');
    
    // Validate deterministic ordering (should be based on node IDs/timestamps)
    final isValidOrdering = result1 == 'AXYB' || result1 == 'AYXB';
    
    if (isValidOrdering) {
      print('✅ Deterministic ordering achieved');
    } else {
      print('⚠️  Unexpected ordering: "$result1"');
    }
  } else {
    print('❌ YATA ordering failed to converge');
  }
  
  print('');
}