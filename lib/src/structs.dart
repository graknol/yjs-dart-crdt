import 'id.dart';
import 'content.dart';

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
      final newId = createID(id.client, id.clock + offset);
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

  static int _generateClientID() {
    // Generate a random 32-bit client ID
    return DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF;
  }

  /// Get the current clock value
  int getState() => _clock;

  /// Increment and return the next clock value
  int nextClock() => ++_clock;

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