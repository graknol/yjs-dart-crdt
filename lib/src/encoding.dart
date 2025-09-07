import 'dart:convert';
import 'dart:typed_data';
import 'crdt_types.dart';

/// Binary encoding utilities for CRDT documents
/// 
/// Provides compact binary representation compared to JSON
class BinaryEncoder {
  static const int _TYPE_DOC = 0;
  static const int _TYPE_YMAP = 1;
  static const int _TYPE_YARRAY = 2;
  static const int _TYPE_YTEXT = 3;
  static const int _TYPE_GCOUNTER = 4;
  static const int _TYPE_PNCOUNTER = 5;
  static const int _TYPE_STRING = 10;
  static const int _TYPE_INT = 11;
  static const int _TYPE_DOUBLE = 12;
  static const int _TYPE_BOOL = 13;
  static const int _TYPE_NULL = 14;
  static const int _TYPE_LIST = 15;
  static const int _TYPE_MAP = 16;

  /// Encode a document to binary format
  static Uint8List encodeDocument(Doc doc) {
    final buffer = BytesBuilder();
    
    // Write header
    buffer.addByte(_TYPE_DOC);
    _writeInt32(buffer, doc.clientID);
    _writeInt32(buffer, doc.getState());
    
    // Write shared types count
    _writeInt32(buffer, doc.sharedTypes.length);
    
    // Write each shared type
    for (final entry in doc.sharedTypes.entries) {
      _writeString(buffer, entry.key);
      _encodeValue(buffer, entry.value);
    }
    
    return buffer.toBytes();
  }

  /// Decode a document from binary format
  static Doc decodeDocument(Uint8List data) {
    final reader = _BinaryReader(data);
    
    // Read header
    final docType = reader.readByte();
    if (docType != _TYPE_DOC) {
      throw FormatException('Invalid document format');
    }
    
    final clientID = reader.readInt32();
    final clock = reader.readInt32();
    
    final doc = Doc(clientID: clientID);
    doc.setClock(clock);
    
    // Read shared types
    final sharedCount = reader.readInt32();
    for (int i = 0; i < sharedCount; i++) {
      final key = reader.readString();
      final value = _decodeValue(reader);
      doc.share(key, value);
    }
    
    return doc;
  }

  /// Compare sizes: binary vs JSON vs JSON+gzip
  static Map<String, int> compareSizes(Doc doc) {
    // Binary encoding
    final binaryData = encodeDocument(doc);
    final binarySize = binaryData.length;
    
    // JSON encoding
    final jsonString = jsonEncode(doc.toJSON());
    final jsonSize = utf8.encode(jsonString).length;
    
    // JSON + gzip (simulated by measuring compression potential)
    // Note: Dart does not have built-in gzip in core, so we estimate
    final jsonGzipSize = _estimateGzipSize(jsonString);
    
    return {
      'binary': binarySize,
      'json': jsonSize,
      'json_gzip_estimated': jsonGzipSize,
    };
  }

  // Internal encoding methods
  
  static void _encodeValue(BytesBuilder buffer, dynamic value) {
    if (value == null) {
      buffer.addByte(_TYPE_NULL);
    } else if (value is String) {
      buffer.addByte(_TYPE_STRING);
      _writeString(buffer, value);
    } else if (value is int) {
      buffer.addByte(_TYPE_INT);
      _writeInt64(buffer, value);
    } else if (value is double) {
      buffer.addByte(_TYPE_DOUBLE);
      _writeDouble(buffer, value);
    } else if (value is bool) {
      buffer.addByte(_TYPE_BOOL);
      buffer.addByte(value ? 1 : 0);
    } else if (value is List) {
      buffer.addByte(_TYPE_LIST);
      _writeInt32(buffer, value.length);
      for (final item in value) {
        _encodeValue(buffer, item);
      }
    } else if (value is Map) {
      buffer.addByte(_TYPE_MAP);
      _writeInt32(buffer, value.length);
      for (final entry in value.entries) {
        _writeString(buffer, entry.key.toString());
        _encodeValue(buffer, entry.value);
      }
    } else if (value.runtimeType.toString() == 'YMap') {
      buffer.addByte(_TYPE_YMAP);
      _encodeValue(buffer, value.toJSON());
    } else if (value.runtimeType.toString() == 'YArray') {
      buffer.addByte(_TYPE_YARRAY);
      _encodeValue(buffer, value.toJSON());
    } else if (value.runtimeType.toString() == 'YText') {
      buffer.addByte(_TYPE_YTEXT);
      _writeString(buffer, value.toString());
    } else if (value.runtimeType.toString() == 'GCounter') {
      buffer.addByte(_TYPE_GCOUNTER);
      _encodeValue(buffer, value.toJSON());
    } else if (value.runtimeType.toString() == 'PNCounter') {
      buffer.addByte(_TYPE_PNCOUNTER);
      _encodeValue(buffer, value.toJSON());
    } else {
      // Fallback: encode as JSON string
      buffer.addByte(_TYPE_STRING);
      _writeString(buffer, jsonEncode(value));
    }
  }

