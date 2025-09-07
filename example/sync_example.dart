import 'dart:convert';
import '../lib/yjs_dart_crdt.dart';
import '../lib/src/encoding.dart';

void main() {
  print('=== CRDT Synchronization Example ===\n');

  // Simulate two clients working on the same project
  final client1 = Doc(clientID: 1001);
  final client2 = Doc(clientID: 2002);

  // Both clients start with shared data structures
  final client1Map = YMap();
  final client1Progress = GCounter();
  final client1Hours = PNCounter();
  
  client1.share('project', client1Map);
  client1Map.set('name', 'Mobile App Project');
  client1Map.set('progress', client1Progress);
  client1Map.set('hours', client1Hours);

  print('--- Initial State (Client 1) ---');
  print('Project name: ${client1Map.get('name')}');

  // Client 1 makes some progress
  client1Progress.increment(client1.clientID, 25); // 25% progress
  client1Hours.increment(client1.clientID, 8); // 8 hours logged
  
  print('Client 1 progress: ${client1Progress.value}%');
  print('Client 1 hours: ${client1Hours.value} hours');

  // Serialize Client 1's state
  print('\\n--- Serialization ---');
  final client1Json = client1.toJSON();
  print('Client 1 JSON size: ${jsonEncode(client1Json).length} bytes');

  // Try binary encoding
  final binaryData = BinaryEncoder.encodeDocument(client1);
  print('Client 1 binary size: ${binaryData.length} bytes');

  // Compare sizes
  final sizeComparison = BinaryEncoder.compareSizes(client1);
  print('Size comparison:');
  for (final entry in sizeComparison.entries) {
    print('  ${entry.key}: ${entry.value} bytes');
  }

  // Simulate Client 2 receiving Client 1's state
  print('\\n--- Client 2 Receives State ---');
  final client2FromJson = Doc.fromJSON(client1Json);
  final client2Map = client2FromJson.get<YMap>('project')!;
  final client2Progress = client2Map.get('progress') as GCounter;
  final client2Hours = client2Map.get('hours') as PNCounter;

  print('Client 2 received project: ${client2Map.get('name')}');
  print('Client 2 received progress: ${client2Progress.value}%');
  print('Client 2 received hours: ${client2Hours.value} hours');

  // Client 2 makes their own changes
  print('\\n--- Client 2 Makes Changes ---');
  client2Progress.increment(client2FromJson.clientID, 15); // 15% more progress
  client2Hours.increment(client2FromJson.clientID, 6); // 6 more hours
  client2Hours.decrement(client2FromJson.clientID, 1); // Correction: -1 hour

  print('Client 2 after changes:');
  print('  Progress: ${client2Progress.value}%'); // Should be 40%
  print('  Hours: ${client2Hours.value} hours'); // Should be 13 hours

  // Simulate synchronization back to Client 1
  print('\\n--- Synchronization Back to Client 1 ---');
  
  // Get Client 2's updates
  final client2Update = client2FromJson.getUpdateSince({});
  
  // Apply updates to Client 1
  client1.applyUpdate(client2Update);
  
  // Check Client 1's final state
  final finalProgress = client1Map.get('progress') as GCounter;
  final finalHours = client1Map.get('hours') as PNCounter;
  
  print('Final synchronized state:');
  print('  Progress: ${finalProgress.value}%');
  print('  Hours: ${finalHours.value} hours');

  // Demonstrate counter merging directly
  print('\\n--- Direct Counter Merging Example ---');
  
  // Create separate counters for each client
  final clientACounter = PNCounter();
  final clientBCounter = PNCounter();
  final clientCCounter = PNCounter();

  // Each client works independently
  clientACounter.increment(1001, 10); // Client A: +10
  clientACounter.decrement(1001, 2);  // Client A: -2 (net: +8)

  clientBCounter.increment(2002, 15); // Client B: +15
  clientBCounter.decrement(2002, 5);  // Client B: -5 (net: +10)

  clientCCounter.increment(3003, 20); // Client C: +20
  clientCCounter.decrement(3003, 8);  // Client C: -8 (net: +12)

  print('Before merge:');
  print('  Client A counter: ${clientACounter.value}');
  print('  Client B counter: ${clientBCounter.value}');
  print('  Client C counter: ${clientCCounter.value}');

  // Merge all counters (this is the CRDT magic!)
  final mergedCounter = clientACounter.copy();
  mergedCounter.merge(clientBCounter);
  mergedCounter.merge(clientCCounter);

  print('After merge:');
  print('  Combined counter: ${mergedCounter.value}'); // Should be 30 (8+10+12)

  // Show that merging is commutative
  final alternativeMerge = clientCCounter.copy();
  alternativeMerge.merge(clientACounter);
  alternativeMerge.merge(clientBCounter);

  print('  Alternative merge order: ${alternativeMerge.value}'); // Should also be 30

  // Demonstrate idempotent merging
  mergedCounter.merge(clientACounter); // Merge again
  print('  After redundant merge: ${mergedCounter.value}'); // Should still be 30

  print('\\n--- Bandwidth Analysis ---');
  
  // Create a more complex document for bandwidth testing
  final complexDoc = Doc(clientID: 9999);
  final complexMap = YMap();
  complexDoc.share('data', complexMap);

  // Add various data types
  complexMap.set('string_field', 'This is a long string with repeated data data data data data');
  complexMap.set('number_field', 42);
  complexMap.set('bool_field', true);
  
  final progressCounters = <String, GCounter>{};
  for (int i = 0; i < 10; i++) {
    final counter = GCounter();
    counter.increment(i, i * 10);
    progressCounters['progress_$i'] = counter;
    complexMap.set('progress_$i', counter);
  }

  final sizes = BinaryEncoder.compareSizes(complexDoc);
  print('Complex document sizes:');
  for (final entry in sizes.entries) {
    print('  ${entry.key}: ${entry.value} bytes');
  }
  
  final jsonSize = sizes['json']!;
  final binarySize = sizes['binary']!;
  final savings = ((jsonSize - binarySize) / jsonSize * 100).round();
  
  print('Binary vs JSON savings: $savings%');
}