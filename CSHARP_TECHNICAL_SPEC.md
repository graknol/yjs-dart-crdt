# C# Y.js CRDT Library Technical Specification

## Overview

This document provides comprehensive technical specifications for creating a C# equivalent of the Dart Y.js CRDT library. The C# implementation must maintain full compatibility with the Dart version for server-client synchronization in offline-first applications.

## Architecture Overview

### Core Design Principles
- **Pure CRDT Implementation**: No external dependencies except .NET Standard libraries
- **Server-Client Compatibility**: Binary and JSON protocol compatibility with Dart client
- **Thread-Safe Operations**: All CRDT operations must be thread-safe for server environments
- **HLC-Based Causality**: Hybrid Logical Clocks for precise ordering and conflict resolution
- **Memory Efficient**: Optimized for server scenarios with many concurrent documents

### Technology Stack
- **Target Framework**: .NET Standard 2.1 (compatible with .NET Core 3.1+ and .NET 5+)
- **Language**: C# 8.0+ (nullable reference types enabled)
- **Serialization**: System.Text.Json for JSON, custom binary encoding
- **Collections**: System.Collections.Concurrent for thread safety
- **Async**: Task-based async patterns throughout

## Core Data Structures

### 1. Hybrid Logical Clock (HLC)

```csharp
namespace YjsCrdtSharp.Core
{
    /// <summary>
    /// Hybrid Logical Clock for causality tracking and ordering
    /// Combines physical time, logical counter, and node ID
    /// </summary>
    public readonly struct HLC : IComparable<HLC>, IEquatable<HLC>
    {
        /// <summary>Physical timestamp in milliseconds since Unix epoch</summary>
        public long PhysicalTime { get; }
        
        /// <summary>Logical counter for events within same millisecond</summary>
        public int LogicalCounter { get; }
        
        /// <summary>Node identifier (GUID v4 for clients, custom for servers)</summary>
        public string NodeId { get; }
        
        // Static factory methods
        public static HLC Now(string nodeId);
        public HLC Increment();
        public HLC ReceiveEvent(HLC other);
        
        // Comparison methods
        public bool HappensBefore(HLC other);
        public bool HappensAfter(HLC other);
        public int CompareTo(HLC other);
        
        // Serialization
        public Dictionary<string, object> ToJson();
        public static HLC FromJson(Dictionary<string, object> json);
    }
}
```

### 2. Document Container (Doc)

```csharp
namespace YjsCrdtSharp.Core
{
    /// <summary>
    /// Main document container managing CRDT types and synchronization
    /// Thread-safe for concurrent server operations
    /// </summary>
    public class Doc : IDisposable
    {
        private readonly ConcurrentDictionary<string, IAbstractType> _sharedTypes;
        private readonly ConcurrentDictionary<string, HLC> _hlcVector;
        private readonly List<Operation> _operationHistory;
        private readonly ReaderWriterLockSlim _historyLock;
        private HLC _currentHLC;
        
        public string NodeId { get; }
        public int ClientID { get; } // Legacy compatibility
        
        // Constructors
        public Doc(string? nodeId = null, int? clientId = null);
        public static Doc WithClientId(int clientId);
        
        // HLC operations
        public HLC GetCurrentHLC();
        public HLC NextHLC();
        public Dictionary<string, HLC> GetHLCVector();
        public void UpdateHLCVector(string nodeId, HLC hlc);
        
        // CRDT type management
        public void Share<T>(string key, T type) where T : IAbstractType;
        public T? Get<T>(string key) where T : class, IAbstractType;
        
        // Synchronization
        public Dictionary<string, object> GetUpdateSince(Dictionary<int, int> remoteState);
        public Dictionary<string, object> GetUpdateSince(Dictionary<string, HLC> remoteHLCState);
        public void ApplyUpdate(Dictionary<string, object> update);
        public Dictionary<string, object> CreateSnapshot();
        public Dictionary<string, object> GetUpdateSinceSnapshot(Dictionary<string, object> snapshot);
        
        // Serialization
        public Dictionary<string, object> ToJson();
        public static Doc FromJson(Dictionary<string, object> json);
        
        // Transactions
        public void Transact(Action<Transaction> action);
        public Task TransactAsync(Func<Transaction, Task> action);
    }
}
```

