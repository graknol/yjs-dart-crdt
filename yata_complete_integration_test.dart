// Complete YATA algorithm test with proper text integration and convergence validation
// This tests the full YATA implementation including document synchronization

import 'dart:math';

/// Mock ID structure
class ID {
  final int client;
  final int clock;
  
  ID(this.client, this.clock);
  
  @override
  String toString() => '$client:$clock';
  
  @override
  bool operator ==(other) => other is ID && client == other.client && clock == other.clock;
  
  @override
  int get hashCode => client.hashCode ^ clock.hashCode;
}

/// Create ID helper
ID createID(int client, int clock) => ID(client, clock);

/// Compare IDs
int compareIDs(ID? a, ID? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  
  if (a.client != b.client) return a.client.compareTo(b.client);
  return a.clock.compareTo(b.clock);
}

/// Content for text
class ContentString {
  final String str;
  ContentString(this.str);
  
  int getLength() => str.length;
  bool isCountable() => true;
  ContentString copy() => ContentString(str);
}

/// YATA Item with full integration
class YataItem {
  final ID id;
  YataItem? left;
  final ID? origin;  
  YataItem? right;
  final ID? rightOrigin;
  final YataText parent;
  final ContentString content;
  bool deleted = false;
  bool integrated = false;
  
  YataItem({
    required this.id,
    this.left,
    this.origin,
    this.right,
    this.rightOrigin,
    required this.parent,
    required this.content,
  });
  
  void markDeleted() => deleted = true;
  
  /// Full YATA integration with conflict resolution
  void integrate() {
    if (integrated) return;
    
    // Step 1: Find actual left/right from origins
    YataItem? actualLeft = origin != null ? parent._findItemById(origin!) : null;
    YataItem? actualRight = rightOrigin != null ? parent._findItemById(rightOrigin!) : null;
    
    // Step 2: Handle concurrent operations (YATA core algorithm)
    if (actualLeft != null && actualRight != null) {
      // Find concurrent items between left and right
      final conflicts = _findConflicts(actualLeft, actualRight);
      if (conflicts.isNotEmpty) {
        final position = _resolveYataConflict([this, ...conflicts]);
        actualLeft = position['left'];
        actualRight = position['right'];
      }
    }
    
    // Step 3: Insert at determined position
    left = actualLeft;
    right = actualRight;
    
    if (left != null) {
      left!.right = this;
    } else {
      parent._start = this;
    }
    
    if (right != null) {
      right!.left = this;
    }
    
    integrated = true;
    parent._length++;
  }
  
  /// Find concurrent operations between left and right
  List<YataItem> _findConflicts(YataItem left, YataItem right) {
    final conflicts = <YataItem>[];
    YataItem? current = left.right;
    
    while (current != null && current != right) {
      if (current.origin == origin && current.rightOrigin == rightOrigin) {
        conflicts.add(current);
      }
      current = current.right;
    }
    
    return conflicts;
  }
  
  /// YATA conflict resolution using deterministic ordering
  Map<String, YataItem?> _resolveYataConflict(List<YataItem> items) {
    // Sort by YATA rules: (clientId, clock) lexicographically
    items.sort((a, b) {
      if (a.id.client != b.id.client) {
        return a.id.client.compareTo(b.id.client);
      }
      return a.id.clock.compareTo(b.id.clock);
    });
    
    final myIndex = items.indexOf(this);
    
    YataItem? newLeft = origin != null ? parent._findItemById(origin!) : null;
    YataItem? newRight = rightOrigin != null ? parent._findItemById(rightOrigin!) : null;
    
    // Adjust based on ordering
    if (myIndex > 0) newLeft = items[myIndex - 1];
    if (myIndex < items.length - 1) newRight = items[myIndex + 1];
    
    return {'left': newLeft, 'right': newRight};
  }
}

/// Position tracking for insertions
class Position {
  YataItem? left;
  YataItem? right;
  int index;
  
  Position(this.left, this.right, this.index);
}

/// YATA-based YText implementation
class YataText {
  YataItem? _start;
  int _length = 0;
  final int clientId;
  int _clock = 0;
  
