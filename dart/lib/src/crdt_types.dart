import 'id.dart';
import 'hlc.dart';
import 'content.dart';
import 'counters.dart';

/// Represents an operation in the CRDT history for delta synchronization
class _Operation {
  final String nodeId;
  final HLC hlc;
  final String type;
  final Map<String, dynamic> data;

  _Operation({
    required this.nodeId,
    required this.hlc,
    required this.type,
    required this.data,
  });

  Map<String, dynamic> toJSON() {
    return {
      'nodeId': nodeId,
      'hlc': hlc.toJson(),
      'type': type,
      'data': data,
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
  )   : _info = content.isCountable() ? _BIT_COUNTABLE : 0,
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
    if (length == 1) {
      return id;
    } else {
      // For HLC-based IDs, we need to increment the logical counter
      final newHLC = id.hlc.copyWith(logicalCounter: id.hlc.logicalCounter + length - 1);
      return ID(newHLC);
    }
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
      transaction._addToDeleteSet(id.hlc.nodeId, id.hlc.physicalTime, length);
    }
  }

  /// Try to merge this item with the right item
  bool mergeWith(Item right) {
    return this.runtimeType == right.runtimeType &&
        compareIDs(right.origin, lastId) &&
        this.right == right &&
        compareIDs(rightOrigin, right.rightOrigin) &&
        id.hlc.nodeId == right.id.hlc.nodeId &&
        id.hlc.physicalTime + length == right.id.hlc.physicalTime &&
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
  final Map<String, int> _deleteSet = {}; // Using String nodeId instead of int client
  final List<Map<String, dynamic>> _operations = [];

  Transaction(this.doc, {this.local = true});

  void _addToDeleteSet(String nodeId, int physicalTime, int len) {
    // Simplified - using string-based delete set
    _deleteSet[nodeId] = (_deleteSet[nodeId] ?? 0) + len;
  }
  
  /// Track an operation during this transaction
  void trackOperation(String type, Map<String, dynamic> data) {
    _operations.add({
      'type': type,
      'data': data,
      'nodeId': doc.nodeId,
      'hlc': doc.getCurrentHLC().toJson(),
    });
  }
  
  /// Get all operations tracked in this transaction
  List<Map<String, dynamic>> getOperations() => List.from(_operations);
}

/// Document that contains CRDT types
class Doc {
  /// Node identifier for this document instance
  final String nodeId;
  
  /// Current Hybrid Logical Clock state
  HLC _currentHLC;
  
  final Map<String, dynamic> _share = {};
  
  /// HLC state representing the known state from each node
  final Map<String, HLC> _hlcVector = {};
  
  /// Operation history for delta synchronization
  final List<_Operation> _operationHistory = [];
  
  /// Maximum number of operations to keep in history
  static const int _maxHistorySize = 1000;

  Doc({String? nodeId, int? clientID}) 
      : nodeId = nodeId ?? (clientID != null ? 'legacy-$clientID' : generateGuidV4()),
        _currentHLC = HLC.now(nodeId ?? (clientID != null ? 'legacy-$clientID' : generateGuidV4())) {
    _hlcVector[this.nodeId] = _currentHLC;
  }

  /// Legacy constructor for backward compatibility
  factory Doc.withClientID(int clientID) {
    final nodeId = 'legacy-$clientID';
    return Doc(nodeId: nodeId);
  }

  /// Backward compatibility getter
  int get clientID => int.tryParse(nodeId.replaceFirst('legacy-', '')) ?? nodeId.hashCode;

  /// Get a copy of the shared types (for serialization)
  Map<String, dynamic> get sharedTypes => Map.from(_share);

  /// Get the current HLC
  HLC getCurrentHLC() => _currentHLC;

  /// Get the current state (for backward compatibility)
  int getState() => _currentHLC.physicalTime;