### 3. Abstract CRDT Type Interface

```csharp
namespace YjsCrdtSharp.Types
{
    /// <summary>
    /// Base interface for all CRDT types
    /// </summary>
    public interface IAbstractType
    {
        Doc? Document { get; set; }
        Dictionary<string, object> ToJson();
        void ApplyRemoteOperation(Dictionary<string, object> operation);
        IAbstractType Clone();
    }
    
    /// <summary>
    /// Base class for CRDT types with common functionality
    /// </summary>
    public abstract class AbstractType : IAbstractType
    {
        protected Doc? _document;
        protected readonly object _lock = new object();
        
        public Doc? Document 
        { 
            get => _document; 
            set => _document = value; 
        }
        
        public abstract Dictionary<string, object> ToJson();
        public abstract void ApplyRemoteOperation(Dictionary<string, object> operation);
        public abstract IAbstractType Clone();
        
        protected void AddOperation(string type, Dictionary<string, object> data)
        {
            // Thread-safe operation recording
        }
    }
}
```

### 4. YMap Implementation

```csharp
namespace YjsCrdtSharp.Types
{
    /// <summary>
    /// Collaborative Map CRDT with last-write-wins semantics
    /// Thread-safe for concurrent access
    /// </summary>
    public class YMap : AbstractType, IDictionary<string, object>
    {
        private readonly ConcurrentDictionary<string, object> _items;
        private readonly ConcurrentDictionary<string, HLC> _keyTimestamps;
        
        public YMap();
        
        // IDictionary implementation
        public object this[string key] { get; set; }
        public void Add(string key, object value);
        public bool Remove(string key);
        public bool TryGetValue(string key, out object value);
        public bool ContainsKey(string key);
        public void Clear();
        
        // CRDT operations
        public void Set(string key, object value);
        public T? Get<T>(string key);
        public bool Has(string key);
        public void Delete(string key);
        
        // Collection properties
        public int Count { get; }
        public ICollection<string> Keys { get; }
        public ICollection<object> Values { get; }
        public ICollection<KeyValuePair<string, object>> Entries { get; }
        
        // Serialization
        public override Dictionary<string, object> ToJson();
        public static YMap FromJson(Dictionary<string, object> json);
        
        // CRDT operations
        public override void ApplyRemoteOperation(Dictionary<string, object> operation);
        public override IAbstractType Clone();
    }
}
```

### 5. YArray Implementation

```csharp
namespace YjsCrdtSharp.Types
{
    /// <summary>
    /// Collaborative Array CRDT preserving insertion order
    /// Uses internal linked list for efficient concurrent insertions
    /// </summary>
    public class YArray<T> : AbstractType, IList<T>
    {
        private readonly List<ArrayItem<T>> _items;
        private readonly ReaderWriterLockSlim _itemsLock;
        
        public YArray();
        public static YArray<T> From(IEnumerable<T> items);
        
        // IList implementation
        public T this[int index] { get; set; }
        public void Insert(int index, T item);
        public void RemoveAt(int index);
        public void Add(T item);
        public bool Remove(T item);
        public void Clear();
        
        // CRDT-specific operations
        public void Push(T item);
        public void PushAll(IEnumerable<T> items);
        public void InsertAll(int index, IEnumerable<T> items);
        public void Delete(int index, int length = 1);
        public T? Get(int index);
        
        // Collection properties
        public int Count { get; }
        public bool IsReadOnly => false;
        
        // Iteration
        public void ForEach(Action<T, int> action);
        public IEnumerable<U> Map<U>(Func<T, int, U> selector);
        
        // Conversion
        public List<T> ToList();
        public override Dictionary<string, object> ToJson();
        public static YArray<T> FromJson(Dictionary<string, object> json);
        
        // CRDT operations
        public override void ApplyRemoteOperation(Dictionary<string, object> operation);
        public override IAbstractType Clone();
    }
    
    /// <summary>
    /// Internal array item with metadata for CRDT operations
    /// </summary>
    internal class ArrayItem<T>
    {
        public T Value { get; set; }
        public HLC Timestamp { get; set; }
        public bool IsDeleted { get; set; }
        public string OriginNodeId { get; set; }
    }
}
```