  YataText(this.clientId);
  
  /// Insert text with YATA algorithm
  void insert(int index, String text) {
    final pos = _findPosition(index);
    
    YataItem? lastInserted;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final itemId = createID(clientId, ++_clock);
      
      final item = YataItem(
        id: itemId,
        left: lastInserted ?? pos.left,
        origin: (lastInserted ?? pos.left)?.id,
        right: pos.right,
        rightOrigin: pos.right?.id,
        parent: this,
        content: ContentString(char),
      );
      
      item.integrate();
      lastInserted = item;
      
      // Update position for next character
      pos.left = item;
    }
  }
  
  /// Find position in document
  Position _findPosition(int targetIndex) {
    int currentIndex = 0;
    YataItem? current = _start;
    YataItem? prev;
    
    while (current != null && currentIndex < targetIndex) {
      if (!current.deleted) {
        currentIndex += current.content.getLength();
      }
      if (currentIndex <= targetIndex) {
        prev = current;
        current = current.right;
      } else {
        break;
      }
    }
    
    return Position(prev, current, currentIndex);
  }
  
  /// Find item by ID (essential for YATA)
  YataItem? _findItemById(ID id) {
    YataItem? current = _start;
    while (current != null) {
      if (current.id == id) return current;
      current = current.right;
    }
    return null;
  }
  
  /// Convert to string
  String toString() {
    final buffer = StringBuffer();
    YataItem? current = _start;
    
    while (current != null) {
      if (!current.deleted) {
        buffer.write(current.content.str);
      }
      current = current.right;
    }
    
    return buffer.toString();
  }
  
  /// Apply operations from another client (synchronization)
  void applyOperations(List<YataItem> operations) {
    operations.sort((a, b) => compareIDs(a.id, b.id));
    
    for (final op in operations) {
      if (_findItemById(op.id) == null) {
        // Create local copy and integrate
        final localItem = YataItem(
          id: op.id,
          origin: op.origin,
          rightOrigin: op.rightOrigin,
          parent: this,
          content: op.content,
        );
        localItem.integrate();
      }
    }
  }
  
  /// Get all operations for synchronization
  List<YataItem> getOperations() {
    final operations = <YataItem>[];
    YataItem? current = _start;
    
    while (current != null) {
      operations.add(current);
      current = current.right;
    }
    
    return operations;
  }
}

/// Complete YATA convergence test
void main() {
  print('🚀 Complete YATA Integration & Convergence Test');
  print('=' * 60);
  
  testYataConvergence();
  testConcurrentEditPrevention();
  testMultiClientScenario();
  testComplexInterleaving();
  
  print('\n🎉 All YATA integration tests passed!');
}

/// Test YATA convergence between two documents
void testYataConvergence() {
  print('\n🔸 Test 1: YATA Document Convergence');
  
  final doc1 = YataText(1);
  final doc2 = YataText(2);
  
  // Initial state
  doc1.insert(0, "Hello World");
  doc2.insert(0, "Hello World");
  
  print('   Initial: "${doc1.toString()}"');
  
  // Concurrent operations
  doc1.insert(6, "Beautiful ");  // Client 1 at position 6
  doc2.insert(6, "Amazing ");    // Client 2 at same position 6
  
  print('   After concurrent edits:');
  print('   Doc1: "${doc1.toString()}"');
  print('   Doc2: "${doc2.toString()}"');
  
  // Synchronize: apply doc1's operations to doc2 and vice versa
  final ops1 = doc1.getOperations();
  final ops2 = doc2.getOperations();
  
  doc1.applyOperations(ops2);
  doc2.applyOperations(ops1);
  
  print('   After synchronization:');
  print('   Doc1: "${doc1.toString()}"');
  print('   Doc2: "${doc2.toString()}"');
  
  assert(doc1.toString() == doc2.toString(), 'Documents did not converge!');
  print('   ✅ YATA convergence verified');
}

