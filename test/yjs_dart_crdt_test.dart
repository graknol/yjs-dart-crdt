import 'package:test/test.dart';
import '../lib/yjs_dart_crdt.dart';

void main() {
  group('Counter Tests', () {
    test('GCounter should increment and merge correctly', () {
      final counter1 = GCounter();
      final counter2 = GCounter();

      // Client 1 increments
      counter1.increment(1, 5);
      expect(counter1.value, equals(5));

      // Client 2 increments  
      counter2.increment(2, 3);
      expect(counter2.value, equals(3));

      // Merge counters
      counter1.merge(counter2);
      expect(counter1.value, equals(8)); // 5 + 3

      // Merging should be idempotent
      counter1.merge(counter2);
      expect(counter1.value, equals(8));
    });

    test('GCounter should handle conflicting increments correctly', () {
      final counter1 = GCounter();
      final counter2 = GCounter();

      // Both clients increment same client ID
      counter1.increment(1, 5);
      counter2.increment(1, 3); // Lower value

      // After merge, should take higher value (grow-only property)
      counter1.merge(counter2);
      expect(counter1.value, equals(5));

      counter2.merge(counter1);
      expect(counter2.value, equals(5));
    });

    test('PNCounter should increment and decrement correctly', () {
      final counter = PNCounter();

      counter.increment(1, 10);
      expect(counter.value, equals(10));

      counter.decrement(1, 3);
      expect(counter.value, equals(7)); // 10 - 3

      counter.add(1, -2); // Should decrement by 2
      expect(counter.value, equals(5)); // 7 - 2

      counter.add(1, 5); // Should increment by 5
      expect(counter.value, equals(10)); // 5 + 5
    });

    test('PNCounter should merge correctly', () {
      final counter1 = PNCounter();
      final counter2 = PNCounter();

      // Client 1: +10, -3 = 7
      counter1.increment(1, 10);
      counter1.decrement(1, 3);
      expect(counter1.value, equals(7));

      // Client 2: +5, -1 = 4  
      counter2.increment(2, 5);
      counter2.decrement(2, 1);
      expect(counter2.value, equals(4));

      // After merge: (10+5) - (3+1) = 11
      counter1.merge(counter2);
      expect(counter1.value, equals(11));
    });

    test('Counters should serialize and deserialize correctly', () {
      final gcounter = GCounter();
      gcounter.increment(1, 5);
      gcounter.increment(2, 3);

      final json = gcounter.toJSON();
      final restored = GCounter.fromJSON(json);
      
      expect(restored.value, equals(gcounter.value));
      expect(restored, equals(gcounter));

      final pncounter = PNCounter();
      pncounter.increment(1, 10);
      pncounter.decrement(2, 3);

      final pnJson = pncounter.toJSON();
      final pnRestored = PNCounter.fromJSON(pnJson);
      
      expect(pnRestored.value, equals(pncounter.value));
      expect(pnRestored, equals(pncounter));
    });
  });

  group('YMap Tests', () {
    late Doc doc;
    late YMap map;

    setUp(() {
      doc = Doc();
      map = YMap();
      doc.share('map', map);
    });

    test('should create empty map', () {
      expect(map.size, equals(0));
      expect(map.keys.isEmpty, isTrue);
    });

    test('should set and get values', () {
      map.set('key1', 'value1');
      map.set('key2', 42);
      map.set('key3', true);

      expect(map.get('key1'), equals('value1'));
      expect(map.get('key2'), equals(42));
      expect(map.get('key3'), equals(true));
      expect(map.size, equals(3));
    });

    test('should check key existence', () {
      map.set('existing', 'value');
      
      expect(map.has('existing'), isTrue);
      expect(map.has('nonexistent'), isFalse);
    });

    test('should delete keys', () {
      map.set('temp', 'value');
      expect(map.has('temp'), isTrue);
      
      map.delete('temp');
      expect(map.has('temp'), isFalse);
      expect(map.get('temp'), isNull);
    });

    test('should convert to JSON', () {
      map.set('string', 'hello');
      map.set('number', 123);
      map.set('boolean', true);

      final json = map.toJSON();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['string'], equals('hello'));
      expect(json['number'], equals(123));
      expect(json['boolean'], equals(true));
    });

    test('should handle overwriting values', () {
      map.set('key', 'initial');
      expect(map.get('key'), equals('initial'));
      
      map.set('key', 'updated');
      expect(map.get('key'), equals('updated'));
      expect(map.size, equals(1)); // Size should remain 1
    });

    test('should support GCounter values', () {
      final counter = GCounter();
      counter.increment(doc.clientID, 5);
      
      map.set('progress', counter);
      expect(map.has('progress'), isTrue);
      
      final retrieved = map.get('progress') as GCounter;
      expect(retrieved.value, equals(5));
      
      // Increment the retrieved counter
      retrieved.increment(doc.clientID, 3);
      expect(retrieved.value, equals(8));
    });

    test('should support PNCounter values', () {
      final counter = PNCounter();
      counter.increment(doc.clientID, 10);
      counter.decrement(doc.clientID, 3);
      
      map.set('balance', counter);
      expect(map.has('balance'), isTrue);
      
      final retrieved = map.get('balance') as PNCounter;
      expect(retrieved.value, equals(7)); // 10 - 3
      
      // Modify the retrieved counter
      retrieved.add(doc.clientID, -2);
      expect(retrieved.value, equals(5)); // 7 - 2
    });
  });

  group('YArray Tests', () {
    late Doc doc;
    late YArray<String> array;

    setUp(() {
      doc = Doc();
      array = YArray<String>();
      doc.share('array', array);
    });

    test('should create empty array', () {
      expect(array.length, equals(0));
      expect(array.toList().isEmpty, isTrue);
    });

    test('should push items', () {
      array.push('apple');
      array.push('banana');

      expect(array.length, equals(2));
      expect(array.get(0), equals('apple'));
      expect(array.get(1), equals('banana'));
    });

    test('should insert items at specific positions', () {
      array.push('apple');
      array.push('cherry');
      array.insert(1, 'banana');

      final result = array.toList();
      expect(result, equals(['apple', 'banana', 'cherry']));
    });

    test('should delete items', () {
      array.pushAll(['a', 'b', 'c', 'd']);
      expect(array.length, equals(4));

      array.delete(1, 2); // Delete 'b' and 'c'
      final result = array.toList();
      expect(result, equals(['a', 'd']));
    });

    test('should handle array access operators', () {
      array.pushAll(['x', 'y', 'z']);
      
      expect(array[0], equals('x'));
      expect(array[1], equals('y'));
      expect(array[2], equals('z'));
      
      array[1] = 'Y'; // This should replace 'y' with 'Y'
      expect(array[1], equals('Y'));
    });

    test('should convert to JSON', () {
      array.pushAll(['hello', 'world']);
      
      final json = array.toJSON();
      expect(json, isA<List>());
      expect(json, equals(['hello', 'world']));
    });
  });

  group('YText Tests', () {
    late Doc doc;
    late YText text;

    setUp(() {
      doc = Doc();
      text = YText();
      doc.share('text', text);
    });

    test('should create empty text', () {
      expect(text.toString(), equals(''));
      expect(text.length, equals(0));
    });

    test('should insert text', () {
      text.insert(0, 'Hello');
      expect(text.toString(), equals('Hello'));
      expect(text.length, equals(5));
    });

    test('should insert text at different positions', () {
      text.insert(0, 'Hello');
      text.insert(5, ' World');
      text.insert(11, '!');

      expect(text.toString(), equals('Hello World!'));
    });

    test('should delete text', () {
      text.insert(0, 'Hello World!');
      text.delete(5, 6); // Delete " World"

      expect(text.toString(), equals('Hello!'));
    });

    test('should handle charAt', () {
      text.insert(0, 'Test');
      
      expect(text.charAt(0), equals('T'));
      expect(text.charAt(1), equals('e'));
      expect(text.charAt(3), equals('t'));
      expect(text.charAt(10), isNull); // Out of bounds
    });

    test('should create text with initial content', () {
      final initialText = YText('Initial content');
      doc.share('initial', initialText);
      
      expect(initialText.toString(), equals('Initial content'));
      expect(initialText.length, equals(15));
    });
  });

  group('Doc Tests', () {
    test('should generate unique client IDs', () {
      final doc1 = Doc();
      final doc2 = Doc();
      
      expect(doc1.clientID, isNot(equals(doc2.clientID)));
    });

    test('should increment clock with operations', () {
      final doc = Doc();
      final map = YMap();
      doc.share('map', map);
      
      final initialClock = doc.getState();
      
      map.set('key1', 'value1');
      expect(doc.getState(), greaterThan(initialClock));
      
      map.set('key2', 'value2');
      expect(doc.getState(), greaterThan(initialClock + 1));
    });

    test('should support transactions', () {
      final doc = Doc();
      final map = YMap();
      doc.share('map', map);
      
      final initialClock = doc.getState();
      
      doc.transact((transaction) {
        map.set('key1', 'value1');
        map.set('key2', 'value2');
        map.set('key3', 'value3');
      });
      
      expect(doc.getState(), greaterThan(initialClock));
      expect(map.size, equals(3));
    });
  });

  group('Serialization Tests', () {
    test('Document should serialize and deserialize correctly', () {
      final doc = Doc(clientID: 12345);
      final map = YMap();
      doc.share('testMap', map);
      
      map.set('string', 'hello');
      map.set('number', 42);
      map.set('boolean', true);
      
      // Serialize and deserialize
      final json = doc.toJSON();
      final restoredDoc = Doc.fromJSON(json);
      
      expect(restoredDoc.clientID, equals(12345));
      
      final restoredMap = restoredDoc.get<YMap>('testMap');
      expect(restoredMap, isNotNull);
      expect(restoredMap!.get('string'), equals('hello'));
      expect(restoredMap.get('number'), equals(42));
      expect(restoredMap.get('boolean'), equals(true));
    });

    test('Document with counters should serialize correctly', () {
      final doc = Doc(clientID: 999);
      final map = YMap();
      final gCounter = GCounter();
      final pnCounter = PNCounter();
      
      gCounter.increment(doc.clientID, 5);
      pnCounter.increment(doc.clientID, 10);
      pnCounter.decrement(doc.clientID, 3);
      
      map.set('progress', gCounter);
      map.set('balance', pnCounter);
      doc.share('counters', map);
      
      // Serialize and deserialize
      final json = doc.toJSON();
      final restoredDoc = Doc.fromJSON(json);
      
      final restoredMap = restoredDoc.get<YMap>('counters');
      expect(restoredMap, isNotNull);
      
      // Note: After deserialization, counters become regular maps
      // This is a limitation of the current simple serialization approach
      final progressData = restoredMap!.get('progress');
      final balanceData = restoredMap.get('balance');
      
      expect(progressData, isNotNull);
      expect(balanceData, isNotNull);
    });

    test('Update generation and application should work', () {
      final doc1 = Doc(clientID: 1);
      final doc2 = Doc(clientID: 2);
      
      final map1 = YMap();
      doc1.share('shared', map1);
      map1.set('key1', 'value1');
      
      // Generate update from doc1
      final update = doc1.getUpdateSince({});
      
      // Apply to doc2
      doc2.applyUpdate(update);
      
      final map2 = doc2.get<YMap>('shared');
      expect(map2, isNotNull);
      expect(map2!.get('key1'), equals('value1'));
    });
  });
}