### 6. YText Implementation

```csharp
namespace YjsCrdtSharp.Types
{
    /// <summary>
    /// Collaborative Text CRDT for character-level editing
    /// Supports concurrent text operations with conflict resolution
    /// </summary>
    public class YText : AbstractType
    {
        private readonly List<TextItem> _items;
        private readonly ReaderWriterLockSlim _itemsLock;
        
        public YText(string? initialContent = null);
        
        // Text operations
        public void Insert(int index, string text);
        public void Delete(int index, int length);
        public char CharAt(int index);
        public string Substring(int start, int length);
        
        // Properties
        public int Length { get; }
        
        // Conversion
        public override string ToString();
        public override Dictionary<string, object> ToJson();
        public static YText FromJson(Dictionary<string, object> json);
        
        // CRDT operations
        public override void ApplyRemoteOperation(Dictionary<string, object> operation);
        public override IAbstractType Clone();
    }
    
    /// <summary>
    /// Internal text item for CRDT operations
    /// </summary>
    internal class TextItem
    {
        public char Character { get; set; }
        public HLC Timestamp { get; set; }
        public bool IsDeleted { get; set; }
        public string OriginNodeId { get; set; }
    }
}
```

### 7. Counter CRDTs

```csharp
namespace YjsCrdtSharp.Counters
{
    /// <summary>
    /// G-Counter (Grow-only Counter) CRDT
    /// Thread-safe increment-only counter
    /// </summary>
    public class GCounter
    {
        private readonly ConcurrentDictionary<int, long> _state;
        
        public GCounter();
        public GCounter(Dictionary<int, long> initialState);
        
        public long Value { get; }
        
        public void Increment(int clientId, long amount = 1);
        public void Merge(GCounter other);
        public Dictionary<int, long> GetState();
        
        // Serialization
        public Dictionary<string, object> ToJson();
        public static GCounter FromJson(Dictionary<string, object> json);
        
        // Thread-safe operations
        public GCounter Clone();
    }
    
    /// <summary>
    /// PN-Counter (Positive-Negative Counter) CRDT
    /// Thread-safe increment/decrement counter
    /// </summary>
    public class PNCounter
    {
        private readonly GCounter _positiveCounter;
        private readonly GCounter _negativeCounter;
        
        public PNCounter();
        public PNCounter(Dictionary<int, long> positiveState, Dictionary<int, long> negativeState);
        
        public long Value { get; }
        
        public void Increment(int clientId, long amount = 1);
        public void Decrement(int clientId, long amount = 1);
        public void Add(int clientId, long amount);
        public void Merge(PNCounter other);
        
        // Serialization
        public Dictionary<string, object> ToJson();
        public static PNCounter FromJson(Dictionary<string, object> json);
        
        // Thread-safe operations
        public PNCounter Clone();
    }
}
```

### 8. Binary Encoding

