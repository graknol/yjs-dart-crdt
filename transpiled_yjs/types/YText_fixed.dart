// YText implementation with proper YATA algorithm
// Based on Y.js YATA (Yet Another Transformation Approach)

import '../polyfill.dart' hide createID, compareIDs;
import '../structs/Item_fixed.dart';
import '../utils/ID.dart' show createID, compareIDs;

/// Content type for text operations  
class ContentString {
  final String str;
  ContentString(this.str);
  
  int getLength() => str.length;
  bool isCountable() => true;
  ContentString copy() => ContentString(str);
  ContentString splice(int offset) {
    return ContentString(str.substring(offset));
  }
}

/// Text position tracker for YATA operations
class ItemTextListPosition {
  dynamic left;
  dynamic right;
  int index;
  Map<String, dynamic> currentAttributes;
  
  ItemTextListPosition(this.left, this.right, this.index, this.currentAttributes);
  
  void forward() {
    if (right == null) return;
    
    // Move to next position
    final rightItem = right as Item;
    final length = rightItem.content.getLength();
    final lengthInt = (length is int) ? length : (length as double).toInt();
    index = index + lengthInt;
    left = right;
    right = rightItem.right;
  }
}

/// Core YText CRDT implementation
class YText {
  dynamic _start;
  int _length = 0;
  List<Function>? _pending;
  dynamic doc;
  dynamic _item;
  bool _hasFormatting = false;
  
  YText([String? initialText]) {
    _pending = initialText != null ? [() => insert(0, initialText)] : [];
  }
  
  int get length {
    if (doc == null) return 0;
    return _length;
  }
  
  void _integrate(dynamic y, dynamic item) {
    doc = y;
    _item = item;
    
    try {
      _pending?.forEach((f) => f());
    } catch (e) {
      print('YText integration error: $e');
    }
    _pending = null;
  }
  
  /// Insert text at given index using YATA algorithm
  void insert(int index, String text, [Map<String, dynamic>? attributes]) {
    if (text.isEmpty) return;
    
    if (doc != null) {
      _transact(() {
        final pos = _findPosition(index);
        _insertText(pos, text, attributes ?? {});
      });
    } else {
      _pending?.add(() => insert(index, text, attributes));
    }
  }
  
  /// Delete text at given index and length
  void delete(int index, int length) {
    if (length == 0) return;
    
    if (doc != null) {
      _transact(() {
        final pos = _findPosition(index);
        _deleteText(pos, length);
      });
    } else {
      _pending?.add(() => delete(index, length));
    }
  }
  
  /// Find position for insertion/deletion using YATA
  ItemTextListPosition _findPosition(int index) {
    final currentAttributes = <String, dynamic>{};
    ItemTextListPosition pos;
    
    // Start from beginning or use search markers for efficiency
    pos = ItemTextListPosition(null, _start, 0, currentAttributes);
    
    // Navigate to target position
    while (pos.right != null && pos.index < index) {
      final item = pos.right as Item;
      final itemLength = item.content.getLength();
      final itemLengthInt = (itemLength is int) ? itemLength : (itemLength as double).toInt();
      
      if (pos.index + itemLengthInt <= index) {
        // Move past this item entirely
        pos.index = pos.index + itemLengthInt;
        pos.left = pos.right;
        pos.right = item.right;
      } else {
        // Position is within this item - need to split
        break;
      }
    }
    
    return pos;
  }
  
