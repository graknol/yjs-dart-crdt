import '../lib/yjs_dart_crdt.dart';

void main() {
  print('=== Y.js Dart CRDT Example ===\n');

  // Create a new document
  final doc = Doc();
  print('Created document with client ID: ${doc.clientID}');

  // Example 1: YMap usage
  print('\n--- YMap Example ---');
  final map = YMap();
  doc.share('myMap', map);

  map.set('name', 'Alice');
  map.set('age', 30);
  map.set('active', true);

  print('Map size: ${map.size}');
  print('Name: ${map.get('name')}');
  print('Age: ${map.get('age')}');
  print('Has "email": ${map.has('email')}');
  print('Map as JSON: ${map.toJSON()}');

  // Example 2: YArray usage
  print('\n--- YArray Example ---');
  final array = YArray<String>();
  doc.share('myArray', array);

  array.push('apple');
  array.push('banana');
  array.insert(1, 'cherry');
  array.pushAll(['date', 'elderberry']);

  print('Array length: ${array.length}');
  print('Item at index 1: ${array.get(1)}');
  print('Array as list: ${array.toList()}');
  print('Array as JSON: ${array.toJSON()}');

  // Example 3: YText usage
  print('\n--- YText Example ---');
  final text = YText('Hello');
  doc.share('myText', text);

  text.insert(5, ' World');
  text.insert(11, '!');

  print('Text content: "${text.toString()}"');
  print('Text length: ${text.length}');
  print('Character at index 6: ${text.charAt(6)}');

  // Example 4: Nested CRDT types
  print('\n--- Nested Types Example ---');
  final nestedMap = YMap();
  final nestedArray = YArray<dynamic>();

  nestedArray.push('item1');
  nestedArray.push('item2');

  map.set('nested_array', nestedArray);
  map.set('nested_map', nestedMap);

  nestedMap.set('inner_key', 'inner_value');

  print('Nested structure: ${map.toJSON()}');

  // Example 5: Operations and state
  print('\n--- Operations Example ---');
  print('Document state (clock): ${doc.getState()}');

  // Perform more operations
  doc.transact((transaction) {
    map.set('batch1', 'value1');
    map.set('batch2', 'value2');
    array.push('batched_item');
  });

  print('After batched operations - Document state: ${doc.getState()}');
  print('Final map: ${map.toJSON()}');
  print('Final array: ${array.toJSON()}');
}
