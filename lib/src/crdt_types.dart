import 'id.dart';
import 'content.dart';
import 'counters.dart';

/// Abstract base class for all structs (Items and GC)
abstract class AbstractStruct {
  final ID id;
  int length;

  AbstractStruct(this.id, this.length);

  /// Integration method to be overridden by subclasses
  void integrate(Transaction transaction, int offset);

  /// Whether this struct is deleted
  bool get deleted;
}

/// Represents a single operation/change in the CRDT
class Item extends AbstractStruct {
  /// The item that was originally to the left of this item
  ID? origin;

  /// The item that is currently to the left of this item
  Item? left;

  /// The item that is currently to the right of this item
  Item? right;

  /// The item that was originally to the right of this item
  ID? rightOrigin;

  /// Parent type (YMap, YArray, or YText)
  dynamic parent;

  /// Key for parent map (null for array/text items)
  String? parentSub;

  /// The actual content of this item
  AbstractContent content;

  /// Info bits for keeping track of state
  int _info;

  Item(
    ID id,
    this.left,
    this.origin,
    this.right,
    this.rightOrigin,
    this.parent,
    this.parentSub,
    this.content,
  ) : _info = content.isCountable() ? _BIT_COUNTABLE : 0,
      super(id, content.getLength());

  static const int _BIT_KEEP = 1;
  static const int _BIT_COUNTABLE = 2;
  static const int _BIT_DELETED = 4;

  /// Whether this item should be kept (not garbage collected)
  bool get keep => (_info & _BIT_KEEP) > 0;
  set keep(bool value) {
    if (keep != value) {
      _info ^= _BIT_KEEP;
    }
  }

  /// Whether this item is countable (affects parent length)
  bool get countable => (_info & _BIT_COUNTABLE) > 0;

  /// Whether this item is deleted
  @override
  bool get deleted => (_info & _BIT_DELETED) > 0;
  set deleted(bool value) {
    if (deleted != value) {
      _info ^= _BIT_DELETED;
    }
  }

  /// Mark this item as deleted
  void markDeleted() {
    _info |= _BIT_DELETED;
  }

  /// Get the last ID covered by this item
  ID get lastId {
    return length == 1 ? id : createID(id.client, id.clock + length - 1);
  }

  /// Delete this item
  void delete(Transaction transaction) {
    if (!deleted) {
      final parentType = parent;
      if (countable && parentSub == null && parentType != null) {
        parentType._length -= length;
      }
      markDeleted();
      // Add to transaction's delete set
      transaction._addToDeleteSet(id.client, id.clock, length);
    }
  }

  /// Try to merge this item with the right item
  bool mergeWith(Item right) {
    return this.runtimeType == right.runtimeType &&
        compareIDs(right.origin, lastId) &&
        this.right == right &&
        compareIDs(rightOrigin, right.rightOrigin) &&
        id.client == right.id.client &&
        id.clock + length == right.id.clock &&
        deleted == right.deleted &&
        content.runtimeType == right.content.runtimeType &&
        content.mergeWith(right.content);
  }

  @override
  void integrate(Transaction transaction, int offset) {
    // Simplified integration - in full Y.js this is much more complex
    // with conflict resolution using the YATA algorithm
    
    if (offset > 0) {
      // Split the item if needed
      content = content.splice(offset);
      length -= offset;
    }

    if (parent != null) {
      // Add to parent
      if (parentSub != null) {
        // Map item - delete previous value if it exists
        final existing = parent._map[parentSub];
        if (existing != null && !existing.deleted) {
          existing.delete(transaction);
        }
        parent._map[parentSub] = this;
      } else {
        // Array/text item - insert based on left/right pointers
        if (left != null) {
          right = left!.right;
          left!.right = this;
          if (right != null) {
            right!.left = this;
          }
        } else {
          // Insert at start
          right = parent._start;
          parent._start = this;
          if (right != null) {
            right!.left = this;
          }
        }
      }

      // Update parent length
      if (countable && parentSub == null && !deleted) {
        parent._length += length;
      }
    }
  }
}

