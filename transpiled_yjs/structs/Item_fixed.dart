// Core Item implementation for YATA algorithm
// Based on Y.js Item structure with proper YATA fields

import '../polyfill.dart' hide createID, compareIDs;
import '../utils/ID.dart' show createID, compareIDs;

/// Abstract base for all CRDT structures
abstract class AbstractStruct {
  final dynamic id;
  final int length;
  bool deleted = false;
  
  AbstractStruct(this.id, this.length);
  
  void markDeleted() {
    deleted = true;
  }
}

/// Abstract base for content types
abstract class AbstractContent {
  int getLength();
  bool isCountable();
  AbstractContent copy();
  AbstractContent? splice(int offset);
  List<dynamic> getContent();
}

/// String content implementation
class ContentString extends AbstractContent {
  final String str;
  
  ContentString(this.str);
  
  @override
  int getLength() => str.length;
  
  @override
  bool isCountable() => true;
  
  @override
  ContentString copy() => ContentString(str);
  
  @override
  ContentString? splice(int offset) {
    if (offset >= str.length) return null;
    return ContentString(str.substring(offset));
  }
  
  @override
  List<dynamic> getContent() => [str];
}

/// Core Item implementation with YATA fields
class Item extends AbstractStruct {
  // YATA-specific fields for conflict resolution
  dynamic left;          // Current left neighbor
  final dynamic origin;  // Original left neighbor (YATA)
  dynamic right;         // Current right neighbor  
  final dynamic rightOrigin; // Original right neighbor (YATA)
  
  // Parent and content
  final dynamic parent;
  final dynamic parentSub;
  AbstractContent content;
  
  // YATA integration fields
  bool integrated = false;
  dynamic redone;
  
  Item({
    required dynamic id,
    this.left,
    this.origin,
    this.right,
    this.rightOrigin,
    required this.parent,
    this.parentSub,
    required this.content,
  }) : super(id, content.getLength());
  
  /// Get the last ID in this item's range
  dynamic get lastId {
    if (id == null) return null;
    return createID(id.client, id.clock + length - 1);
  }
  
  /// Check if this item is countable (affects parent length)
  bool get countable {
    return content.isCountable() && !deleted;
  }
  
  /// Integrate this item using YATA algorithm
  void integrate(dynamic transaction, int offset) {
    if (integrated) return;
    
    // YATA Step 1: Find correct position
    final integrationResult = _performYataIntegration(transaction, offset);
    
    // YATA Step 2: Update links
    left = integrationResult['left'];
    right = integrationResult['right'];
    
    // YATA Step 3: Insert into structure
    if (left != null) {
      left.right = this;
    } else {
      // This is the new start
      if (parent._start == right) {
        parent._start = this;
      }
    }
    
    if (right != null) {
      right.left = this;
    }
    
    integrated = true;
    
    // Update parent length if countable
    if (countable) {
      parent._length = (parent._length ?? 0) + length;
    }
    
    // Update YText start pointer if this is the first item
    if (parent is YText && (parent._start == null || parent._start == right)) {
      parent._start = this;
    }
  }
  
  /// Perform YATA conflict resolution
  Map<String, dynamic> _performYataIntegration(dynamic transaction, int offset) {
    dynamic left = this.left;
    dynamic right = this.right;
    
    // Find the actual items from origins
    if (origin != null) {
      left = _findItemByOrigin(origin, transaction);
    }
    
    if (rightOrigin != null) {
      right = _findItemByOrigin(rightOrigin, transaction);
    }
    
    // YATA: Handle concurrent insertions
    if (left != null && right != null) {
      // Scan for concurrent operations between left and right
      final conflicts = _findConcurrentOperations(left, right);
      
      if (conflicts.isNotEmpty) {
        // Resolve using YATA ordering
        final position = _resolveYataConflict(conflicts);
        left = position['left'];
        right = position['right'];
      }
    }
    
    return {'left': left, 'right': right};
  }
  
  /// Find concurrent operations that need YATA resolution
  List<Item> _findConcurrentOperations(dynamic left, dynamic right) {
    final conflicts = <Item>[];
    dynamic current = left.right;
    
    while (current != null && current != right) {
      // Check if this operation has the same origins (concurrent)
      if (current.origin != null && current.rightOrigin != null &&
          compareIDs(current.origin, origin) == 0 &&
          compareIDs(current.rightOrigin, rightOrigin) == 0) {
        conflicts.add(current);
      }
      current = current.right;
    }
    
    return conflicts;
  }
  
  /// Resolve YATA conflict using deterministic ordering
  Map<String, dynamic> _resolveYataConflict(List<Item> conflicts) {
    // Add this item to conflicts for sorting
    final allItems = [this, ...conflicts];
    
    // YATA ordering: sort by (clientId, clock) lexicographically
    allItems.sort((a, b) {
      final aId = a.id;
      final bId = b.id;
      
      // First compare client IDs
      if (aId.client != bId.client) {
        return aId.client.compareTo(bId.client);
      }
      
      // Then compare clocks
      return aId.clock.compareTo(bId.clock);
    });
    
    // Find where this item should be positioned
    final myIndex = allItems.indexOf(this);
    
    dynamic newLeft = origin != null ? _findItemByOrigin(origin, null) : null;
    dynamic newRight = rightOrigin != null ? _findItemByOrigin(rightOrigin, null) : null;
    
    // Adjust position based on YATA ordering
    if (myIndex > 0) {
      newLeft = allItems[myIndex - 1];
    }
    
    if (myIndex < allItems.length - 1) {
      newRight = allItems[myIndex + 1];
    }
    
    return {'left': newLeft, 'right': newRight};
  }
  
  /// Find item by origin ID (simplified lookup)
  dynamic _findItemByOrigin(dynamic originId, dynamic transaction) {
    if (originId == null) return null;
    
    // Use polyfill function for now
    return createPlaceholderItem(originId);
  }
  
  /// Remove this item (mark as deleted)
  void remove(dynamic transaction) {
    if (deleted) return;
    
    markDeleted();
    
    // Update parent length
    if (countable) {
      parent._length = (parent._length ?? 0) - length;
    }
    
    // Add to transaction's delete set
    transaction?.deleteSet?.add(this);
  }
  
  /// Split this item at given offset
  Item? splice(int offset) {
    if (offset <= 0 || offset >= length) return null;
    
    // Split content
    final rightContent = content.splice(offset);
    if (rightContent == null) return null;
    
    // Create right item
    final rightId = createID(id.client, id.clock + offset);
    final rightItem = Item(
      id: rightId,
      left: this,
      origin: id,
      right: right,
      rightOrigin: right?.id,
      parent: parent,
      parentSub: parentSub,
      content: rightContent,
    );
    
    // Update this item
    content = content..splice(offset); // Truncate original content
    right = rightItem;
    
    // Update right neighbor
    if (rightItem.right != null) {
      rightItem.right.left = rightItem;
    }
    
    return rightItem;
  }
  
  @override
  String toString() {
    return 'Item(id: $id, content: ${content.getContent()}, deleted: $deleted)';
  }
}