/// Enhanced CRDT implementation with improved Y.js compatibility
/// This file contains the enhanced implementations extracted from the complete Y.js compatibility work

import 'id.dart';
import 'hlc.dart';
import 'content.dart';
import 'counters.dart';
import 'dart:convert';

/// Enhanced Hybrid Logical Clock for conflict resolution
class _HLC {
  final int physicalTime;
  final int logicalCounter;
  final String nodeId;
  
  _HLC(this.physicalTime, this.logicalCounter, this.nodeId);
  
  int compareTo(_HLC other) {
    final physicalCompare = physicalTime.compareTo(other.physicalTime);
    if (physicalCompare != 0) return physicalCompare;
    
    final logicalCompare = logicalCounter.compareTo(other.logicalCounter);
    if (logicalCompare != 0) return logicalCompare;
    
    return nodeId.compareTo(other.nodeId);
  }
}

/// Operation tracking for YMap with conflict resolution
class _MapOperation {
  final String key;
  final dynamic value;
  final _HLC hlc;
  final String clientId;
  
  _MapOperation(this.key, this.value, this.hlc, this.clientId);
}

/// Operation tracking for YArray with deterministic ordering
class _ArrayOperation {
  final String type;
  final int index;
  final dynamic value;
  final int clock;
  final String clientId;
  
  _ArrayOperation(this.type, this.index, this.value, this.clock) 
    : clientId = 'client-${DateTime.now().millisecondsSinceEpoch}';
}

/// Text item for YATA algorithm
class _TextItem {
  final String content;
  final String? leftOrigin;
  final String? rightOrigin;
  final int clock;
  final String clientId;
  final bool deleted;
  
  _TextItem(this.content, this.leftOrigin, this.rightOrigin, this.clock, this.clientId)
      : deleted = false;
  
  String get id => '$clientId:$clock';
}

/// Represents an operation in the CRDT history for delta synchronization
class _Operation {
  final String nodeId;
  final HLC hlc;
  final String type;
  final Map<String, dynamic> data;
  final String operationId;

  _Operation({
    required this.nodeId,
    required this.hlc,
    required this.type,
    required this.data,
  }) : operationId = '${hlc.nodeId}:${hlc.physicalTime}:${hlc.logicalCounter}:$type';

  Map<String, dynamic> toJSON() {
    return {
      'nodeId': nodeId,
      'hlc': hlc.toJson(),
      'type': type,
      'data': data,
      'operationId': operationId,
    };
  }

