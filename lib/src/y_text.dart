import 'structs.dart';
import 'content.dart';
import 'id.dart';

/// Y.Text - A collaborative text CRDT implementation
/// 
/// Supports concurrent text editing with character-level operations.
/// This is a simplified version without rich text formatting.
class YText extends AbstractType {
  /// Create a new YText
  YText([String? initialText]) {
    if (initialText != null && initialText.isNotEmpty) {
      _pendingInserts.add(() => insert(0, initialText));
    }
  }

  final List<void Function()> _pendingInserts = [];

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
    Item? current = super._start;
    
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
    Item? current = super._start;
    
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
      return _TextPosition(null, super._start);
    }
    
    int currentIndex = 0;
    Item? current = super._start;
    
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
    Item? lastItem = super._start;
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