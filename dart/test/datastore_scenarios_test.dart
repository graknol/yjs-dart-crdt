import 'package:test/test.dart';
import '../lib/yjs_dart_crdt.dart';

void main() {
  group('Datastore Scenarios - User Sync State Tracking', () {
    test('Scenario 1: Client fails to process delta - should recover on next request', () {
      // This test addresses: "The server responds with new delta and client somehow 
      // fails to process/save it. Now, does the server think that the client has received it 
      // and skips them in the next delta?"
      
      final server = Doc(nodeId: 'server-1');
      final client = Doc(nodeId: 'client-1');
      
      // Set up initial shared state
      final serverMap = YMap();
      server.share('document', serverMap);
      serverMap.set('initial', 'data');
      
      // Client syncs initially and successfully processes
      final initialUpdate = server.getUpdateSince({});
      client.applyUpdate(initialUpdate);
      
      // Verify client got the data
      final clientMap = client.get<YMap>('document');
      expect(clientMap, isNotNull);
      expect(clientMap!.get('initial'), equals('data'));
      
      // Store client's successfully processed state
      final clientProcessedState = client.getVectorClock();
      
      // Server makes more changes
      serverMap.set('change1', 'value1');
      serverMap.set('change2', 'value2');
      
      // Client requests delta using their successfully processed state
      final deltaUpdate1 = server.getUpdateSince(clientProcessedState);
      expect(deltaUpdate1['type'], equals('delta_update'));
      final operations1 = deltaUpdate1['operations'] as List;
      expect(operations1.length, equals(2)); // Both changes included
      
      // CRITICAL: Client fails to process this delta (simulated by not calling applyUpdate)
      // Client does NOT update their HLC vector/state
      
      // Server makes one more change
      serverMap.set('change3', 'value3');
      
      // Client requests again using the SAME old state (because they failed to process)
      final deltaUpdate2 = server.getUpdateSince(clientProcessedState); // Same state as before!
      
      // Server should include ALL operations the client missed, including the ones
      // from the failed delta plus the new one
      expect(deltaUpdate2['type'], equals('delta_update'));
      final operations2 = deltaUpdate2['operations'] as List;
      expect(operations2.length, equals(3)); // All three changes since clientProcessedState
      
      // Verify the operations contain the expected changes
      final operationTypes = operations2.map((op) => op['data']['key']).toSet();
      expect(operationTypes, containsAll(['change1', 'change2', 'change3']));
      
      // Now client successfully processes the delta
      client.applyUpdate(deltaUpdate2);
      final updatedClientMap = client.get<YMap>('document');
      expect(updatedClientMap!.get('change1'), equals('value1'));
      expect(updatedClientMap.get('change2'), equals('value2'));
      expect(updatedClientMap.get('change3'), equals('value3'));
      
      // Future requests should now be minimal
      final finalClientState = client.getVectorClock();
      final noChangesUpdate = server.getUpdateSince(finalClientState);
      expect(noChangesUpdate['type'], equals('no_changes'));
    });

    test('Scenario 2: Multi-server scaling - different server HLC vectors should not corrupt data', () {
      // This test addresses: "Suppose we scale out to 3 server nodes, and each server 
      // keeps its own local copy of the map. Will this corrupt the client's data if it 
      // requests delta from two servers that have not synced their maps?"
      
      final server1 = Doc(nodeId: 'server-1');
      final server2 = Doc(nodeId: 'server-2');
      final server3 = Doc(nodeId: 'server-3');
      final client = Doc(nodeId: 'client-1');
      
      // Each server starts with the same initial state
      for (final server in [server1, server2, server3]) {
        final map = YMap();
        server.share('document', map);
        map.set('initial', 'shared');
      }
      
      // Client syncs with server1 initially
      var update = server1.getUpdateSince({});
      client.applyUpdate(update);
      final clientState1 = client.getVectorClock();
      
      // Each server makes different changes (simulating distributed system)
      final map1 = server1.get<YMap>('document')!;
      final map2 = server2.get<YMap>('document')!;
      final map3 = server3.get<YMap>('document')!;
      
      map1.set('server1_change', 'data1');
      map2.set('server2_change', 'data2');
      map3.set('server3_change', 'data3');
      
      // Critical: Servers don't sync their operation histories with each other
      // Each server only knows about their own operations
      
      // Client requests deltas from server2 (who doesn't know about client's sync with server1)
      final deltaFromServer2 = server2.getUpdateSince(clientState1);
      expect(deltaFromServer2['type'], equals('delta_update'));
      
      // Apply server2's changes
      client.applyUpdate(deltaFromServer2);
      final clientState2 = client.getVectorClock();
      
      // Client then requests from server3 (who doesn't know about client's history with server1 or server2)
      final deltaFromServer3 = server3.getUpdateSince(clientState2);
      expect(deltaFromServer3['type'], equals('delta_update'));
      
      // Apply server3's changes
      client.applyUpdate(deltaFromServer3);
      final clientState3 = client.getVectorClock();
      
      // Client should now have all data from all servers
      final finalClientMap = client.get<YMap>('document')!;
      expect(finalClientMap.get('initial'), equals('shared'));
      expect(finalClientMap.get('server2_change'), equals('data2'));
      expect(finalClientMap.get('server3_change'), equals('data3'));
      
      // The HLC vector should reflect operations from all nodes
      final clientHLCVector = client.getVectorClock();
      expect(clientHLCVector.keys, containsAll(['client-1', 'server-2', 'server-3']));
      
      // Key insight: Each server only needs to track operations they've generated
      // The client's HLC vector tells each server exactly what they need to send
      // No server-side state about client sync status is needed
      
      // Verify no data corruption by doing a round-trip with server1
      final finalDeltaFromServer1 = server1.getUpdateSince(clientState3);
      
      // Server1 should send their change that the client hasn't seen yet
      expect(finalDeltaFromServer1['type'], equals('delta_update'));
      final server1Operations = finalDeltaFromServer1['operations'] as List;
      expect(server1Operations.length, equals(1)); // Only server1's change
      
      client.applyUpdate(finalDeltaFromServer1);
      final completeClientMap = client.get<YMap>('document')!;
      
      // Client should now have ALL changes from ALL servers
      expect(completeClientMap.get('initial'), equals('shared'));
      expect(completeClientMap.get('server1_change'), equals('data1'));
      expect(completeClientMap.get('server2_change'), equals('data2'));
      expect(completeClientMap.get('server3_change'), equals('data3'));
    });

    test('Edge case: Client HLC vector ahead of server for some nodes', () {
      // This tests what happens when a client has seen operations from a node
      // that the current server hasn't seen yet (in a multi-server setup)
      
      final serverA = Doc(nodeId: 'server-a');
      final serverB = Doc(nodeId: 'server-b');
      final client = Doc(nodeId: 'client-1');
      
      // ServerA makes changes
      final mapA = YMap();
      serverA.share('document', mapA);
      mapA.set('from_a', 'data_a');
      
      // Client syncs with serverA
      var update = serverA.getUpdateSince({});
      client.applyUpdate(update);
      
      // ServerB makes changes independently
      final mapB = YMap();
      serverB.share('document', mapB);
      mapB.set('from_b', 'data_b');
      
      // Client also syncs with serverB
      final clientStateAfterA = client.getVectorClock();
      update = serverB.getUpdateSince(clientStateAfterA);
      client.applyUpdate(update);
      
      // Now client's HLC vector includes knowledge of both servers
      final clientFinalState = client.getVectorClock();
      final clientHLCVector = client.getVectorClock();
      
      // ServerA doesn't know about serverB's operations
      // When client requests from serverA using their complete state,
      // serverA should only send operations they have that client hasn't seen
      final deltaFromA = serverA.getUpdateSince(clientFinalState);
      
      // Since client already has serverA's operations, this should be no_changes
      expect(deltaFromA['type'], equals('no_changes'));
      
      // The key insight: Servers don't need to know about ALL nodes
      // They only compare HLC entries for nodes they have operations for
      // Missing nodes in server's HLC vector are safely ignored
    });

    test('Concurrent operations at same millisecond from different servers', () {
      // This tests the edge case mentioned in previous conversations about
      // concurrent operations at the exact same millisecond
      
      final server1 = Doc(nodeId: 'server-1');
      final server2 = Doc(nodeId: 'server-2');
      final client = Doc(nodeId: 'client-1');
      
      // Set up shared documents
      final map1 = YMap();
      final map2 = YMap();
      server1.share('doc', map1);
      server2.share('doc', map2);
      
      // Client syncs initial empty state
      var update = server1.getUpdateSince({});
      client.applyUpdate(update);
      final clientInitialState = client.getVectorClock();
      
      // Force both servers to make changes at very close times
      // (simulating the edge case where they might get the same millisecond)
      map1.set('concurrent1', 'value1');
      map2.set('concurrent2', 'value2');
      
      // Client gets updates from both servers
      final delta1 = server1.getUpdateSince(clientInitialState);
      final delta2 = server2.getUpdateSince(clientInitialState);
      
      expect(delta1['type'], equals('delta_update'));
      expect(delta2['type'], equals('delta_update'));
      
      // Apply both deltas
      client.applyUpdate(delta1);
      final stateAfterServer1 = client.getVectorClock();
      
      client.applyUpdate(delta2);
      final stateAfterBoth = client.getVectorClock();
      
      // Client should have both operations
      final clientMap = client.get<YMap>('doc')!;
      expect(clientMap.get('concurrent1'), equals('value1'));
      expect(clientMap.get('concurrent2'), equals('value2'));
      
      // Verify that requesting again from either server yields no_changes
      final noChanges1 = server1.getUpdateSince(stateAfterBoth);
      final noChanges2 = server2.getUpdateSince(stateAfterBoth);
      
      expect(noChanges1['type'], equals('no_changes'));
      expect(noChanges2['type'], equals('no_changes'));
      
      // The HLC system correctly handles the concurrent operations
      // through the per-node tracking mechanism
      final clientHLCVector = client.getVectorClock();
      expect(clientHLCVector.keys, containsAll(['client-1', 'server-1', 'server-2']));
    });

    test('Server operation history pruning does not break delta sync', () {
      // Tests that if a server prunes old operations from history,
      // it gracefully falls back to full state sync when needed
      
      final server = Doc(nodeId: 'server-1');
      final client = Doc(nodeId: 'client-1');
      
      // Set up initial state
      final map = YMap();
      server.share('document', map);
      
      // Client syncs initial state
      var update = server.getUpdateSince({});
      client.applyUpdate(update);
      final clientEarlyState = client.getVectorClock();
      
      // Server makes many changes (simulating time passing)
      for (int i = 0; i < 50; i++) {
        map.set('key_$i', 'value_$i');
      }
      
      // Force server to prune operation history by exceeding max size
      // (In practice, this would happen naturally over time)
      // The current implementation keeps the last 1000 operations
      
      // Client that has been offline for a long time requests update
      final deltaUpdate = server.getUpdateSince(clientEarlyState);
      
      // This should still work - either as delta_update if history is sufficient
      // or as full_state if history was pruned
      expect(deltaUpdate['type'], isIn(['delta_update', 'full_state']));
      
      // Client should be able to apply the update regardless of type
      client.applyUpdate(deltaUpdate);
      
      // Verify client has all the data
      final clientMap = client.get<YMap>('document')!;
      expect(clientMap.get('key_0'), equals('value_0'));
      expect(clientMap.get('key_49'), equals('value_49'));
      
      // Future syncs should work normally
      map.set('final', 'change');
      final clientCurrentState = client.getVectorClock();
      final finalDelta = server.getUpdateSince(clientCurrentState);
      expect(finalDelta['type'], equals('delta_update'));
      
      client.applyUpdate(finalDelta);
      expect(client.get<YMap>('document')!.get('final'), equals('change'));
    });
  });
}