/// Transaction manages atomic updates to CRDT types
class Transaction {
  final Doc doc;
  final bool local;
  final Map<int, int> _deleteSet = {};

  Transaction(this.doc, {this.local = true});

  void _addToDeleteSet(int client, int clock, int len) {
    // Simplified - in full Y.js this uses a more complex structure
    _deleteSet[client] = (_deleteSet[client] ?? 0) + len;
  }
}

/// Document that contains CRDT types
class Doc {
  final int clientID;
  final Map<String, dynamic> _share = {};
  int _clock = 0;

  Doc({int? clientID}) : clientID = clientID ?? _generateClientID();

  /// Get a copy of the shared types (for serialization)
  Map<String, dynamic> get sharedTypes => Map.from(_share);

  static int _generateClientID() {
    // Generate a random 32-bit client ID
    return DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF;
  }

  /// Get the current clock value
  int getState() => _clock;

  /// Increment and return the next clock value
  int nextClock() => ++_clock;

  /// Set the clock value (used during deserialization)
  void setClock(int clock) => _clock = clock;

  /// Get a shared type by key
  T? get<T>(String key) => _share[key] as T?;

  /// Set a shared type by key
  void share<T>(String key, T type) {
    _share[key] = type;
    if (type is AbstractType) {
      type._integrate(this);
    }
  }

  /// Execute a transaction
  void transact(void Function(Transaction) fn, {bool local = true}) {
    final transaction = Transaction(this, local: local);
    fn(transaction);
  }

  /// Serialize the entire document state to JSON
  Map<String, dynamic> toJSON() {
    final result = <String, dynamic>{
      'clientID': clientID,
      'clock': _clock,
      'shared': <String, dynamic>{},
    };

    for (final entry in _share.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is AbstractType) {
        result['shared'][key] = {
          'type': value.runtimeType.toString(),
          'data': value.toJSON(),
        };
      } else {
        result['shared'][key] = {
          'type': 'primitive',
          'data': value,
        };
      }
    }

    return result;
  }

  /// Create a document from serialized JSON state
  static Doc fromJSON(Map<String, dynamic> json) {
    final clientID = json['clientID'] as int?;
    final clock = json['clock'] as int? ?? 0;
    
    final doc = Doc(clientID: clientID);
    doc.setClock(clock);
    
    final shared = json['shared'] as Map<String, dynamic>? ?? {};
    
    for (final entry in shared.entries) {
      final key = entry.key;
      final itemData = entry.value as Map<String, dynamic>;
      final type = itemData['type'] as String;
      final data = itemData['data'];
      
      switch (type) {
        case 'YMap':
          final ymap = YMap();
          doc.share(key, ymap);
          // Restore YMap data - simplified for now
          if (data is Map<String, dynamic>) {
            for (final mapEntry in data.entries) {
              ymap.set(mapEntry.key, mapEntry.value);
            }
          }
          break;
        case 'YArray':
          final yarray = YArray<dynamic>();
          doc.share(key, yarray);
          // Restore YArray data - simplified for now
          if (data is List) {
            for (final item in data) {
              yarray.push(item);
            }
          }
          break;
        case 'YText':
          final ytext = YText();
          doc.share(key, ytext);
          // Restore YText data - simplified for now
          if (data is String) {
            ytext.insert(0, data);
          }
          break;
        default:
          // For primitive types or unknown types
          doc._share[key] = data;
      }
    }
    
    return doc;
  }

  /// Get an update/delta representing all changes since a given state
  /// This is a simplified version - full Yjs has more complex update encoding
  Map<String, dynamic> getUpdateSince(Map<int, int> remoteState) {
    // Simplified: return full state for now
    // In full implementation, this would compute minimal delta
    return {
      'type': 'full_state',
      'state': toJSON(),
      'vector_clock': {clientID.toString(): _clock},
    };
  }

  /// Apply an update/delta to this document
  void applyUpdate(Map<String, dynamic> update) {
    final updateType = update['type'] as String;
    
    if (updateType == 'full_state') {
      final state = update['state'] as Map<String, dynamic>;
      final otherDoc = Doc.fromJSON(state);
      
      // Merge the other document's state into this one
      // This is a simplified merge - full implementation would be more complex
      for (final entry in otherDoc._share.entries) {
        final key = entry.key;
        final value = entry.value;
        
        if (!_share.containsKey(key)) {
          share(key, value);
        } else {
          // For now, just replace - full implementation would merge
          share(key, value);
        }
      }
      
      // Update clock to maximum
      _clock = (_clock > otherDoc._clock) ? _clock : otherDoc._clock;
    }
  }
}

