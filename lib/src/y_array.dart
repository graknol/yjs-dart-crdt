import 'structs.dart';
import 'content.dart';
import 'id.dart';

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
        _typeListInsert(transaction, index, items);
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
    delete(index, 1);
    insert(index, value);
  }

  /// Get an item at a specific index
  T? operator [](int index) => get(index);

  /// Convert to a regular Dart List
  List<T> toList() {
    final result = <T>[];
    Item? current = super._start;
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
    Item? current = super._start;
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
    Item? current = super._start;
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
    if (index > super._length) {
      throw RangeError('Index $index out of range (0-${super._length})');
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
    if (index >= super._length || deleteCount <= 0) return;

    Item? current = _findItemAtIndex(index);
    int remaining = deleteCount;
    
    while (current != null && remaining > 0) {
      if (!current.deleted && current.countable) {
        final itemLength = current.content.getLength();
        if (remaining >= itemLength) {
          // Delete entire item
          current.delete(transaction);
          remaining -= itemLength;
        } else {
          // Split and delete part of the item
          // This is simplified - full implementation would split the item
          current.delete(transaction);
          remaining = 0;
        }
      }
      current = current.right;
    }
  }

  dynamic _typeListGet(int index) {
    if (index >= super._length) return null;
    
    Item? current = super._start;
    int currentIndex = 0;
    
    while (current != null) {
      if (!current.deleted && current.countable) {
        final content = current.content.getContent();
        for (final item in content) {
          if (currentIndex == index) {
            return item;
          }
          currentIndex++;
        }
      }
      current = current.right;
    }
    
    return null;
  }

  Item? _findItemAtIndex(int index) {
    if (index < 0) return null;
    
    Item? current = super._start;
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