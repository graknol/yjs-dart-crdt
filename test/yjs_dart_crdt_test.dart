import 'package:test/test.dart';
import '../lib/yjs_dart_crdt.dart';

void main() {
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
}