```csharp
namespace YjsCrdtSharp.Encoding
{
    /// <summary>
    /// Binary encoder for efficient document serialization
    /// Compatible with Dart binary format
    /// </summary>
    public static class BinaryEncoder
    {
        // Type constants matching Dart implementation
        private const byte TYPE_DOC = 0;
        private const byte TYPE_YMAP = 1;
        private const byte TYPE_YARRAY = 2;
        private const byte TYPE_YTEXT = 3;
        private const byte TYPE_GCOUNTER = 4;
        private const byte TYPE_PNCOUNTER = 5;
        
        public static byte[] EncodeDocument(Doc document);
        public static Doc DecodeDocument(byte[] data);
        public static byte[] EncodeValue(object value);
        public static object DecodeValue(ReadOnlySpan<byte> data, ref int position);
        
        public static Dictionary<string, int> CompareSizes(Doc document);
    }
    
    /// <summary>
    /// Binary reader helper for decoding operations
    /// </summary>
    internal class BinaryReader
    {
        private readonly ReadOnlySpan<byte> _data;
        private int _position;
        
        public BinaryReader(ReadOnlySpan<byte> data);
        
        public byte ReadByte();
        public int ReadInt32();
        public long ReadInt64();
        public string ReadString();
        public T ReadValue<T>();
    }
}
```

### 9. Transaction System

```csharp
namespace YjsCrdtSharp.Core
{
    /// <summary>
    /// Transaction context for batching CRDT operations
    /// Ensures atomic updates and proper HLC management
    /// </summary>
    public class Transaction : IDisposable
    {
        private readonly Doc _document;
        private readonly List<Operation> _operations;
        private bool _isCommitted;
        private bool _isDisposed;
        
        internal Transaction(Doc document);
        
        public void AddOperation(Operation operation);
        public void Commit();
        public void Rollback();
        public void Dispose();
        
        // Properties
        public Doc Document { get; }
        public IReadOnlyList<Operation> Operations { get; }
        public bool IsCommitted { get; }
    }
    
    /// <summary>
    /// Individual CRDT operation for history tracking
    /// </summary>
    public class Operation
    {
        public HLC Timestamp { get; set; }
        public string NodeId { get; set; }
        public string Type { get; set; }
        public string Target { get; set; }
        public Dictionary<string, object> Data { get; set; }
        
        public Dictionary<string, object> ToJson();
        public static Operation FromJson(Dictionary<string, object> json);
    }
}
```

## Protocol Compatibility

### JSON Serialization Format

All JSON serialization must match the Dart format exactly:

```json
{
  "nodeId": "string",
  "hlc": {
    "physicalTime": 1234567890123,
    "logicalCounter": 0,
    "nodeId": "string"
  },
  "shared": {
    "key1": {
      "type": "YMap",
      "data": { /* YMap data */ }
    },
    "key2": {
      "type": "YArray",
      "data": [ /* YArray data */ ]
    }
  }
}
```

### Update Protocol Format

```json
{
  "type": "delta_update",
  "nodeId": "string",
  "hlc_vector": {
    "node1": { "physicalTime": 123, "logicalCounter": 0, "nodeId": "node1" },
    "node2": { "physicalTime": 124, "logicalCounter": 1, "nodeId": "node2" }
  },
  "operations": [
    {
      "type": "map_set",
      "target": "key",
      "key": "field",
      "value": "data",
      "hlc": { /* HLC data */ }
    }
  ]
}
```

### Binary Protocol

Binary encoding must match byte-for-byte with Dart implementation:
- Little-endian integer encoding
- UTF-8 string encoding with length prefix
- Type tags matching exactly
- Version compatibility headers

## Implementation Guidelines

### 1. Thread Safety
- Use `ConcurrentDictionary<TKey, TValue>` for shared collections
- `ReaderWriterLockSlim` for complex read/write scenarios
- `Interlocked` operations for simple atomic updates
- `lock` statements for critical sections

### 2. Memory Management
- Implement `IDisposable` for resource cleanup
- Use object pooling for frequently allocated objects
- Weak references where appropriate to prevent memory leaks
- Explicit cleanup of event handlers

### 3. Error Handling
- Custom exception types for CRDT-specific errors
- Validation at API boundaries
- Graceful degradation for partial failures
- Comprehensive logging for debugging

### 4. Performance Considerations
- Lazy initialization of collections
- Efficient diff algorithms for synchronization
- Batch processing for multiple operations
- Memory-efficient data structures