  /// Increment and return the next HLC
  HLC nextHLC() {
    _currentHLC = _currentHLC.increment();
    _hlcVector[nodeId] = _currentHLC;
    return _currentHLC;
  }
  
  /// Get a copy of the current HLC vector
  Map<String, HLC> getHLCVector() => Map.from(_hlcVector);
  
  /// Get vector clock for backward compatibility
  Map<int, int> getVectorClock() {
    final result = <int, int>{};
    for (final entry in _hlcVector.entries) {
      // Convert node ID to int for legacy support
      final clientId = int.tryParse(entry.key.replaceFirst('legacy-', '')) ?? entry.key.hashCode;
      result[clientId] = entry.value.physicalTime;
    }
    return result;
  }
  
  /// Update HLC vector with information from another node
  void updateHLCVector(String otherNodeId, HLC otherHLC) {
    final currentHLC = _hlcVector[otherNodeId];
    if (currentHLC == null || otherHLC.happensBefore(currentHLC)) {
      _hlcVector[otherNodeId] = otherHLC;
    }
    
    // Update our own HLC based on received event
    _currentHLC = _currentHLC.receiveEvent(otherHLC);
    _hlcVector[nodeId] = _currentHLC;
  }
  
  /// Compare HLC vectors to determine if we need updates from a remote state
  bool _needsUpdateFromHLCState(Map<String, HLC> remoteState) {
    for (final entry in remoteState.entries) {
      final nodeId = entry.key;
      final remoteHLC = entry.value;
      final localHLC = _hlcVector[nodeId];
      
      if (localHLC == null || remoteHLC.happensAfter(localHLC)) {
        return true;
      }
    }
    return false;
  }
  
  /// Add an operation to the history
  void _addOperation(String type, Map<String, dynamic> data) {
    final op = _Operation(
      nodeId: nodeId,
      hlc: _currentHLC,
      type: type,
      data: data,
    );
    
    _operationHistory.add(op);
    
    // Trim history if it gets too large
    if (_operationHistory.length > _maxHistorySize) {
      _operationHistory.removeRange(0, _operationHistory.length - _maxHistorySize);
    }
  }

  /// Set the clock value (used during deserialization)
  void setClock(int clock) {
    _currentHLC = HLC(
      physicalTime: clock,
      logicalCounter: _currentHLC.logicalCounter,
      nodeId: nodeId,
    );
    _hlcVector[nodeId] = _currentHLC;
  }

  /// Get a shared type by key
  T? get<T>(String key) => _share[key] as T?;

  /// Set a shared type by key
  void share<T>(String key, T type) {
    _share[key] = type;
    if (type is AbstractType) {
      type._integrate(this);
    }
    
    // Increment HLC and track this as an operation for delta synchronization
    nextHLC();
    _addOperation('share', {
      'key': key,
      'type': type.runtimeType.toString(),
      'data': type is AbstractType ? type.toJSON() : type,
    });
  }

  /// Execute a transaction
  void transact(void Function(Transaction) fn, {bool local = true}) {
    final transaction = Transaction(this, local: local);
    fn(transaction);
    
    // Process tracked operations from the transaction
    for (final opData in transaction.getOperations()) {
      nextHLC(); // Increment HLC for each operation
      final op = _Operation(
        nodeId: opData['nodeId'] as String,
        hlc: _currentHLC, // Use the incremented HLC value
        type: opData['type'] as String,
        data: opData['data'] as Map<String, dynamic>,
      );
      _operationHistory.add(op);
      
      // Trim history if needed
      if (_operationHistory.length > _maxHistorySize) {
        _operationHistory.removeRange(0, _operationHistory.length - _maxHistorySize);
      }
    }
  }