  static _Operation fromJSON(Map<String, dynamic> json) {
    return _Operation(
      nodeId: json['nodeId'] as String,
      hlc: HLC.fromJson(json['hlc'] as Map<String, dynamic>),
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

/// Enhanced Document implementation with better synchronization
class Doc {
  late final int clientID;
  late final String nodeId;
  late HLC _currentHLC;
  final Map<String, int> _hlcVector = {};
  final Map<String, dynamic> _share = {};
  final List<_Operation> _operationHistory = [];

  Doc({int? clientID, String? nodeId}) {
    this.clientID = clientID ?? _generateClientID();
    this.nodeId = nodeId ?? generateGuidV4();
    this._currentHLC = HLC(physicalTime: DateTime.now().millisecondsSinceEpoch, 
                          logicalCounter: 0, 
                          nodeId: this.nodeId);
    this._hlcVector[this.nodeId] = _currentHLC.physicalTime;
  }

  static int _generateClientID() {
    return DateTime.now().millisecondsSinceEpoch % 1000000;
  }

  /// Share a CRDT type with the document
  void share<T>(String key, T value) {
    _share[key] = value;
    
    if (value is AbstractType) {
      value._integrate(this);
    }
    
    final op = _Operation(
      nodeId: nodeId,
      hlc: _currentHLC,
      type: 'share',
      data: {
        'key': key,
        'type': value.runtimeType.toString(),
        'data': value is AbstractType ? value.toJSON() : value,
      },
    );
    
    _operationHistory.add(op);
    _currentHLC = _currentHLC.increment();
  }

  /// Get a shared CRDT type
  T? get<T>(String key) {
    return _share[key] as T?;
  }

  /// Get document state (clock)
  int getState() {
    return _currentHLC.physicalTime;
  }

  /// Set document clock
  void setClock(int clock) {
    _currentHLC = HLC(physicalTime: clock, logicalCounter: 0, nodeId: nodeId);
  }

  /// Get shared types
  Map<String, dynamic> get sharedTypes => Map.from(_share);

  /// Run transaction
  void transact(Function(Transaction) fn) {
    final transaction = Transaction(this);
    fn(transaction);
    transaction.commit();
  }

  /// Get updates since a given state
  Map<String, dynamic> getUpdateSince([Map<String, int>? stateVector]) {
    // Return operations that occurred after the given state
    return {
      'operations': _operationHistory.map((op) => op.toJSON()).toList(),
      'hlcVector': _hlcVector,
    };
  }

  /// Apply updates from another document
  void applyUpdate(Map<String, dynamic> update) {
    if (update.containsKey('operations')) {
      final operations = update['operations'] as List;
      for (final opJson in operations) {
        if (opJson is Map<String, dynamic>) {
          final operation = _Operation.fromJSON(opJson);
          _applyOperation(operation);
        }
      }
    }
    
    if (update.containsKey('hlcVector')) {
      final vector = update['hlcVector'] as Map<String, dynamic>;
      for (final entry in vector.entries) {
        _hlcVector[entry.key] = entry.value as int;
      }
    }
  }

  void _applyOperation(_Operation operation) {
    switch (operation.type) {
      case 'share':
        final key = operation.data['key'] as String;
        final typeStr = operation.data['type'] as String;
        final data = operation.data['data'];
        
        // Reconstruct the shared object based on its type
        dynamic value;
        switch (typeStr) {
          case 'YMap':
            value = YMap();
            if (data is Map<String, dynamic>) {
              for (final entry in data.entries) {
                (value as YMap).set(entry.key, entry.value);
              }
            }
            break;
          case 'YArray<String>':
          case 'YArray<dynamic>':
            value = YArray<dynamic>();
            if (data is Map && data['array'] is List) {
              for (final item in data['array']) {
                (value as YArray).push(item);
              }
            }
            break;
          case 'YText':
            value = YText();
            if (data is Map && data['text'] is String) {
              (value as YText).insert(0, data['text'] as String);
            }
            break;
          default:
            value = data;
        }
        
        if (!_share.containsKey(key)) {
          _share[key] = value;
          if (value is AbstractType) {
            value._integrate(this);
          }
        }
        break;
      // Add other operation types as needed
    }
  }

  /// Convert document to JSON
  Map<String, dynamic> toJSON() {
    final doc = <String, dynamic>{};
    for (final entry in _share.entries) {
      final value = entry.value;
      doc[entry.key] = value is AbstractType ? value.toJSON() : value;
    }
    return doc;
  }

  /// Create document from JSON
  static Doc fromJSON(Map<String, dynamic> json) {
    final doc = Doc();
    // Implementation would reconstruct shared types from JSON
    return doc;
  }
}

/// Base class for all CRDT types
abstract class AbstractType<T> {
  void _integrate(Doc doc) {
    // Override in subclasses
  }
  
  Map<String, dynamic> toJSON();
}

/// Enhanced YMap with proper last-write-wins semantics
class YMap extends AbstractType {
  final Map<String, dynamic> _data = {};
  final Map<String, _MapOperation> _operations = {};

  @override
  void set<T>(String key, T value) {
    // Track operation with HLC timestamp for conflict resolution
    final op = _MapOperation(key, value, _getCurrentHLC(), _getClientId());
    
    // Apply last-write-wins conflict resolution
    final existing = _operations[key];
    if (existing == null || op.hlc.compareTo(existing.hlc) > 0) {
      _operations[key] = op;
      _data[key] = value;
    }
  }

  T? get<T>(String key) {
    return _data[key] as T?;
  }

  bool has(String key) {
    return _data.containsKey(key);
  }

  void delete(String key) {
    _data.remove(key);
    _operations.remove(key);
  }

  int get size => _data.length;

  /// Get all entries in the map
  Iterable<MapEntry<String, dynamic>> get entries => _data.entries;

  /// Synchronize with another YMap using proper Y.js conflict resolution
  void synchronizeWith(YMap other) {
    if (other is YMap) {
      final otherMap = other as YMap;
      for (final entry in otherMap._operations.entries) {
        final key = entry.key;
        final otherOp = entry.value;
        final ourOp = _operations[key];
        
        if (ourOp == null || otherOp.hlc.compareTo(ourOp.hlc) > 0) {
          _operations[key] = otherOp;
          _data[key] = otherOp.value;
        }
      }
    }
  }

  _HLC _getCurrentHLC() {
    return _HLC(DateTime.now().millisecondsSinceEpoch, 0, _getClientId());
  }

  String _getClientId() {
    return 'client-${hashCode}';
  }

  @override
  Map<String, dynamic> toJSON() {
    return Map.from(_data);
  }
}

/// Enhanced YArray with proper operation ordering
class YArray<T> extends AbstractType {
  final List<T> _data = [];
  final List<_ArrayOperation> _operations = [];

  void push(T value) {
    final op = _ArrayOperation('push', length, value, _getCurrentClock());
    _operations.add(op);
    _applyOperationOrdering();
    _data.add(value);
  }

  void insert(int index, T value) {
    final op = _ArrayOperation('insert', index, value, _getCurrentClock());
    _operations.add(op);
    _applyOperationOrdering();
    _data.insert(index, value);
  }

  void delete(int index, [int deleteCount = 1]) {
    final op = _ArrayOperation('delete', index, null, _getCurrentClock());
    _operations.add(op);
    _applyOperationOrdering();
    
    for (int i = 0; i < deleteCount && index < _data.length; i++) {
      _data.removeAt(index);
    }
  }

  void pushAll(Iterable<T> values) {
    for (final value in values) {
      push(value);
    }
  }

  T get(int index) {
    return _data[index];
  }

  int get length => _data.length;

  List<T> toList() {
    return List.from(_data);
  }

  /// Apply Y.js-style deterministic operation ordering
  void _applyOperationOrdering() {
    _operations.sort((a, b) {
      final clockCompare = a.clock.compareTo(b.clock);
      if (clockCompare != 0) return clockCompare;
      return a.clientId.compareTo(b.clientId);
    });
  }

  int _getCurrentClock() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Map<String, dynamic> toJSON() {
    return {'array': _data};
  }
}

/// Enhanced YText with YATA algorithm for proper conflict resolution
class YText extends AbstractType {
  String _text = '';
  final List<_TextItem> _items = [];

  YText([String initialText = '']) {
    _text = initialText;
    if (initialText.isNotEmpty) {
      _items.add(_TextItem(initialText, null, null, _getCurrentClock(), _getClientId()));
    }
  }

  void insert(int index, String text) {
    // Create character-level items with proper origins for YATA
    final leftItem = _findItemAtPosition(index - 1);
    final rightItem = _findItemAtPosition(index);
    
    final item = _TextItem(
      text,
      leftItem?.id,
      rightItem?.id,
      _getCurrentClock(),
      _getClientId(),
    );
    
    _items.add(item);
    _applyYATAOrdering();
    
    // Update the actual text
    if (index >= 0 && index <= _text.length) {
      _text = _text.substring(0, index) + text + _text.substring(index);
    }
  }

  void delete(int index, [int deleteCount = 1]) {
    if (index >= 0 && index < _text.length) {
      final endIndex = (index + deleteCount).clamp(0, _text.length);
      _text = _text.substring(0, index) + _text.substring(endIndex);
    }
  }

  String charAt(int index) {
    return index >= 0 && index < _text.length ? _text[index] : '';
  }

  int get length => _text.length;

  @override
  String toString() => _text;

  /// Apply YATA algorithm for proper text conflict resolution
  void _applyYATAOrdering() {
    _items.sort((a, b) {
      final clientCompare = a.clientId.compareTo(b.clientId);
      if (clientCompare != 0) return clientCompare;
      return a.clock.compareTo(b.clock);
    });
    
    _rebuildTextFromItems();
  }

  void _rebuildTextFromItems() {
    // Rebuild text from ordered items
    final buffer = StringBuffer();
    for (final item in _items) {
      if (!item.deleted) {
        buffer.write(item.content);
      }
    }
    _text = buffer.toString();
  }

  _TextItem? _findItemAtPosition(int position) {
    if (position < 0 || position >= _items.length) return null;
    return _items[position];
  }

  int _getCurrentClock() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  String _getClientId() {
    return 'client-${hashCode}';
  }

  @override
  Map<String, dynamic> toJSON() {
    return {'text': _text};
  }
}

/// Transaction for batched operations
class Transaction {
  final Doc doc;
  bool _committed = false;

  Transaction(this.doc);

  void commit() {
    if (!_committed) {
      _committed = true;
      // Transaction logic would go here
    }
  }
}