  /// Insert text using YATA conflict resolution
  void _insertText(ItemTextListPosition pos, String text, Map<String, dynamic> attributes) {
    final clientId = _getClientId();
    final clock = _getNextClock();
    
    // Create content for each character (YATA requirement)
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final charId = createID(clientId, clock + i);
      
      // YATA: Find correct position considering concurrent operations
      final left = pos.left;
      final right = pos.right;
      
      // Create new Item with YATA origins
      final item = Item(
        id: charId,
        left: left,
        origin: left?.id, // Origin left for YATA
        right: right,
        rightOrigin: right?.id, // Origin right for YATA  
        parent: this,
        parentSub: null,
        content: ContentString(char),
      );
      
      // Integrate using YATA algorithm
      _integrateItem(item);
      
      // Update position for next character
      pos.left = item;
      pos.index++;
    }
  }
  
  /// Integrate Item using YATA conflict resolution
  void _integrateItem(Item item) {
    // YATA Step 1: Find integration position
    dynamic left = item.left;
    dynamic right = item.right;
    
    // YATA Step 2: Handle concurrent insertions at same position
    // Items with same origin need to be ordered consistently
    if (left != null && right != null) {
      // Check for concurrent operations between left and right
      final conflicts = _findConflicts(left, right, item);
      if (conflicts.isNotEmpty) {
        // Resolve using YATA ordering (client ID + clock)
        final insertPos = _resolveYataConflict(conflicts, item);
        left = insertPos.left;
        right = insertPos.right;
      }
    }
    
    // YATA Step 3: Insert at resolved position
    item.left = left;
    item.right = right;
    
    if (left != null) {
      left.right = item;
    } else {
      _start = item;
    }
    
    if (right != null) {
      right.left = item;
    }
    
    _length++;
  }
  
  /// Find conflicting concurrent operations
  List<dynamic> _findConflicts(dynamic left, dynamic right, Item newItem) {
    final conflicts = <dynamic>[];
    dynamic current = left?.right;
    
    while (current != null && current != right) {
      // Check if this is a concurrent operation (same origin)
      if (current.origin == newItem.origin && current.rightOrigin == newItem.rightOrigin) {
        conflicts.add(current);
      }
      current = current.right;
    }
    
    return conflicts;
  }
  
  /// Resolve YATA conflict using deterministic ordering
  dynamic _resolveYataConflict(List<dynamic> conflicts, Item newItem) {
    // YATA ordering: sort by (clientId, clock) lexicographically
    final sortedItems = [newItem, ...conflicts];
    sortedItems.sort((a, b) {
      final aId = a.id;
      final bId = b.id;
      
      // Compare client IDs first
      if (aId.client != bId.client) {
        return aId.client.compareTo(bId.client);
      }
      
      // Then compare clocks
      return aId.clock.compareTo(bId.clock);
    });
    
    // Find position for newItem in sorted order
    final newIndex = sortedItems.indexOf(newItem);
    
    dynamic left = newItem.origin != null ? _findItemById(newItem.origin) : null;
    dynamic right = newItem.rightOrigin != null ? _findItemById(newItem.rightOrigin) : null;
    
    // Adjust position based on YATA ordering
    for (int i = 0; i < newIndex; i++) {
      left = sortedItems[i];
    }
    
    if (newIndex < sortedItems.length - 1) {
      right = sortedItems[newIndex + 1];
    }
    
    return {'left': left, 'right': right};
  }
  
  /// Delete text at position
  void _deleteText(ItemTextListPosition pos, int length) {
    int remaining = length;
    
    while (remaining > 0 && pos.right != null) {
      final item = pos.right as Item;
      final itemLength = item.content.getLength();
      final itemLengthInt = (itemLength is int) ? itemLength : (itemLength as double).toInt();
      
      if (itemLengthInt <= remaining) {
        // Delete entire item
        item.markDeleted();
        remaining = remaining - itemLengthInt;
        _length = _length - itemLengthInt;
        pos.forward();
      } else {
        // Partial delete - split item
        final splitItem = _splitItem(item, remaining);
        splitItem.markDeleted();
        remaining = 0;
        _length -= remaining;
      }
    }
  }
  
  /// Split item at given offset (for partial operations)
  dynamic _splitItem(Item item, int offset) {
    final content = item.content as ContentString;
    final leftContent = ContentString(content.str.substring(0, offset));
    final rightContent = ContentString(content.str.substring(offset));
    
    // Create new item for right part
    final clientId = _getClientId();
    final clock = _getNextClock();
    final rightItem = Item(
      id: createID(clientId, clock),
      left: item,
      origin: item.id,
      right: item.right,
      rightOrigin: item.right?.id,
      parent: this,
      parentSub: null,
      content: rightContent,
    );
    
    // Update original item
    item.content = leftContent;
    item.right = rightItem;
    
    if (rightItem.right != null) {
      rightItem.right.left = rightItem;
    }
    
    return rightItem;
  }
  
  /// Convert to string representation
  String toString() {
    final buffer = StringBuffer();
    dynamic current = _start;
    
    while (current != null) {
      if (!current.deleted && current.content is ContentString) {
        buffer.write((current.content as ContentString).str);
      }
      current = current.right;
    }
    
    return buffer.toString();
  }
  
  /// Helper methods
  void _transact(Function operation) {
    // Simplified transaction - in real Y.js this is more complex
    operation();
  }
  
  int _getClientId() => doc?.clientID ?? 0;
  int _getNextClock() => getNextClock(doc?.store, _getClientId());
  
  dynamic _findItemById(dynamic id) {
    // Search through document for item with given ID
    dynamic current = _start;
    while (current != null) {
      if (compareIDs(current.id, id) == 0) {
        return current;
      }
      current = current.right;
    }
    return null;
  }
}

/// Item class for YATA algorithm
class Item {
  final dynamic id;
  dynamic left;
  final dynamic origin;  // YATA: original left reference
  dynamic right;
  final dynamic rightOrigin; // YATA: original right reference
  final dynamic parent;
  final dynamic parentSub;
  dynamic content;
  bool deleted = false;
  
  Item({
    required this.id,
    this.left,
    this.origin,
    this.right,
    this.rightOrigin,
    this.parent,
    this.parentSub,
    required this.content,
  });
  
  void markDeleted() {
    deleted = true;
  }
}