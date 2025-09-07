import 'package:test/test.dart';
import '../lib/yjs_dart_crdt.dart';

void main() {
  group('Delta Synchronization Tests', () {
    test('Should generate delta updates instead of full state', () {
      final doc1 = Doc(clientID:1);
      final doc2 = Doc(clientID:2);
      
      // Initial state in doc1
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('key1', 'value1');
      
      // Doc2 gets initial state
      final initialUpdate = doc1.getUpdateSince({});
      doc2.applyUpdate(initialUpdate);
      
      // Verify doc2 received the state
      final map2 = doc2.get<YMap>('shared');
      expect(map2, isNotNull);
      expect(map2!.get('key1'), equals('value1'));
      
      // Make a change in doc1
      map1.set('key2', 'value2');
      
      // Get delta update from doc1's perspective
      final doc2State = doc2.getVectorClock();
      final deltaUpdate = doc1.getUpdateSince(doc2State);
      
      // Should be a delta update, not full state
      expect(deltaUpdate['type'], equals('delta_update'));
      expect(deltaUpdate['operations'], isA<List>());
      expect((deltaUpdate['operations'] as List).isNotEmpty, isTrue);
    });

    test('Should handle incremental delta updates correctly', () {
      final doc1 = Doc(clientID:1);
      final doc2 = Doc(clientID:2);
      
      // Set up initial state
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('initial', 'value');
      
      // Sync to doc2
      var update = doc1.getUpdateSince({});
      doc2.applyUpdate(update);
      
      // Make multiple changes in doc1
      map1.set('key1', 'value1');
      map1.set('key2', 'value2');
      map1.set('key3', 'value3');
      
      // Get delta update
      final doc2State = doc2.getVectorClock();
      final deltaUpdate = doc1.getUpdateSince(doc2State);
      
      // Apply delta to doc2
      doc2.applyUpdate(deltaUpdate);
      
      // Verify all changes were applied
      final map2 = doc2.get<YMap>('shared');
      expect(map2, isNotNull);
      expect(map2!.get('initial'), equals('value'));
      expect(map2.get('key1'), equals('value1'));
      expect(map2.get('key2'), equals('value2'));
      expect(map2.get('key3'), equals('value3'));
    });

    test('Should not drop operations during synchronization', () {
      final doc1 = Doc(clientID: 1);
      final doc2 = Doc(clientID: 2);
      
      // Create initial shared state
      final map1 = YMap();
      doc1.share('shared', map1);
      
      // Simulate rapid changes
      for (int i = 0; i < 10; i++) {
        map1.set('key$i', 'value$i');
      }
      
      // Get all updates at once
      final update = doc1.getUpdateSince({});
      doc2.applyUpdate(update);
      
      // Verify no operations were dropped
      final map2 = doc2.get<YMap>('shared');
      expect(map2, isNotNull);
      
      for (int i = 0; i < 10; i++) {
        expect(map2!.get('key$i'), equals('value$i'),
            reason: 'Operation for key$i was dropped');
      }
    });

    test('Should support snapshot-based synchronization', () {
      final doc1 = Doc(clientID: 1);
      
      // Create initial state
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('initial', 'data');
      
      // Create snapshot
      final snapshot = doc1.createSnapshot();
      expect(snapshot['type'], equals('snapshot'));
      expect(snapshot['vector_clock'], isA<Map<int, int>>());
      
      // Make changes after snapshot
      map1.set('after_snapshot', 'new_data');
      
      // Get updates since snapshot
      final updateSinceSnapshot = doc1.getUpdateSinceSnapshot(snapshot);
      
      // Should contain only changes after snapshot
      expect(updateSinceSnapshot['type'], equals('delta_update'));
      
      // Apply to new document
      final doc2 = Doc(clientID: 2);
      
      // First apply snapshot state
      final snapshotState = snapshot['state'] as Map<String, dynamic>;
      final snapshotDoc = Doc.fromJSON(snapshotState);
      doc2.applyUpdate({
        'type': 'full_state',
        'state': snapshotState,
        'vector_clock': snapshot['vector_clock'],
      });
      
      // Then apply changes since snapshot
      doc2.applyUpdate(updateSinceSnapshot);
      
      // Verify both old and new data
      final map2 = doc2.get<YMap>('shared');
      expect(map2, isNotNull);
      expect(map2!.get('initial'), equals('data'));
      expect(map2.get('after_snapshot'), equals('new_data'));
    });

    test('Should handle clients coming back online efficiently', () {
      final doc1 = Doc(clientID: 1); // Always online
      final doc2 = Doc(clientID: 2); // Goes offline
      final doc3 = Doc(clientID: 3); // New client
      
      // Initial sync between doc1 and doc2
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('initial', 'value');
      
      var update = doc1.getUpdateSince({});
      doc2.applyUpdate(update);
      
      // Save doc2's state before going "offline"
      final doc2OfflineState = doc2.getVectorClock();
      
      // Changes happen while doc2 is offline
      map1.set('while_offline_1', 'change1');
      map1.set('while_offline_2', 'change2');
      
      // Doc3 joins and gets full sync
      update = doc1.getUpdateSince({});
      doc3.applyUpdate(update);
      
      // Doc2 comes back online and requests changes since it went offline
      final catchupUpdate = doc1.getUpdateSince(doc2OfflineState);
      doc2.applyUpdate(catchupUpdate);
      
      // All documents should be in sync
      final map2 = doc2.get<YMap>('shared');
      final map3 = doc3.get<YMap>('shared');
      
      expect(map2, isNotNull);
      expect(map3, isNotNull);
      
      // Check all have the same data
      expect(map1.get('initial'), equals('value'));
      expect(map2!.get('initial'), equals('value'));
      expect(map3!.get('initial'), equals('value'));
      
      expect(map1.get('while_offline_1'), equals('change1'));
      expect(map2.get('while_offline_1'), equals('change1'));
      expect(map3.get('while_offline_1'), equals('change1'));
      
      expect(map1.get('while_offline_2'), equals('change2'));
      expect(map2.get('while_offline_2'), equals('change2'));
      expect(map3.get('while_offline_2'), equals('change2'));
    });

    test('Should return no_changes when no updates are needed', () {
      final doc1 = Doc(clientID: 1);
      final doc2 = Doc(clientID: 2);
      
      // Set up identical state
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('key', 'value');
      
      var update = doc1.getUpdateSince({});
      doc2.applyUpdate(update);
      
      // No changes made, request update
      final doc2State = doc2.getVectorClock();
      final noChangeUpdate = doc1.getUpdateSince(doc2State);
      
      expect(noChangeUpdate['type'], equals('no_changes'));
    });

    test('Should handle vector clocks correctly', () {
      final doc1 = Doc(clientID: 1);
      final doc2 = Doc(clientID: 2);
      
      // Initial vector clocks should only contain own client
      var vc1 = doc1.getVectorClock();
      var vc2 = doc2.getVectorClock();
      
      expect(vc1[1], equals(0));
      expect(vc1.containsKey(2), isFalse);
      expect(vc2[2], equals(0));
      expect(vc2.containsKey(1), isFalse);
      
      // Make changes in doc1
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('key', 'value');
      
      vc1 = doc1.getVectorClock();
      expect(vc1[1], greaterThan(0));
      
      // Sync to doc2
      var update = doc1.getUpdateSince({});
      doc2.applyUpdate(update);
      
      // Doc2's vector clock should now know about doc1's changes
      vc2 = doc2.getVectorClock();
      expect(vc2.containsKey(1), isTrue);
      expect(vc2[1], equals(vc1[1]));
    });

    test('Should provide sync state information', () {
      final doc = Doc(clientID: 123);
      
      final map = YMap();
      doc.share('test_map', map);
      map.set('key', 'value');
      
      final syncState = doc.getSyncState();
      
      expect(syncState['clientID'], equals(123));
      expect(syncState['clock'], isA<int>());
      expect(syncState['vector_clock'], isA<Map<int, int>>());
      expect(syncState['operation_history_size'], isA<int>());
      expect(syncState['shared_types'], contains('test_map'));
    });

    test('Should detect changes correctly', () {
      final doc1 = Doc(clientID: 1);
      final doc2 = Doc(clientID: 2);
      
      // Set up initial sync
      final map1 = YMap();
      doc1.share('shared', map1);
      
      var update = doc1.getUpdateSince({});
      doc2.applyUpdate(update);
      
      final doc2State = doc2.getVectorClock();
      expect(doc1.hasChangesSince(doc2State), isFalse);
      
      // Make a change
      map1.set('new_key', 'new_value');
      expect(doc1.hasChangesSince(doc2State), isTrue);
      
      // Sync and check again
      update = doc1.getUpdateSince(doc2State);
      doc2.applyUpdate(update);
      
      final newDoc2State = doc2.getVectorClock();
      expect(doc1.hasChangesSince(newDoc2State), isFalse);
    });
  });
}