import 'package:test/test.dart';
import '../lib/yjs_dart_crdt.dart';

void main() {
  group('Hybrid Logical Clock Tests', () {
    test('Should create HLC with current time and node ID', () {
      final nodeId = 'test-node-1';
      final hlc = HLC.now(nodeId);
      
      expect(hlc.nodeId, equals(nodeId));
      expect(hlc.logicalCounter, equals(0));
      expect(hlc.physicalTime, greaterThan(0));
    });

    test('Should increment HLC properly', () {
      final hlc1 = HLC.now('node-1');
      final hlc2 = hlc1.increment();
      
      expect(hlc2.nodeId, equals(hlc1.nodeId));
      expect(hlc2.physicalTime, greaterThanOrEqualTo(hlc1.physicalTime));
      
      if (hlc2.physicalTime == hlc1.physicalTime) {
        expect(hlc2.logicalCounter, equals(hlc1.logicalCounter + 1));
      } else {
        expect(hlc2.logicalCounter, equals(0));
      }
    });

    test('Should handle HLC event reception correctly', () {
      final hlc1 = HLC(physicalTime: 1000, logicalCounter: 5, nodeId: 'node-1');
      final hlc2 = HLC(physicalTime: 1000, logicalCounter: 3, nodeId: 'node-2');
      
      final result = hlc1.receiveEvent(hlc2);
      
      expect(result.nodeId, equals('node-1'));
      expect(result.physicalTime, greaterThanOrEqualTo(1000));
      expect(result.logicalCounter, equals(6)); // max(5,3) + 1
    });

    test('Should compare HLCs correctly', () {
      final hlc1 = HLC(physicalTime: 1000, logicalCounter: 5, nodeId: 'node-1');
      final hlc2 = HLC(physicalTime: 1001, logicalCounter: 3, nodeId: 'node-2');
      final hlc3 = HLC(physicalTime: 1000, logicalCounter: 6, nodeId: 'node-3');
      
      expect(hlc1.happensBefore(hlc2), isTrue);
      expect(hlc2.happensAfter(hlc1), isTrue);
      expect(hlc1.happensBefore(hlc3), isTrue);
      expect(hlc3.happensAfter(hlc1), isTrue);
    });

    test('Should generate GUID v4 node IDs', () {
      final guid1 = generateGuidV4();
      final guid2 = generateGuidV4();
      
      expect(guid1, isNot(equals(guid2)));
      expect(guid1.length, equals(36)); // Standard GUID format
      expect(guid1, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('Should serialize and deserialize HLC correctly', () {
      final original = HLC(physicalTime: 1234567890, logicalCounter: 42, nodeId: 'test-node');
      final json = original.toJson();
      final restored = HLC.fromJson(json);
      
      expect(restored, equals(original));
      expect(restored.physicalTime, equals(original.physicalTime));
      expect(restored.logicalCounter, equals(original.logicalCounter));
      expect(restored.nodeId, equals(original.nodeId));
    });
  });

  group('Doc with HLC Integration Tests', () {
    test('Should use HLC-based node IDs', () {
      final doc1 = Doc();
      final doc2 = Doc(nodeId: 'custom-service-id');
      final doc3 = Doc(clientID: 123); // Legacy support
      
      expect(doc1.nodeId, isNotNull);
      expect(doc1.nodeId.length, equals(36)); // GUID format
      expect(doc2.nodeId, equals('custom-service-id'));
      expect(doc3.nodeId, equals('legacy-123'));
      expect(doc3.clientID, equals(123));
    });

    test('Should track HLC state in operations', () {
      final doc1 = Doc(nodeId: 'server-1');
      final doc2 = Doc(nodeId: 'client-1');
      
      // Create shared state
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('key1', 'value1');
      
      // Get initial sync state
      final syncState = doc1.getSyncState();
      expect(syncState['nodeId'], equals('server-1'));
      expect(syncState['hlc'], isA<Map<String, dynamic>>());
      expect(syncState['hlc_vector'], isA<Map<String, dynamic>>());
      
      // Sync to client
      final update = doc1.getUpdateSince({});
      expect(update['nodeId'], equals('server-1'));
      expect(update.containsKey('hlc_vector'), isTrue);
      
      doc2.applyUpdate(update);
      
      // Verify client received HLC state
      final clientSyncState = doc2.getSyncState();
      expect(clientSyncState['hlc_vector'], isA<Map<String, dynamic>>());
      
      final map2 = doc2.get<YMap>('shared');
      expect(map2, isNotNull);
      expect(map2!.get('key1'), equals('value1'));
    });

    test('Should maintain backward compatibility with legacy vector clocks', () {
      final doc1 = Doc(clientID: 1); // Legacy constructor
      final doc2 = Doc(clientID: 2); // Legacy constructor
      
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('test', 'value');
      
      // Should still work with legacy getVectorClock
      final vectorClock = doc1.getVectorClock();
      expect(vectorClock, isA<Map<int, int>>());
      expect(vectorClock[1], greaterThan(0));
      
      // Should work with legacy update format
      final update = doc1.getUpdateSince({});
      expect(update.containsKey('vector_clock'), isTrue);
      
      doc2.applyUpdate(update);
      
      final map2 = doc2.get<YMap>('shared');
      expect(map2, isNotNull);
      expect(map2!.get('test'), equals('value'));
    });

    test('Should handle concurrent updates with HLC ordering', () {
      final server = Doc(nodeId: 'server');
      final client1 = Doc(nodeId: 'client-1');
      final client2 = Doc(nodeId: 'client-2');
      
      // Setup shared document
      final serverMap = YMap();
      server.share('doc', serverMap);
      
      // Both clients get initial state
      final initialUpdate = server.getUpdateSince({});
      client1.applyUpdate(initialUpdate);
      client2.applyUpdate(initialUpdate);
      
      // Concurrent modifications
      final map1 = client1.get<YMap>('doc')!;
      final map2 = client2.get<YMap>('doc')!;
      
      map1.set('key1', 'from-client-1');
      map2.set('key2', 'from-client-2');
      
      // Sync to server with HLC ordering
      final update1 = client1.getUpdateSince(server.getVectorClock());
      final update2 = client2.getUpdateSince(server.getVectorClock());
      
      server.applyUpdate(update1);
      server.applyUpdate(update2);
      
      // Verify both updates were applied
      expect(serverMap.get('key1'), equals('from-client-1'));
      expect(serverMap.get('key2'), equals('from-client-2'));
      
      // Verify HLC vectors track all nodes
      final serverSyncState = server.getSyncState();
      final hlcVector = serverSyncState['hlc_vector'] as Map<String, dynamic>;
      expect(hlcVector.containsKey('server'), isTrue);
      expect(hlcVector.containsKey('client-1'), isTrue);
      expect(hlcVector.containsKey('client-2'), isTrue);
    });

    test('Should not miss operations when clients sync concurrent changes at same millisecond', () {
      final server = Doc(nodeId: 'server');
      final clientA = Doc(nodeId: 'client-a');  // Lexicographically first
      final clientB = Doc(nodeId: 'client-b');  // Lexicographically second
      
      // Initial sync - all clients have same starting state
      final serverMap = YMap();
      server.share('doc', serverMap);
      
      final initialUpdate = server.getUpdateSince({});
      clientA.applyUpdate(initialUpdate);
      clientB.applyUpdate(initialUpdate);
      
      // Clients go "offline" - save their current state
      final clientAOfflineState = clientA.getVectorClock();
      final clientBOfflineState = clientB.getVectorClock();
      
      // Both clients make concurrent changes while "offline"
      final mapA = clientA.get<YMap>('doc')!;
      final mapB = clientB.get<YMap>('doc')!;
      
      mapA.set('keyA', 'valueA');
      mapB.set('keyB', 'valueB');
      
      // Both clients sync their changes to server
      final updateA = clientA.getUpdateSince(server.getVectorClock());
      final updateB = clientB.getUpdateSince(server.getVectorClock());
      
      server.applyUpdate(updateA);
      server.applyUpdate(updateB);
      
      // Critical test: when clients request deltas, they should get each other's operations
      // Client A requests delta (should get Client B's operation)
      final deltaForA = server.getUpdateSince(clientAOfflineState);
      expect(deltaForA['type'], equals('delta_update'));
      
      final operationsForA = deltaForA['operations'] as List;
      expect(operationsForA.length, greaterThan(0));
      
      // Client B requests delta (should get Client A's operation)
      final deltaForB = server.getUpdateSince(clientBOfflineState);
      expect(deltaForB['type'], equals('delta_update'));
      
      final operationsForB = deltaForB['operations'] as List;
      expect(operationsForB.length, greaterThan(0));
      
      // Apply the deltas
      clientA.applyUpdate(deltaForB);  // Client A gets Client B's changes
      clientB.applyUpdate(deltaForA);  // Client B gets Client A's changes
      
      // Verify both clients now have both operations (no missing operations)
      final finalMapA = clientA.get<YMap>('doc')!;
      final finalMapB = clientB.get<YMap>('doc')!;
      
      expect(finalMapA.get('keyA'), equals('valueA'));  // Client A keeps their own change
      expect(finalMapA.get('keyB'), equals('valueB'));  // Client A receives Client B's change
      expect(finalMapB.get('keyA'), equals('valueA'));  // Client B receives Client A's change
      expect(finalMapB.get('keyB'), equals('valueB'));  // Client B keeps their own change
      
      // Final verification: all three documents should be identical
      expect(serverMap.get('keyA'), equals('valueA'));
      expect(serverMap.get('keyB'), equals('valueB'));
    });
  });
}