  /// Serialize the entire document state to JSON
  Map<String, dynamic> toJSON() {
    final result = <String, dynamic>{
      'nodeId': nodeId,
      'hlc': _currentHLC.toJson(),
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
    String? nodeId;
    
    // Handle both new HLC format and legacy format
    if (json.containsKey('nodeId')) {
      nodeId = json['nodeId'] as String?;
    } else if (json.containsKey('clientID')) {
      // Legacy format support
      final clientID = json['clientID'] as int?;
      nodeId = clientID != null ? 'legacy-$clientID' : null;
    }
    
    final doc = Doc(nodeId: nodeId);
    
    // Restore HLC if available
    if (json.containsKey('hlc')) {
      doc._currentHLC = HLC.fromJson(json['hlc'] as Map<String, dynamic>);
    } else if (json.containsKey('clock')) {
      // Legacy clock support
      final clock = json['clock'] as int? ?? 0;
      doc._currentHLC = HLC(
        physicalTime: clock * 1000, // Convert to milliseconds
        logicalCounter: 0,
        nodeId: doc.nodeId,
      );
    }
    
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
  /// This implementation computes minimal deltas based on HLC vectors
  /// Also supports legacy vector clock format for backward compatibility
  Map<String, dynamic> getUpdateSince(Map<int, int> remoteState) {
    final List<Map<String, dynamic>> operations = [];
    final Map<String, HLC> currentVector = getHLCVector();
    
    // Convert legacy vector clock to HLC format for comparison
    final Map<String, HLC> remoteHLCState = {};
    for (final entry in remoteState.entries) {
      final clientId = entry.key;
      final clock = entry.value;
      final nodeId = 'legacy-$clientId';
      remoteHLCState[nodeId] = HLC(
        physicalTime: clock * 1000, // Convert to milliseconds
        logicalCounter: 0,
        nodeId: nodeId,
      );
    }
    
    // Find operations that the remote client hasn't seen
    for (final operation in _operationHistory) {
      final opNodeId = operation.nodeId;
      final opHLC = operation.hlc;
      final remoteHLC = remoteHLCState[opNodeId];
      
      // Include this operation if remote hasn't seen it
      if (remoteHLC == null || opHLC.happensAfter(remoteHLC)) {
        operations.add(operation.toJSON());
      }
    }
    
    // If we have operations to send, return delta update
    if (operations.isNotEmpty) {
      return {
        'type': 'delta_update',
        'operations': operations,
        'hlc_vector': currentVector.map((k, v) => MapEntry(k, v.toJson())),
        'vector_clock': getVectorClock().map((k, v) => MapEntry(k.toString(), v)), // Legacy compatibility
        'nodeId': nodeId,
      };
    }
    
    // If remote state indicates they need a full sync or we have no common history
    bool needsFullSync = false;
    for (final entry in remoteHLCState.entries) {
      final remoteNodeId = entry.key;
      final remoteHLC = entry.value;
      final localHLC = currentVector[remoteNodeId];
      
      // If they have changes we don't know about, or if we can't find
      // the operations they need in our history, send full state
      if (localHLC == null || remoteHLC.happensAfter(localHLC) || 
          (remoteHLC.physicalTime > 0 && _operationHistory.isEmpty)) {
        needsFullSync = true;
        break;
      }
    }
    
    if (needsFullSync) {
      return {
        'type': 'full_state',
        'state': toJSON(),
        'hlc_vector': currentVector.map((k, v) => MapEntry(k, v.toJson())),
        'vector_clock': getVectorClock().map((k, v) => MapEntry(k.toString(), v)), // Legacy compatibility
        'nodeId': nodeId,
      };
    }
    
    // No changes to send
    return {
      'type': 'no_changes',
      'hlc_vector': currentVector.map((k, v) => MapEntry(k, v.toJson())),
      'vector_clock': getVectorClock().map((k, v) => MapEntry(k.toString(), v)), // Legacy compatibility
      'nodeId': nodeId,
    };
  }

  /// Apply an update/delta to this document
  void applyUpdate(Map<String, dynamic> update) {
    final updateType = update['type'] as String;
    final updateNodeId = update['nodeId'] as String?;
    
    // Handle HLC vector clock updates
    final updateHLCVectorData = update['hlc_vector'] as Map<String, dynamic>?;
    if (updateHLCVectorData != null) {
      for (final entry in updateHLCVectorData.entries) {
        final nodeId = entry.key;
        final hlcData = entry.value as Map<String, dynamic>;
        final hlc = HLC.fromJson(hlcData);
        updateHLCVector(nodeId, hlc);
      }
    }
    
    // Handle legacy vector clock updates for backward compatibility
    final updateVectorClock = update['vector_clock'] as Map<String, dynamic>?;
    if (updateVectorClock != null && updateHLCVectorData == null) {
      for (final entry in updateVectorClock.entries) {
        final clientId = int.parse(entry.key);
        final clock = entry.value as int;
        final nodeId = 'legacy-$clientId';
        final hlc = HLC(
          physicalTime: clock * 1000, // Convert to milliseconds
          logicalCounter: 0,
          nodeId: nodeId,
        );
        updateHLCVector(nodeId, hlc);
      }
    }
    
    switch (updateType) {
      case 'delta_update':
        _applyDeltaUpdate(update);
        break;
        
      case 'full_state':
        _applyFullStateUpdate(update);
        break;
        
      case 'no_changes':
        // Nothing to apply, HLC vector already updated above
        break;
        
      default:
        throw ArgumentError('Unknown update type: $updateType');
    }
  }
  
  /// Apply a delta update containing incremental operations
  void _applyDeltaUpdate(Map<String, dynamic> update) {
    final operations = update['operations'] as List<dynamic>;
    
    print('DEBUG: Processing ${operations.length} operations');
    
    for (final opData in operations) {
      final op = _Operation.fromJSON(opData as Map<String, dynamic>);
      
      print('DEBUG: Processing operation from ${op.nodeId} with HLC ${op.hlc.physicalTime}');
      
      // For testing YATA - temporarily disable operation filtering to ensure all operations are processed
      // TODO: Implement proper operation deduplication based on unique operation IDs
      print('DEBUG: Applying operation: ${op.type}');
      
      // Apply the operation based on its type
      _applyOperation(op);
      
      // Update our HLC vector (take the maximum of local and remote)
      final localHLC = _hlcVector[op.nodeId];
      if (localHLC == null || op.hlc.happensAfter(localHLC)) {
        updateHLCVector(op.nodeId, op.hlc);
      }
      
      // Add to our operation history if it's not from us
      if (op.nodeId != nodeId) {
        _operationHistory.add(op);
        
        // Trim history if needed
        if (_operationHistory.length > _maxHistorySize) {
          _operationHistory.removeRange(0, _operationHistory.length - _maxHistorySize);
        }
      }
    }
  }
  
  /// Apply a full state update (legacy compatibility)
  void _applyFullStateUpdate(Map<String, dynamic> update) {
    final state = update['state'] as Map<String, dynamic>;
    final otherDoc = Doc.fromJSON(state);
    
    // Merge the other document's state into this one
    for (final entry in otherDoc._share.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (!_share.containsKey(key)) {
        // Don't track this as an operation since it's a full state sync
        _share[key] = value;
        if (value is AbstractType) {
          value._integrate(this);
        }
      } else {
        // For now, just replace - full implementation would merge CRDT states
        _share[key] = value;
        if (value is AbstractType) {
          value._integrate(this);
        }
      }
    }
    
    // Update HLC to be after the other document's HLC
    _currentHLC = _currentHLC.receiveEvent(otherDoc._currentHLC);
    _hlcVector[nodeId] = _currentHLC;
  }
  
  /// Apply a specific operation to the document state
  void _applyOperation(_Operation operation) {
    print('DEBUG: Applying operation: ${operation.type} with data: ${operation.data}');
    
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
          case 'YArray':
            value = YArray<dynamic>();
            if (data is List) {
              for (final item in data) {
                (value as YArray).push(item);
              }
            }
            break;
          case 'YText':
            value = YText();
            if (data is String) {
              (value as YText).insert(0, data);
            }
            break;
          case 'GCounter':
            if (data is Map<String, dynamic> && data['state'] != null) {
              final state = data['state'] as Map<String, dynamic>;
              final counterState = state.map((k, v) => MapEntry(int.parse(k), v as int));
              value = GCounter(counterState);
            } else {
              value = GCounter();
            }
            break;
          case 'PNCounter':
            if (data is Map<String, dynamic>) {
              final positive = data['positive'] as Map<String, dynamic>?;
              final negative = data['negative'] as Map<String, dynamic>?;
              
              Map<int, int>? positiveState;
              Map<int, int>? negativeState;
              
              if (positive != null) {
                positiveState = positive.map((k, v) => MapEntry(int.parse(k), v as int));
              }
              if (negative != null) {
                negativeState = negative.map((k, v) => MapEntry(int.parse(k), v as int));
              }
              
              value = PNCounter(positiveState, negativeState);
            } else {
              value = PNCounter();
            }
            break;
          default:
            // For primitive types
            value = data;
        }
        
        // Apply the share operation without tracking it again
        _share[key] = value;
        if (value is AbstractType) {
          value._integrate(this);
        }
        break;
        
      case 'map_set':
        final targetKey = operation.data['target'] as String;
        final key = operation.data['key'] as String;
        final value = operation.data['value'];
        final valueType = operation.data['value_type'] as String;
        
        // Find the target map in shared types
        for (final entry in _share.entries) {
          if (entry.value is YMap) {
            final map = entry.value as YMap;
            
            // Reconstruct the value based on its type
            dynamic reconstructedValue;
            switch (valueType) {
              case 'GCounter':
                if (value is Map<String, dynamic> && value['state'] != null) {
                  final state = value['state'] as Map<String, dynamic>;
                  final counterState = state.map((k, v) => MapEntry(int.parse(k), v as int));
                  reconstructedValue = GCounter(counterState);
                } else {
                  reconstructedValue = GCounter();
                }
                break;
              case 'PNCounter':
                if (value is Map<String, dynamic>) {
                  final positive = value['positive'] as Map<String, dynamic>?;
                  final negative = value['negative'] as Map<String, dynamic>?;
                  
                  Map<int, int>? positiveState;
                  Map<int, int>? negativeState;
                  
                  if (positive != null) {
                    positiveState = positive.map((k, v) => MapEntry(int.parse(k), v as int));
                  }
                  if (negative != null) {
                    negativeState = negative.map((k, v) => MapEntry(int.parse(k), v as int));
                  }
                  
                  reconstructedValue = PNCounter(positiveState, negativeState);
                } else {
                  reconstructedValue = PNCounter();
                }
                break;
              default:
                // For primitive types and other types
                reconstructedValue = value;
            }
            
            // Apply the set operation directly to the map's internal structure
            // without going through the normal set method to avoid double tracking
            map._directSet(key, reconstructedValue);
            break;
          }
        }
        break;
        break;
        
      case 'text_insert':
        final targetKey = operation.data['target'] as String;
        final index = operation.data['index'] as int;
        final text = operation.data['text'] as String;
        final originLeft = operation.data['origin_left'] as String?;
        final originRight = operation.data['origin_right'] as String?;
        
        // The target for text operations is 'text', but we need to find the
        // YText instance. For now, find the first YText in shared types.
        // In a more complete implementation, we'd use the target key properly.
        for (final entry in _share.entries) {
          if (entry.value is YText) {
            final ytext = entry.value as YText;
            // Apply the remote insert operation with YATA origins
            ytext._applyRemoteInsert(index, text, operation.hlc, 
              originLeft: originLeft, originRight: originRight);
            break;
          }
        }
        break;
        
      case 'text_delete':
        final targetKey = operation.data['target'] as String;
        final index = operation.data['index'] as int;
        final deleteCount = operation.data['deleteCount'] as int;
        
        // Find the YText instance in shared types
        for (final entry in _share.entries) {
          if (entry.value is YText) {
            final ytext = entry.value as YText;
            // Apply the remote delete operation
            ytext._applyRemoteDelete(index, deleteCount, operation.hlc);
            break;
          }
        }
        break;
        
      default:
        // Handle other operation types as they are implemented
        break;
    }
  }
  