/// Test that YATA prevents character interleaving
void testConcurrentEditPrevention() {
  print('\n🔸 Test 2: Character Interleaving Prevention');
  
  final doc1 = YataText(1);
  final doc2 = YataText(2);
  
  // Start with "The cat"
  doc1.insert(0, "The cat");
  doc2.insert(0, "The cat");
  
  // Both insert at position 4 (between "The " and "cat")
  doc1.insert(4, "big ");
  doc2.insert(4, "black ");
  
  // Synchronize
  doc1.applyOperations(doc2.getOperations());
  doc2.applyOperations(doc1.getOperations());
  
  final result1 = doc1.toString();
  final result2 = doc2.toString();
  
  print('   Result1: "$result1"');
  print('   Result2: "$result2"');
  
  // Verify no character interleaving
  assert(result1 == result2, 'Documents did not converge');
  assert(!result1.contains('bbilgack') && !result1.contains('bilgack'), 'Character interleaving detected');
  
  // Should be either "The big black cat" or "The black big cat"
  assert(result1 == "The big black cat" || result1 == "The black big cat", 'Unexpected result');
  
  print('   ✅ No character interleaving - proper word boundaries maintained');
}

/// Test complex multi-client scenario
void testMultiClientScenario() {
  print('\n🔸 Test 3: Multi-Client Complex Scenario');
  
  final doc1 = YataText(1);
  final doc2 = YataText(2); 
  final doc3 = YataText(3);
  
  // Initial text
  const initial = "The quick fox jumps";
  doc1.insert(0, initial);
  doc2.insert(0, initial);
  doc3.insert(0, initial);
  
  // Concurrent operations
  doc1.insert(10, "brown ");        // "The quick brown fox jumps"
  doc2.insert(19, " over the lazy dog");  // "The quick fox jumps over the lazy dog"  
  doc3.insert(4, "very ");          // "The very quick fox jumps"
  
  print('   Individual results:');
  print('   Doc1: "${doc1.toString()}"');
  print('   Doc2: "${doc2.toString()}"');
  print('   Doc3: "${doc3.toString()}"');
  
  // Full synchronization
  final ops1 = doc1.getOperations();
  final ops2 = doc2.getOperations();
  final ops3 = doc3.getOperations();
  
  doc1.applyOperations(ops2);
  doc1.applyOperations(ops3);
  
  doc2.applyOperations(ops1);
  doc2.applyOperations(ops3);
  
  doc3.applyOperations(ops1);
  doc3.applyOperations(ops2);
  
  print('   After full synchronization:');
  print('   Doc1: "${doc1.toString()}"');
  print('   Doc2: "${doc2.toString()}"');
  print('   Doc3: "${doc3.toString()}"');
  
  final result1 = doc1.toString();
  final result2 = doc2.toString();
  final result3 = doc3.toString();
  
  assert(result1 == result2 && result2 == result3, 'All documents must converge');
  
  print('   ✅ Multi-client convergence achieved');
}

/// Test complex interleaving scenario
void testComplexInterleaving() {
  print('\n🔸 Test 4: Complex Interleaving Scenario');
  
  final doc1 = YataText(1);
  final doc2 = YataText(2);
  
  // Multiple rapid insertions at same position
  doc1.insert(0, "ABC");
  doc2.insert(0, "ABC");
  
  // Insert characters at position 1 (between A and BC)
  doc1.insert(1, "X");  
  doc1.insert(2, "Y");  
  doc2.insert(1, "P");  
  doc2.insert(2, "Q");  
  
  print('   Before sync:');
  print('   Doc1: "${doc1.toString()}"');  // Should be AXYBC
  print('   Doc2: "${doc2.toString()}"');  // Should be APQBC
  
  // Synchronize
  doc1.applyOperations(doc2.getOperations());
  doc2.applyOperations(doc1.getOperations());
  
  print('   After sync:');
  print('   Doc1: "${doc1.toString()}"');
  print('   Doc2: "${doc2.toString()}"');
  
  assert(doc1.toString() == doc2.toString(), 'Complex scenario must converge');
  
  print('   ✅ Complex interleaving handled correctly');
}