  static dynamic _decodeValue(_BinaryReader reader) {
    final type = reader.readByte();
    
    switch (type) {
      case _TYPE_NULL:
        return null;
      case _TYPE_STRING:
        return reader.readString();
      case _TYPE_INT:
        return reader.readInt64();
      case _TYPE_DOUBLE:
        return reader.readDouble();
      case _TYPE_BOOL:
        return reader.readByte() == 1;
      case _TYPE_LIST:
        final length = reader.readInt32();
        final list = <dynamic>[];
        for (int i = 0; i < length; i++) {
          list.add(_decodeValue(reader));
        }
        return list;
      case _TYPE_MAP:
        final length = reader.readInt32();
        final map = <String, dynamic>{};
        for (int i = 0; i < length; i++) {
          final key = reader.readString();
          final value = _decodeValue(reader);
          map[key] = value;
        }
        return map;
      case _TYPE_YMAP:
        // For now, return the JSON representation
        // Full implementation would reconstruct the YMap
        return _decodeValue(reader);
      case _TYPE_YARRAY:
        // For now, return the JSON representation
        return _decodeValue(reader);
      case _TYPE_YTEXT:
        // For now, return the string representation
        return reader.readString();
      case _TYPE_GCOUNTER:
      case _TYPE_PNCOUNTER:
        // For now, return the JSON representation
        return _decodeValue(reader);
      default:
        throw FormatException('Unknown type: $type');
    }
  }

  static void _writeInt32(BytesBuilder buffer, int value) {
    final data = Uint8List(4);
    data.buffer.asByteData().setInt32(0, value, Endian.little);
    buffer.add(data);
  }

  static void _writeInt64(BytesBuilder buffer, int value) {
    final data = Uint8List(8);
    data.buffer.asByteData().setInt64(0, value, Endian.little);
    buffer.add(data);
  }

  static void _writeDouble(BytesBuilder buffer, double value) {
    final data = Uint8List(8);
    data.buffer.asByteData().setFloat64(0, value, Endian.little);
    buffer.add(data);
  }

  static void _writeString(BytesBuilder buffer, String value) {
    final bytes = utf8.encode(value);
    _writeInt32(buffer, bytes.length);
    buffer.add(bytes);
  }

  // Simple gzip size estimation (very rough)
  static int _estimateGzipSize(String json) {
    // Very rough estimation: gzip typically achieves 60-80% compression on JSON
    // This varies greatly depending on data repetition
    final jsonSize = utf8.encode(json).length;
    return (jsonSize * 0.7).round(); // Assume 70% of original size
  }
}

/// Binary data reader helper
class _BinaryReader {
  final Uint8List _data;
  int _offset = 0;

  _BinaryReader(this._data);

  int readByte() {
    if (_offset >= _data.length) {
      throw FormatException('Unexpected end of data');
    }
    return _data[_offset++];
  }

  int readInt32() {
    if (_offset + 4 > _data.length) {
      throw FormatException('Unexpected end of data');
    }
    final value = _data.buffer.asByteData().getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readInt64() {
    if (_offset + 8 > _data.length) {
      throw FormatException('Unexpected end of data');
    }
    final value = _data.buffer.asByteData().getInt64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  double readDouble() {
    if (_offset + 8 > _data.length) {
      throw FormatException('Unexpected end of data');
    }
    final value = _data.buffer.asByteData().getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  String readString() {
    final length = readInt32();
    if (_offset + length > _data.length) {
      throw FormatException('Unexpected end of data');
    }
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return utf8.decode(bytes);
  }
}