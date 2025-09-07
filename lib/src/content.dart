
import 'counters.dart';

/// Abstract base class for all content types in CRDT operations
abstract class AbstractContent {
  /// Get the length of this content
  int getLength();

  /// Get the actual content as a list
  List<dynamic> getContent();

  /// Whether this content should be counted for length calculations
  bool isCountable();

  /// Create a copy of this content
  AbstractContent copy();

  /// Split this content at the given offset
  AbstractContent splice(int offset);

  /// Try to merge with another content of the same type
  bool mergeWith(AbstractContent right);

  /// Get a reference number for encoding
  int getRef();
}

/// Content that holds arbitrary JSON-serializable values
class ContentAny extends AbstractContent {
  final List<dynamic> content;

  ContentAny(this.content);

  @override
  int getLength() => content.length;

  @override
  List<dynamic> getContent() => content;

  @override
  bool isCountable() => true;

  @override
  AbstractContent copy() => ContentAny(List.from(content));

  @override
  AbstractContent splice(int offset) {
    final right = ContentAny(content.sublist(offset));
    content.removeRange(offset, content.length);
    return right;
  }

  @override
  bool mergeWith(AbstractContent right) {
    if (right is ContentAny) {
      content.addAll(right.content);
      return true;
    }
    return false;
  }

  @override
  int getRef() => 8; // Reference number for ContentAny
}

/// Content that holds string data
class ContentString extends AbstractContent {
  String str;

  ContentString(this.str);

  @override
  int getLength() => str.length;

  @override
  List<dynamic> getContent() => [str];

  @override
  bool isCountable() => true;

  @override
  AbstractContent copy() => ContentString(str);

  @override
  AbstractContent splice(int offset) {
    final right = ContentString(str.substring(offset));
    str = str.substring(0, offset);
    return right;
  }

  @override
  bool mergeWith(AbstractContent right) {
    if (right is ContentString) {
      str += right.str;
      return true;
    }
    return false;
  }

  @override
  int getRef() => 4; // Reference number for ContentString
}

/// Content that references other CRDT types
class ContentType extends AbstractContent {
  final dynamic type; // Will hold YMap, YArray, or YText

  ContentType(this.type);

  @override
  int getLength() => 1;

  @override
  List<dynamic> getContent() => [type];

  @override
  bool isCountable() => true;

  @override
  AbstractContent copy() => ContentType(type);

  @override
  AbstractContent splice(int offset) {
    throw UnsupportedError('ContentType cannot be split');
  }

  @override
  bool mergeWith(AbstractContent right) => false; // Cannot merge types

  @override
  int getRef() => 7; // Reference number for ContentType
}

/// Content for deleted items - keeps track of length but no actual content
class ContentDeleted extends AbstractContent {
  final int len;

  ContentDeleted(this.len);

  @override
  int getLength() => len;

  @override
  List<dynamic> getContent() => [];

  @override
  bool isCountable() => false;

  @override
  AbstractContent copy() => ContentDeleted(len);

  @override
  AbstractContent splice(int offset) {
    return ContentDeleted(len - offset);
  }

  @override
  bool mergeWith(AbstractContent right) {
    return false; // Deleted content cannot be merged
  }

  @override
  int getRef() => 1; // Reference number for ContentDeleted
}

/// Content that holds CRDT counter values (GCounter or PNCounter)
class ContentCounter extends AbstractContent {
  final dynamic counter; // GCounter or PNCounter

  ContentCounter(this.counter);

  @override
  int getLength() => 1;

  @override
  List<dynamic> getContent() => [counter];

  @override
  bool isCountable() => true;

  @override
  AbstractContent copy() {
    // Create a copy of the counter
    if (counter.runtimeType.toString() == 'GCounter') {
      return ContentCounter(counter.copy());
    } else if (counter.runtimeType.toString() == 'PNCounter') {
      return ContentCounter(counter.copy());
    }
    return ContentCounter(counter);
  }

  @override
  AbstractContent splice(int offset) {
    throw UnsupportedError('ContentCounter cannot be split');
  }

  @override
  bool mergeWith(AbstractContent right) {
    // Counters can be merged by merging their internal state
    if (right is ContentCounter && 
        counter.runtimeType == right.counter.runtimeType) {
      counter.merge(right.counter);
      return true;
    }
    return false;
  }

  @override
  int getRef() => 9; // Reference number for ContentCounter
}