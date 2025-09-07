using System;
using System.Collections.Generic;
using System.Text.Json;
using YjsCrdtSharp.Core;
using YjsCrdtSharp.Types;

namespace YjsCrdtSharp.IntegrationTest
{
    /// <summary>
    /// Integration test simulating collaboration between Dart client and C# server
    /// Demonstrates YText collaborative editing with serialization/deserialization
    /// </summary>
    public class DartCSharpIntegrationTest
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("=== Dart-C# CRDT Integration Test ===\n");
            
            // Test 1: Basic YText Collaboration
            TestBasicYTextCollaboration();
            
            // Test 2: Concurrent Editing Scenario
            TestConcurrentEditing();
            
            // Test 3: Serialization Compatibility
            TestSerializationCompatibility();
            
            Console.WriteLine("\n=== All Integration Tests Completed ===");
        }

        /// <summary>Test basic YText collaboration between simulated Dart and C# instances</summary>
        static void TestBasicYTextCollaboration()
        {
            Console.WriteLine("--- Test 1: Basic YText Collaboration ---");
            
            // Simulate C# server instance
            var serverText = new YText("Hello ");
            serverText.Document = new MockDocument("server-1");
            
            // Simulate Dart client instance
            var clientText = new YText("World");
            clientText.Document = new MockDocument("client-1");
            
            Console.WriteLine($"Server initial: '{serverText}'");
            Console.WriteLine($"Client initial: '{clientText}'");
            
            // Server performs edit
            serverText.Insert(6, "beautiful ");
            Console.WriteLine($"Server after edit: '{serverText}'");
            
            // Serialize server state
            var serverJson = serverText.ToJson();
            Console.WriteLine($"Server JSON: {JsonSerializer.Serialize(serverJson, new JsonSerializerOptions { WriteIndented = true })}");
            
            // Client applies server's changes
            var clientFromServer = YText.FromJson(serverJson);
            Console.WriteLine($"Client after applying server changes: '{clientFromServer}'");
            
            // Client performs edit
            clientText.Insert(5, "!");
            Console.WriteLine($"Client after local edit: '{clientText}'");
            
            Console.WriteLine();
        }

        /// <summary>Test concurrent editing scenario with conflict resolution</summary>
        static void TestConcurrentEditing()
        {
            Console.WriteLine("--- Test 2: Concurrent Editing Scenario ---");
            
            // Start with same base text
            var baseText = "The quick brown fox jumps over the lazy dog.";
            
            var serverText = new YText(baseText);
            serverText.Document = new MockDocument("server-1");
            
            var clientText = new YText(baseText);
            clientText.Document = new MockDocument("client-1");
            
            Console.WriteLine($"Base text: '{baseText}'");
            
            // Concurrent edits
            // Server: Insert at position 10
            serverText.Insert(10, "very ");
            Console.WriteLine($"Server concurrent edit: '{serverText}'");
            
            // Client: Insert at position 35 (in original positions)
            clientText.Insert(35, "quickly ");
            Console.WriteLine($"Client concurrent edit: '{clientText}'");
            
            // Exchange operations
            var serverOp = new Dictionary<string, object>
            {
                ["type"] = "text_insert",
                ["index"] = 10,
                ["text"] = "very ",
                ["timestamp"] = serverText.Document!.GetCurrentHLC().ToJson()
            };
            
            var clientOp = new Dictionary<string, object>
            {
                ["type"] = "text_insert", 
                ["index"] = 35,
                ["text"] = "quickly ",
                ["timestamp"] = clientText.Document!.GetCurrentHLC().ToJson()
            };
            
            // Apply operations
            clientText.ApplyRemoteOperation(serverOp);
            serverText.ApplyRemoteOperation(clientOp);
            
            Console.WriteLine($"Final server state: '{serverText}'");
            Console.WriteLine($"Final client state: '{clientText}'");
            
            Console.WriteLine();
        }

        /// <summary>Test serialization compatibility with expected Dart format</summary>
        static void TestSerializationCompatibility()
        {
            Console.WriteLine("--- Test 3: Serialization Compatibility ---");
            
            var text = new YText("Hello");
            text.Document = new MockDocument("test-node");
            text.Insert(5, " World!");
            
            var json = text.ToJson();
            Console.WriteLine($"C# YText JSON: {JsonSerializer.Serialize(json, new JsonSerializerOptions { WriteIndented = true })}");
            
            // Test deserialization
            var recreated = YText.FromJson(json);
            Console.WriteLine($"Recreated from JSON: '{recreated}'");
            
            // Test with Dart-compatible format
            var dartCompatibleJson = new Dictionary<string, object>
            {
                ["type"] = "YText",
                ["text"] = "Hello from Dart!"
            };
            
            var fromDart = YText.FromJson(dartCompatibleJson);
            Console.WriteLine($"From Dart format: '{fromDart}'");
            
            Console.WriteLine();
        }
    }

    /// <summary>Mock document for testing</summary>
    public class MockDocument : IDocument
    {
        private HLC _currentHLC;
        
        public string NodeId { get; }
        public int ClientId => NodeId.GetHashCode();
        
        public MockDocument(string nodeId)
        {
            NodeId = nodeId;
            _currentHLC = HLC.Now(nodeId);
        }
        
        public HLC GetCurrentHLC() => _currentHLC;
        
        public HLC NextHLC()
        {
            _currentHLC = _currentHLC.Increment();
            return _currentHLC;
        }
    }
}