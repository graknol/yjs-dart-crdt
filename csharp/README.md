# Y.js CRDT Sharp - C# Implementation

A pure C# implementation of Y.js core CRDT (Conflict-free Replicated Data Type) data structures for offline-first applications and server synchronization. This library is fully compatible with the Dart implementation for client-server scenarios.

## Features

- **YMap**: Collaborative map/dictionary with last-write-wins semantics
- **GCounter**: Grow-only counter for collaborative increment operations
- **PNCounter**: Positive-negative counter supporting increment/decrement
- **Hybrid Logical Clocks**: Advanced causality tracking with millisecond precision
- **Thread-Safe Operations**: All CRDT operations are thread-safe for server environments
- **Protocol Compatibility**: JSON and binary serialization compatible with Dart client
- **Pure C# Implementation**: No external dependencies except .NET Standard libraries
- **Server Optimized**: Designed for high-concurrency server scenarios

## Quick Start

### Installation

```bash
dotnet add package YjsCrdtSharp
```

### Basic Usage

```csharp
using YjsCrdtSharp.Core;
using YjsCrdtSharp.Types;
using YjsCrdtSharp.Counters;

// Create a collaborative map
var map = new YMap();
map.Set("name", "Alice");
map.Set("age", 30);

Console.WriteLine($"Name: {map.Get<string>("name")}");
Console.WriteLine($"Age: {map.Get<int>("age")}");

// Use counters for collaborative metrics
var progress = new GCounter();
progress.Increment(clientId: 1, amount: 25);
progress.Increment(clientId: 2, amount: 35);

Console.WriteLine($"Total progress: {progress.Value}%");

// Merge with counters from other nodes
var otherProgress = new GCounter();
otherProgress.Increment(clientId: 3, amount: 20);
progress.Merge(otherProgress);

Console.WriteLine($"After merge: {progress.Value}%");
```

### Server Synchronization Example

```csharp
// Server setup
var serverMap = new YMap();
serverMap.Set("document", "Collaborative Document");

var serverProgress = new GCounter();
serverProgress.Increment(0, 10); // Server baseline

// Client simulation
var clientProgress = new GCounter();
clientProgress.Increment(1, 25); // Client 1 contribution
clientProgress.Increment(2, 35); // Client 2 contribution

// Server merges client updates
serverProgress.Merge(clientProgress);
Console.WriteLine($"Final progress: {serverProgress.Value}%"); // 70%

// Serialization for network transfer
var json = serverProgress.ToJson();
var restored = GCounter.FromJson(json);
```

## API Reference

### HLC (Hybrid Logical Clock)

```csharp
// Create HLC with current time
var hlc = HLC.Now("node-id");

// Increment for new event
var nextHLC = hlc.Increment();

// Receive event from another node
var receivedHLC = hlc.ReceiveEvent(remoteHLC);

// Compare causality
if (hlc1.HappensBefore(hlc2)) {
    Console.WriteLine("hlc1 happened before hlc2");
}
```

### YMap - Collaborative Dictionary

```csharp
var map = new YMap();

// Basic operations
map.Set("key", "value");
var value = map.Get<string>("key");
bool exists = map.Has("key");
map.Delete("key");

// Collection operations
map.Clear();
Console.WriteLine($"Count: {map.Count}");

// Nested CRDT types
var nestedCounter = new GCounter();
nestedCounter.Increment(1, 10);
map.Set("progress", nestedCounter);

// JSON serialization
var json = map.ToJson();
var restored = YMap.FromJson(json);
```

### GCounter - Grow-Only Counter

```csharp
var counter = new GCounter();

// Increment operations
counter.Increment(clientId: 1, amount: 5);
counter.Increment(clientId: 2, amount: 10);

Console.WriteLine($"Total: {counter.Value}"); // 15

// Merge with other counters
var other = new GCounter();
other.Increment(3, 7);
counter.Merge(other);

Console.WriteLine($"After merge: {counter.Value}"); // 22

// Serialization
var json = counter.ToJson();
var restored = GCounter.FromJson(json);
```

### PNCounter - Increment/Decrement Counter

```csharp
var counter = new PNCounter();

// Operations
counter.Increment(clientId: 1, amount: 10);
counter.Decrement(clientId: 1, amount: 3);
counter.Add(clientId: 2, amount: 5);    // Positive
counter.Add(clientId: 2, amount: -2);   // Negative

Console.WriteLine($"Net value: {counter.Value}"); // 10

// Merge operations
counter.Merge(otherCounter);

// Serialization
var json = counter.ToJson();
var restored = PNCounter.FromJson(json);
```

## Architecture

### Thread Safety

All CRDT operations are thread-safe using:
- `ConcurrentDictionary<TKey, TValue>` for shared collections
- `ReaderWriterLockSlim` for complex read/write scenarios
- Atomic operations where appropriate

### Memory Management

- Implements `IDisposable` for resource cleanup
- Efficient object reuse patterns
- Minimal allocation overhead

### Protocol Compatibility

Maintains full compatibility with the Dart implementation:
- JSON serialization format matches exactly
- Binary encoding protocol (future implementation)
- HLC vector synchronization
- Operation ordering and conflict resolution

## Examples

### Running Examples

```bash
cd csharp/YjsCrdtSharp.Examples
dotnet run
```

### Running Tests

```bash
cd csharp/YjsCrdtSharp.Tests
dotnet test
```

### Building the Library

```bash
cd csharp/YjsCrdtSharp
dotnet build
dotnet pack
```

## Advanced Usage

### Server Integration

```csharp
public class DocumentService
{
    private readonly ConcurrentDictionary<string, YMap> _documents = new();
    
    public void UpdateDocument(string documentId, Dictionary<string, object> clientUpdate)
    {
        var document = _documents.GetOrAdd(documentId, _ => new YMap());
        
        // Apply client updates
        foreach (var change in clientUpdate)
        {
            document.Set(change.Key, change.Value);
        }
        
        // Broadcast to other clients...
    }
    
    public Dictionary<string, object> GetDocument(string documentId)
    {
        if (_documents.TryGetValue(documentId, out var document))
        {
            return document.ToJson();
        }
        return new Dictionary<string, object>();
    }
}
```

### ASP.NET Core Integration

```csharp
[ApiController]
[Route("api/[controller]")]
public class CrdtController : ControllerBase
{
    private readonly DocumentService _documentService;
    
    [HttpPost("documents/{id}/update")]
    public IActionResult UpdateDocument(string id, [FromBody] Dictionary<string, object> update)
    {
        _documentService.UpdateDocument(id, update);
        return Ok();
    }
    
    [HttpGet("documents/{id}")]
    public ActionResult<Dictionary<string, object>> GetDocument(string id)
    {
        return _documentService.GetDocument(id);
    }
}
```

## Requirements

- .NET Standard 2.1+
- .NET Core 3.1+ or .NET 5+
- C# 8.0+ (nullable reference types)

## Contributing

This implementation follows the same CRDT algorithms as the Dart version. When contributing:

1. Maintain protocol compatibility with Dart implementation
2. Ensure thread safety for all operations
3. Add comprehensive unit tests
4. Follow C# coding conventions
5. Update documentation for API changes

## License

MIT License - see LICENSE file for details.

## Compatibility

This C# implementation is designed to be fully compatible with:
- Dart Y.js CRDT client library
- Y.js JavaScript implementation (JSON protocol)
- Any system implementing the same CRDT algorithms