/// Base class for all CRDT types
abstract class AbstractType {
  /// The document this type belongs to
  Doc? doc;

  /// Internal map for key-value storage (used by YMap)
  final Map<String, Item> _map = {};

  /// Start of the linked list (used by YArray and YText)
  Item? _start;

  /// Current length of the type
  int _length = 0;

  /// Get the current length
  int get length => _length;

  /// Integrate this type into a document
  void _integrate(Doc doc) {
    this.doc = doc;
  }

  /// Convert to JSON representation
  dynamic toJSON();
}

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
    return _map.keys.where((key) {
      final item = _map[key];
      return item != null && !item.deleted;
    });
  }

  /// Get all values
  Iterable<dynamic> get values {
    return _map.values
        .where((item) => !item.deleted)
        .map((item) => item.content.getContent().last);
  }

  /// Get all entries as key-value pairs
  Iterable<MapEntry<String, dynamic>> get entries {
    return _map.entries
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
    return _map.values.where((item) => !item.deleted).length;
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
    final left = _map[key];
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
    } else if (value.runtimeType.toString() == 'GCounter' || 
               value.runtimeType.toString() == 'PNCounter') {
      content = ContentCounter(value);
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
    final item = _map[key];
    if (item != null && !item.deleted) {
      return item.content.getContent().last;
    }
    return null;
  }

  bool _typeMapHas(String key) {
    final item = _map[key];
    return item != null && !item.deleted;
  }

  void _typeMapDelete(Transaction transaction, String key) {
    final item = _map[key];
    if (item != null) {
      item.delete(transaction);
    }
  }
}

/// Y.Array - A collaborative Array CRDT implementation
/// 
/// Maintains insertion order with support for concurrent modifications.
/// Uses a doubly-linked list internally for efficient insertions.
class YArray<T> extends AbstractType {
  /// Create a new YArray
  YArray();

  /// Create a YArray from an existing list
  static YArray<T> from<T>(List<T> items) {
    final array = YArray<T>();
    if (items.isNotEmpty) {
      array.insertAll(0, items);
    }
    return array;
  }

