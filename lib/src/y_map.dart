import 'structs.dart';
import 'content.dart';
import 'id.dart';

/// Y.Map - A collaborative Map CRDT implementation
/// 
/// Last-write-wins semantics for each key.
/// Supports nested CRDT types as values.
class YMap extends AbstractType {
  /// Create a new YMap
  YMap();

  /// Set a key-value pair
  void set<T>(String key, T value) {
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        _typeMapSet(transaction, key, value);
      });
    }
  }

  /// Get a value by key
  T? get<T>(String key) {
    return _typeMapGet(key) as T?;
  }

  /// Check if a key exists
  bool has(String key) {
    return _typeMapHas(key);
  }

  /// Delete a key
  void delete(String key) {
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        _typeMapDelete(transaction, key);
      });
    }
  }

  /// Get all keys
  Iterable<String> get keys {
    return super._map.keys.where((key) {
      final item = super._map[key];
      return item != null && !item.deleted;
    });
  }

  /// Get all values
  Iterable<dynamic> get values {
    return super._map.values
        .where((item) => !item.deleted)
        .map((item) => item.content.getContent().last);
  }

  /// Get all entries as key-value pairs
  Iterable<MapEntry<String, dynamic>> get entries {
    return super._map.entries
        .where((entry) => !entry.value.deleted)
        .map((entry) => MapEntry(
              entry.key,
              entry.value.content.getContent().last,
            ));
  }

  /// Clear all entries
  void clear() {
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        for (final key in List.from(keys)) {
          _typeMapDelete(transaction, key);
        }
      });
    }
  }

  /// Get the size (number of non-deleted entries)
  int get size {
    return super._map.values.where((item) => !item.deleted).length;
  }

  /// Convert to a regular Dart Map
  @override
  Map<String, dynamic> toJSON() {
    final result = <String, dynamic>{};
    for (final entry in entries) {
      final value = entry.value;
      if (value is AbstractType) {
        result[entry.key] = value.toJSON();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  // Internal helper methods

  void _typeMapSet(Transaction transaction, String key, dynamic value) {
    final left = super._map[key];
    final doc = transaction.doc;
    
    AbstractContent content;
    if (value == null ||
        value is num ||
        value is String ||
        value is bool ||
        value is List ||
        value is Map) {
      content = ContentAny([value]);
    } else if (value is AbstractType) {
      content = ContentType(value);
    } else {
      throw ArgumentError('Unsupported value type: ${value.runtimeType}');
    }

    final item = Item(
      createID(doc.clientID, doc.nextClock()),
      left,
      left?.lastId,
      null,
      null,
      this,
      key,
      content,
    );

    item.integrate(transaction, 0);
  }

  dynamic _typeMapGet(String key) {
    final item = super._map[key];
    if (item != null && !item.deleted) {
      return item.content.getContent().last;
    }
    return null;
  }

  bool _typeMapHas(String key) {
    final item = super._map[key];
    return item != null && !item.deleted;
  }

  void _typeMapDelete(Transaction transaction, String key) {
    final item = super._map[key];
    if (item != null) {
      item.delete(transaction);
    }
  }
}