### 5. Testing Requirements
- Unit tests for all CRDT operations
- Integration tests with Dart client
- Concurrent access testing
- Performance benchmarks
- Protocol compatibility tests

## Dependencies and Package Structure

### Package Structure
```
YjsCrdtSharp/
├── YjsCrdtSharp.csproj
├── Core/
│   ├── Doc.cs
│   ├── HLC.cs
│   ├── ID.cs
│   └── Transaction.cs
├── Types/
│   ├── AbstractType.cs
│   ├── YMap.cs
│   ├── YArray.cs
│   └── YText.cs
├── Counters/
│   ├── GCounter.cs
│   └── PNCounter.cs
├── Encoding/
│   ├── BinaryEncoder.cs
│   └── JsonSerializer.cs
└── Extensions/
    ├── GuidExtensions.cs
    └── DictionaryExtensions.cs
```

### Project File (.csproj)
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
    <Nullable>enable</Nullable>
    <LangVersion>8.0</LangVersion>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
    <PackageId>YjsCrdtSharp</PackageId>
    <Version>0.1.0</Version>
    <Authors>YjsCRDT Contributors</Authors>
    <Description>Pure C# implementation of Y.js CRDT data structures</Description>
    <PackageTags>crdt;yjs;collaboration;offline-first</PackageTags>
  </PropertyGroup>
  
  <ItemGroup>
    <PackageReference Include="System.Text.Json" Version="6.0.0" />
  </ItemGroup>
</Project>
```

## API Usage Examples

### Basic Document Usage
```csharp
// Create document
var doc = new Doc();

// Create and share YMap
var map = new YMap();
doc.Share("myMap", map);

map.Set("name", "Alice");
map.Set("age", 30);

// Serialize
var json = doc.ToJson();
var binary = BinaryEncoder.EncodeDocument(doc);
```

### Server Synchronization
```csharp
// Server-side document management
var serverDoc = new Doc(nodeId: "server-1");
var serverMap = new YMap();
serverDoc.Share("document", serverMap);

// Client connects and requests initial state
var initialUpdate = serverDoc.GetUpdateSince(new Dictionary<int, int>());
// Send initialUpdate to client

// Client sends changes
var clientUpdate = /* received from client */;
serverDoc.ApplyUpdate(clientUpdate);

// Broadcast to other clients
var broadcastUpdate = serverDoc.GetUpdateSince(clientState);
```

### Counter Usage
```csharp
var progress = new GCounter();
var hours = new PNCounter();

// Multiple clients increment
progress.Increment(client1Id, 25);
progress.Increment(client2Id, 15);

hours.Increment(client1Id, 8);
hours.Decrement(client1Id, 1); // Correction

// Merge from other nodes
progress.Merge(remoteProgress);
hours.Merge(remoteHours);
```

## Testing Strategy

### Unit Test Structure
```csharp
[TestClass]
public class YMapTests
{
    [TestMethod]
    public void SetAndGet_ShouldStoreAndRetrieveValues()
    {
        var map = new YMap();
        map.Set("key", "value");
        Assert.AreEqual("value", map.Get<string>("key"));
    }
    
    [TestMethod]
    public void ConcurrentOperations_ShouldBeThreadSafe()
    {
        var map = new YMap();
        var tasks = new Task[100];
        
        for (int i = 0; i < 100; i++)
        {
            int index = i;
            tasks[i] = Task.Run(() => map.Set($"key{index}", $"value{index}"));
        }
        
        Task.WaitAll(tasks);
        Assert.AreEqual(100, map.Count);
    }
}
```

### Integration Tests
- Cross-platform protocol compatibility
- Multi-client synchronization scenarios
- Performance under load
- Memory usage patterns
- Error recovery scenarios

This specification provides a complete blueprint for creating a C# CRDT library that is fully compatible with the Dart implementation while optimized for server-side usage patterns.