  /// Insert an item at the specified index
  void insert(int index, T item) {
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        _typeListInsert(transaction, index, [item]);
      });
    }
  }

  /// Insert multiple items at the specified index
  void insertAll(int index, List<T> items) {
    if (items.isEmpty) return;
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        // Insert items one by one to maintain proper CRDT structure
        for (int i = 0; i < items.length; i++) {
          _typeListInsert(transaction, index + i, [items[i]]);
        }
      });
    }
  }

  /// Add an item to the end of the array
  void push(T item) {
    insert(length, item);
  }

  /// Add multiple items to the end of the array
  void pushAll(List<T> items) {
    insertAll(length, items);
  }

  /// Remove items starting at index
  void delete(int index, [int deleteCount = 1]) {
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        _typeListDelete(transaction, index, deleteCount);
      });
    }
  }

  /// Get an item by index
  T? get(int index) {
    return _typeListGet(index) as T?;
  }

  /// Set an item at a specific index (replaces existing)
  void operator []=(int index, T value) {
    if (index < length) {
      delete(index, 1);
      insert(index, value);
    } else {
      // If index is out of bounds, just insert at the end
      insert(length, value);
    }
  }

  /// Get an item at a specific index
  T? operator [](int index) => get(index);

  /// Convert to a regular Dart List
  List<T> toList() {
    final result = <T>[];
    Item? current = _start;
    while (current != null) {
      if (!current.deleted && current.countable) {
        final content = current.content.getContent();
        for (final item in content) {
          if (item is T) {
            result.add(item);
          }
        }
      }
      current = current.right;
    }
    return result;
  }

  @override
  List<dynamic> toJSON() {
    final result = <dynamic>[];
    Item? current = _start;
    while (current != null) {
      if (!current.deleted && current.countable) {
        final content = current.content.getContent();
        for (final item in content) {
          if (item is AbstractType) {
            result.add(item.toJSON());
          } else {
            result.add(item);
          }
        }
      }
      current = current.right;
    }
    return result;
  }

  /// Iterate over all items
  void forEach(void Function(T item, int index) callback) {
    int index = 0;
    Item? current = _start;
    while (current != null) {
      if (!current.deleted && current.countable) {
        final content = current.content.getContent();
        for (final item in content) {
          if (item is T) {
            callback(item, index++);
          }
        }
      }
      current = current.right;
    }
  }

  /// Map over all items
  List<R> map<R>(R Function(T item, int index) callback) {
    final result = <R>[];
    forEach((item, index) {
      result.add(callback(item, index));
    });
    return result;
  }

  // Internal helper methods

  void _typeListInsert(Transaction transaction, int index, List<dynamic> content) {
    if (index > _length) {
      throw RangeError('Index $index out of range (0-$_length)');
    }

    Item? left = _findItemAtIndex(index - 1);
    Item? right = left?.right;

    // Create content
    final contentObj = ContentAny(content);
    
    final item = Item(
      createID(transaction.doc.clientID, transaction.doc.nextClock()),
      left,
      left?.lastId,
      right,
      right?.id,
      this,
      null,
      contentObj,
    );

    item.integrate(transaction, 0);
  }

  void _typeListDelete(Transaction transaction, int index, int deleteCount) {
    if (index < 0 || deleteCount <= 0) return;

    int deletedCount = 0;
    int currentIndex = 0;
    Item? current = _start;
    
    while (current != null && deletedCount < deleteCount) {
      if (!current.deleted && current.countable) {
        final content = current.content.getContent();
        final itemLength = content.length;
        
        // Check if this item overlaps with deletion range
        if (currentIndex < index + deleteCount && currentIndex + itemLength > index) {
          // This item should be deleted (or part of it)
          current.delete(transaction);
          deletedCount += itemLength;
        }
        currentIndex += itemLength;
      }
      current = current.right;
    }
  }

  dynamic _typeListGet(int index) {
    if (index < 0) return null;
    
    Item? current = _start;
    int currentIndex = 0;
    
    while (current != null) {
      if (!current.deleted && current.countable) {
        final content = current.content.getContent();
        final itemLength = content.length;
        
        if (currentIndex + itemLength > index) {
          // Found the item containing this index
          final localIndex = index - currentIndex;
          return content[localIndex];
        }
        currentIndex += itemLength;
      }
      current = current.right;
    }
    
    return null;
  }

  Item? _findItemAtIndex(int index) {
    if (index < 0) return null;
    
    Item? current = _start;
    int currentIndex = 0;
    
    while (current != null && currentIndex <= index) {
      if (!current.deleted && current.countable) {
        final itemLength = current.content.getLength();
        if (currentIndex + itemLength > index) {
          return current;
        }
        currentIndex += itemLength;
      }
      current = current.right;
    }
    
    return null;
  }
}

/// Y.Text - A collaborative text CRDT implementation
/// 
/// Supports concurrent text editing with character-level operations.
/// This is a simplified version without rich text formatting.
class YText extends AbstractType {
  final List<void Function()> _pendingInserts = [];

  /// Create a new YText
  YText([String? initialText]) {
    if (initialText != null && initialText.isNotEmpty) {
      _pendingInserts.add(() => insert(0, initialText));
    }
  }

  @override
  void _integrate(Doc doc) {
    super._integrate(doc);
    // Execute any pending operations
    for (final op in _pendingInserts) {
      op();
    }
    _pendingInserts.clear();
  }