  /// Create a snapshot of the current document state
  /// This can be used as a checkpoint for delta synchronization
  Map<String, dynamic> createSnapshot() {
    return {
      'type': 'snapshot',
      'state': toJSON(),
      'hlc_vector': getHLCVector().map((k, v) => MapEntry(k, v.toJson())),
      'vector_clock': getVectorClock(), // Legacy compatibility
      'timestamp': DateTime.now().toIso8601String(),
      'nodeId': nodeId,
    };
  }
  
  /// Get updates since a specific snapshot
  Map<String, dynamic> getUpdateSinceSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot['type'] != 'snapshot') {
      throw ArgumentError('Invalid snapshot format');
    }
    
    // Try HLC vector first, fall back to legacy vector clock
    if (snapshot.containsKey('vector_clock')) {
      final snapshotVectorClock = snapshot['vector_clock'] as Map<String, dynamic>;
      final remoteState = snapshotVectorClock.map((k, v) => MapEntry(int.parse(k), v as int));
      return getUpdateSince(remoteState);
    } else {
      // If no legacy support needed, we could use HLC vector directly here
      // For now, convert to legacy format for compatibility
      return getUpdateSince({});
    }
  }
  
  /// Check if this document has unseen changes compared to a remote state
  bool hasChangesSince(Map<int, int> remoteState) {
    final currentVector = getVectorClock();
    
    for (final entry in currentVector.entries) {
      final clientId = entry.key;
      final localClock = entry.value;
      final remoteClock = remoteState[clientId] ?? 0;
      
      if (localClock > remoteClock) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Get a summary of the current synchronization state
  Map<String, dynamic> getSyncState() {
    return {
      'nodeId': nodeId,
      'clientID': clientID, // Legacy compatibility
      'hlc': _currentHLC.toJson(),
      'clock': _currentHLC.physicalTime, // Legacy compatibility
      'hlc_vector': getHLCVector().map((k, v) => MapEntry(k, v.toJson())),
      'vector_clock': getVectorClock().map((k, v) => MapEntry(k.toString(), v)), // Legacy compatibility
      'operation_history_size': _operationHistory.length,
      'shared_types': _share.keys.toList(),
    };
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
    final crdtEntries = _map.entries
        .where((entry) => !entry.value.deleted)
        .map((entry) => MapEntry(
              entry.key,
              entry.value.content.getContent().last,
            ));
    
    final simpleEntries = _simpleMap?.entries ?? <MapEntry<String, dynamic>>[];
    
    // Combine both sources, with CRDT entries taking precedence
    final Map<String, dynamic> combined = {};
    
    // Add simple map entries first
    for (final entry in simpleEntries) {
      combined[entry.key] = entry.value;
    }
    
    // Add CRDT entries (these override simple map entries if keys conflict)
    for (final entry in crdtEntries) {
      combined[entry.key] = entry.value;
    }
    
    return combined.entries;
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
    
    // Track this operation for delta synchronization
    transaction.trackOperation('map_set', {
      'target': 'map',
      'key': key,
      'value': value is AbstractType ? value.toJSON() : value,
      'value_type': value.runtimeType.toString(),
    });
    
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
      createID(doc.nextHLC()),
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
  
  /// Direct set method for applying operations without tracking them again
  void _directSet(String key, dynamic value) {
    // This is a simplified direct set that bypasses transaction tracking
    // Used when applying operations from remote sources
    // In a full implementation, this would create proper CRDT items
    
    // For now, we'll use a simple approach for testing
    // This should be enhanced to properly handle CRDT items
    if (value is AbstractType) {
      value._integrate(doc!);
    }
    
    // Store in a simple way for testing - this should be enhanced
    // to create proper Item structures
    _simpleMap ??= <String, dynamic>{};
    _simpleMap![key] = value;
  }
  
  /// Simple map for direct operations - this is a temporary solution
  Map<String, dynamic>? _simpleMap;
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

  void _typeListInsert(
      Transaction transaction, int index, List<dynamic> content) {
    if (index > _length) {
      throw RangeError('Index $index out of range (0-$_length)');
    }

    Item? left = _findItemAtIndex(index - 1);
    Item? right = left?.right;

    // Create content
    final contentObj = ContentAny(content);

    final item = Item(
      createID(transaction.doc.nextHLC()),
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
        if (currentIndex < index + deleteCount &&
            currentIndex + itemLength > index) {
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
      if (!current.deleted &&
          current.countable &&
          current.content is ContentString) {
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

    // Track this operation for delta synchronization with YATA origins
    final position = _findPosition(index);
    transaction.trackOperation('text_insert', {
      'target': 'text',
      'index': index,
      'text': text,
      'origin_left': position.left?.id.toString(),
      'origin_right': position.right?.id.toString(),
    });

    // YATA approach: Insert each character as a separate item
    // This ensures proper conflict resolution for concurrent edits
    Item? currentLeft = position.left;
    Item? currentRight = position.right;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final content = ContentString(char); // Single character
      final item = Item(
        createID(transaction.doc.nextHLC()),
        currentLeft,
        currentLeft?.lastId,
        (i == 0) ? currentRight : null, // Only first character points to right origin
        (i == 0) ? currentRight?.id : null,
        this,
        null,
        content,
      );

      item.integrate(transaction, 0);
      
      // Update pointers for next character - characters form a contiguous sequence
      currentLeft = item;
      // currentRight stays null for subsequent characters in same operation
      currentRight = null;
    }
  }

  void _deleteText(Transaction transaction, int index, int deleteCount) {
    if (index >= length || deleteCount <= 0) return;

    final endIndex = (index + deleteCount).clamp(0, length);
    int currentIndex = 0;
    Item? current = _start;

    while (current != null && currentIndex < endIndex) {
      if (!current.deleted &&
          current.countable &&
          current.content is ContentString) {
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
    Item? previousItem;

    while (current != null) {
      if (!current.deleted &&
          current.countable &&
          current.content is ContentString) {
        final content = current.content as ContentString;
        final itemStartIndex = currentIndex;
        final itemEndIndex = currentIndex + content.str.length;

        if (index <= itemEndIndex) {
          if (index == itemStartIndex) {
            // Insert at the beginning of this item
            return _TextPosition(previousItem, current);
          } else if (index == itemEndIndex) {
            // Insert at the end of this item
            return _TextPosition(current, current.right);
          } else {
            // Insert within this item - we need to split it
            // For now, let's insert at the end of this item as a workaround
            // TODO: Implement proper item splitting
            return _TextPosition(current, current.right);
          }
        }

        currentIndex = itemEndIndex;
      }
      previousItem = current;
      current = current.right;
    }

    // Insert at the very end
    return _TextPosition(previousItem, null);
  }
  
  /// Apply a remote insert operation (used during synchronization)
  void _applyRemoteInsert(int index, String text, HLC remoteHLC, {String? originLeft, String? originRight}) {
    // Apply remote insert without creating new transaction
    // This prevents infinite recursion during sync
    
    print('DEBUG: _applyRemoteInsert called with index=$index, text="$text", originLeft=$originLeft, originRight=$originRight');
    
    if (index > length) {
      index = length; // Clamp to valid range
    }
    
    // Find origin items by their IDs if provided
    Item? leftOriginItem;
    Item? rightOriginItem;
    
    if (originLeft != null) {
      leftOriginItem = _findItemById(originLeft);
    }
    
    if (originRight != null) {
      rightOriginItem = _findItemById(originRight);
    }
    
    // If origins not found, fall back to position-based insertion
    if (leftOriginItem == null && rightOriginItem == null) {
      final position = _findPosition(index);
      leftOriginItem = position.left;
      rightOriginItem = position.right;
    }

    Item? currentLeft = leftOriginItem;
    Item? currentRight = (rightOriginItem != null) ? rightOriginItem : leftOriginItem?.right;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final content = ContentString(char);
      final item = Item(
        createID(remoteHLC.increment()), // Use remote HLC
        currentLeft,
        currentLeft?.lastId,
        (i == 0) ? currentRight : null, // Only first char points to right origin
        (i == 0) ? currentRight?.id : null,
        this,
        null,
        content,
      );

      // Direct integration without transaction to avoid recursion
      _integrateItemDirectly(item);
      
      // Update pointers for next character
      currentLeft = item;
      currentRight = null; // Clear right origin for subsequent chars
    }
    
    print('DEBUG: After _applyRemoteInsert, text is now: "${toString()}"');
  }
  
  /// Find item by its ID string representation
  Item? _findItemById(String idString) {
    // Parse the ID string to extract HLC components
    // Expected format: "ID(HLC(physicalTime:logicalCounter@nodeId))"
    final match = RegExp(r'ID\(HLC\((\d+):(\d+)@([^)]+)\)\)').firstMatch(idString);
    if (match == null) {
      print('DEBUG: Could not parse ID string: $idString');
      return null;
    }
    
    final physicalTime = int.parse(match.group(1)!);
    final logicalCounter = int.parse(match.group(2)!);
    final nodeId = match.group(3)!;
    
    final targetHLC = HLC(
      physicalTime: physicalTime,
      logicalCounter: logicalCounter,
      nodeId: nodeId,
    );
    
    Item? current = _start;
    while (current != null) {
      if (current.id.hlc == targetHLC) {
        return current;
      }
      current = current.right;
    }
    
    print('DEBUG: Could not find item with ID: $idString');
    return null;
  }
  
  /// Apply a remote delete operation (used during synchronization)
  void _applyRemoteDelete(int index, int deleteCount, HLC remoteHLC) {
    // Apply remote delete without creating new transaction
    if (index >= length || deleteCount <= 0) return;

    final endIndex = (index + deleteCount).clamp(0, length);
    int currentIndex = 0;
    Item? current = _start;

    while (current != null && currentIndex < endIndex) {
      if (!current.deleted &&
          current.countable &&
          current.content is ContentString) {
        final content = current.content as ContentString;
        final itemStart = currentIndex;
        final itemEnd = currentIndex + content.str.length;

        if (itemStart < endIndex && itemEnd > index) {
          // This item overlaps with the deletion range
          // For character-level operations, just mark as deleted
          current.deleted = true;
          _length--;
        }

        currentIndex = itemEnd;
      }
      current = current.right;
    }
  }
  
  /// Direct integration without transaction (used during sync)
  void _integrateItemDirectly(Item item) {
    // Simplified integration for remote operations
    if (item.left != null) {
      item.right = item.left!.right;
      item.left!.right = item;
      if (item.right != null) {
        item.right!.left = item;
      }
    } else {
      // Insert at start
      item.right = _start;
      _start = item;
      if (item.right != null) {
        item.right!.left = item;
      }
    }

    // Update length
    if (item.countable && !item.deleted) {
      _length += item.length;
    }
  }
}

/// Helper class to represent a position in the text
class _TextPosition {
  final Item? left;
  final Item? right;

  _TextPosition(this.left, this.right);
}