  /// Insert text at the specified position
  void insert(int index, String text) {
    if (text.isEmpty) return;
    
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        _insertText(transaction, index, text);
      });
    } else {
      // Queue the operation for when the text is integrated
      _pendingInserts.add(() => insert(index, text));
    }
  }

  /// Delete characters starting at index
  void delete(int index, int deleteCount) {
    if (deleteCount <= 0) return;
    
    final doc = this.doc;
    if (doc != null) {
      doc.transact((transaction) {
        _deleteText(transaction, index, deleteCount);
      });
    }
  }

  /// Get the current text content
  @override
  String toString() {
    final buffer = StringBuffer();
    Item? current = _start;
    
    while (current != null) {
      if (!current.deleted && current.countable && current.content is ContentString) {
        final content = current.content as ContentString;
        buffer.write(content.str);
      }
      current = current.right;
    }
    
    return buffer.toString();
  }

  @override
  String toJSON() => toString();

  /// Get a substring
  String substring(int start, [int? end]) {
    final fullText = toString();
    return fullText.substring(start, end);
  }

  /// Get character at index
  String? charAt(int index) {
    final text = toString();
    if (index >= 0 && index < text.length) {
      return text[index];
    }
    return null;
  }

  /// Get the length of the text
  @override
  int get length {
    return toString().length;
  }

  // Internal helper methods

  void _insertText(Transaction transaction, int index, String text) {
    if (index > length) {
      throw RangeError('Index $index out of range (0-$length)');
    }

    // Find position to insert
    final position = _findPosition(index);
    
    final content = ContentString(text);
    final item = Item(
      createID(transaction.doc.clientID, transaction.doc.nextClock()),
      position.left,
      position.left?.lastId,
      position.right,
      position.right?.id,
      this,
      null,
      content,
    );

    item.integrate(transaction, 0);
  }

  void _deleteText(Transaction transaction, int index, int deleteCount) {
    if (index >= length || deleteCount <= 0) return;

    final endIndex = (index + deleteCount).clamp(0, length);
    int currentIndex = 0;
    Item? current = _start;
    
    while (current != null && currentIndex < endIndex) {
      if (!current.deleted && current.countable && current.content is ContentString) {
        final content = current.content as ContentString;
        final itemStart = currentIndex;
        final itemEnd = currentIndex + content.str.length;
        
        if (itemStart < endIndex && itemEnd > index) {
          // This item overlaps with the deletion range
          final deleteStart = (index - itemStart).clamp(0, content.str.length);
          final deleteEnd = (endIndex - itemStart).clamp(0, content.str.length);
          
          if (deleteStart == 0 && deleteEnd >= content.str.length) {
            // Delete entire item
            current.delete(transaction);
          } else {
            // Partial deletion - simplified approach
            // In a full implementation, this would split the item
            final newText = content.str.substring(0, deleteStart) +
                           content.str.substring(deleteEnd);
            content.str = newText;
          }
        }
        
        currentIndex = itemEnd;
      }
      current = current.right;
    }
  }

  /// Find the position (left, right items) for inserting at index
  _TextPosition _findPosition(int index) {
    if (index == 0) {
      return _TextPosition(null, _start);
    }
    
    int currentIndex = 0;
    Item? current = _start;
    
    while (current != null) {
      if (!current.deleted && current.countable && current.content is ContentString) {
        final content = current.content as ContentString;
        final nextIndex = currentIndex + content.str.length;
        
        if (nextIndex >= index) {
          // Insert within or at the end of this item
          if (nextIndex == index) {
            // Insert at the end of this item
            return _TextPosition(current, current.right);
          } else {
            // Insert within this item - would need to split in full implementation
            return _TextPosition(current, current.right);
          }
        }
        
        currentIndex = nextIndex;
      }
      current = current.right;
    }
    
    // Insert at the end
    Item? lastItem = _start;
    while (lastItem?.right != null) {
      lastItem = lastItem?.right;
    }
    return _TextPosition(lastItem, null);
  }
}

/// Helper class to represent a position in the text
class _TextPosition {
  final Item? left;
  final Item? right;

  _TextPosition(this.left, this.right);
}