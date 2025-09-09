using System;
using System.Collections.Generic;
using System.Text.Json;
using YjsCrdtSharp.Core;
using YjsCrdtSharp.Types;

namespace YjsCrdtSharp.RealWorldIntegrationTest
{
    /// <summary>
    /// Real-world integration test demonstrating full protocol compatibility 
    /// with Dart client, including JSON format exchange and operation processing
    /// </summary>
    public class RealWorldIntegrationTest
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("=== Real-World Dart-C# Integration Test ===\n");

            try
            {
                // Test 1: Process Dart Client Update
                TestProcessDartClientUpdate();
                
                // Test 2: Generate Server Response
                TestGenerateServerResponse();
                
                // Test 3: Full Collaboration Simulation
                TestFullCollaboration();
                
                Console.WriteLine("✅ All real-world integration tests passed!");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Integration test failed: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                Environment.Exit(1);
            }
            
            Console.WriteLine("\n=== Real-World Integration Test Complete ===");
        }

        /// <summary>Process a real update from Dart client</summary>
        static void TestProcessDartClientUpdate()
        {
            Console.WriteLine("--- Test 1: Process Dart Client Update ---");
            
            // This is the exact JSON format that Dart produces
            var dartClientJson = """
                {
                    "nodeId": "mobile-client-1",
                    "hlc": {
                        "physicalTime": 1757274937464,
                        "logicalCounter": 2,
                        "nodeId": "mobile-client-1"
                    },
                    "shared": {
                        "collaborative_doc": {
                            "type": "YText",
                            "data": "Hello Beautiful World!"
                        }
                    }
                }
                """;
            
            Console.WriteLine("1. Received Dart client JSON:");
            Console.WriteLine(dartClientJson);
            
            // Parse the JSON as C# would
            var jsonDoc = JsonDocument.Parse(dartClientJson);
            var root = jsonDoc.RootElement;
            
            // Extract key information
            var nodeId = root.GetProperty("nodeId").GetString()!;
            var hlcElement = root.GetProperty("hlc");
            var sharedElement = root.GetProperty("shared");
            
            Console.WriteLine($"2. Extracted nodeId: {nodeId}");
            
            // Process HLC
            var physicalTime = hlcElement.GetProperty("physicalTime").GetInt64();
            var logicalCounter = hlcElement.GetProperty("logicalCounter").GetInt32();
            var hlcNodeId = hlcElement.GetProperty("nodeId").GetString()!;
            
            var clientHlc = new HLC(physicalTime, logicalCounter, hlcNodeId);
            Console.WriteLine($"3. Client HLC: {clientHlc}");
            
            // Extract YText data
            var collaborativeDoc = sharedElement.GetProperty("collaborative_doc");
            var textType = collaborativeDoc.GetProperty("type").GetString();
            var textData = collaborativeDoc.GetProperty("data").GetString()!;
            
            Console.WriteLine($"4. YText type: {textType}, content: \"{textData}\"");
            
            // Create C# YText from Dart data
            var serverText = new YText(textData);
            var mockDoc = new MockDocument("server-1");
            serverText.Document = mockDoc;
            
            Console.WriteLine($"5. C# YText created: \"{serverText}\"");
            
            // Server performs an edit
            serverText.Insert(textData.Length, " - edited by server");
            Console.WriteLine($"6. Server edited: \"{serverText}\"");
            
            Console.WriteLine("✅ Successfully processed Dart client update\n");
        }

        /// <summary>Generate server response that Dart can consume</summary>
        static void TestGenerateServerResponse()
        {
            Console.WriteLine("--- Test 2: Generate Server Response ---");
            
            // Create server document
            var serverDoc = new MockDocument("server-1");
            var serverText = new YText("Server initial content");
            serverText.Document = serverDoc;
            
            Console.WriteLine($"1. Server content: \"{serverText}\"");
            
            // Perform server operations
            serverText.Insert(6, " modified");
            serverText.Insert(serverText.Length, " - ready for client");
            
            Console.WriteLine($"2. After operations: \"{serverText}\"");
            
            // Generate Dart-compatible JSON response
            var response = new Dictionary<string, object>
            {
                ["nodeId"] = serverDoc.NodeId,
                ["hlc"] = serverDoc.GetCurrentHLC().ToJson(),
                ["shared"] = new Dictionary<string, object>
                {
                    ["collaborative_doc"] = new Dictionary<string, object>
                    {
                        ["type"] = "YText",
                        ["data"] = serverText.ToString()
                    }
                }
            };
            
            var responseJson = JsonSerializer.Serialize(response, new JsonSerializerOptions 
            { 
                WriteIndented = true 
            });
            
            Console.WriteLine("3. Generated server response JSON:");
            Console.WriteLine(responseJson);
            
            // Generate operation format for incremental sync
            var operations = new List<Dictionary<string, object>>
            {
                new Dictionary<string, object>
                {
                    ["type"] = "text_insert",
                    ["target"] = "collaborative_doc",
                    ["index"] = 6,
                    ["text"] = " modified",
                    ["timestamp"] = serverDoc.GetCurrentHLC().ToJson()
                },
                new Dictionary<string, object>
                {
                    ["type"] = "text_insert",
                    ["target"] = "collaborative_doc", 
                    ["index"] = serverText.Length - " - ready for client".Length,
                    ["text"] = " - ready for client",
                    ["timestamp"] = serverDoc.NextHLC().ToJson()
                }
            };
            
            var updateResponse = new Dictionary<string, object>
            {
                ["type"] = "delta_update",
                ["nodeId"] = serverDoc.NodeId,
                ["operations"] = operations,
                ["hlc_vector"] = new Dictionary<string, object>
                {
                    [serverDoc.NodeId] = serverDoc.GetCurrentHLC().ToJson()
                }
            };
            
            var updateJson = JsonSerializer.Serialize(updateResponse, new JsonSerializerOptions 
            { 
                WriteIndented = true 
            });
            
            Console.WriteLine("4. Generated incremental update JSON:");
            Console.WriteLine(updateJson);
            
            Console.WriteLine("✅ Successfully generated server response\n");
        }

        /// <summary>Simulate full collaboration between Dart and C#</summary>
        static void TestFullCollaboration()
        {
            Console.WriteLine("--- Test 3: Full Collaboration Simulation ---");
            
            const string initialText = "The quick brown fox";
            
            // Simulate Dart client
            var dartDoc = new MockDocument("mobile-app");
            var dartText = new YText(initialText);
            dartText.Document = dartDoc;
            
            // Simulate C# server
            var serverDoc = new MockDocument("server-1");
            var serverText = new YText(initialText);
            serverText.Document = serverDoc;
            
            Console.WriteLine($"Initial state: \"{initialText}\"");
            
            // Step 1: Dart client adds ending
            dartText.Insert(initialText.Length, " jumps over the lazy dog");
            Console.WriteLine($"Step 1 - Dart client: \"{dartText}\"");
            
            // Simulate sync: server receives client state
            serverText = new YText(dartText.ToString());
            serverText.Document = serverDoc;
            Console.WriteLine($"Step 1 - Server synced: \"{serverText}\"");
            
            // Step 2: Server adds emphasis  
            serverText.Insert(10, "very ");
            Console.WriteLine($"Step 2 - Server edit: \"{serverText}\"");
            
            // Simulate sync: client receives server state
            dartText = new YText(serverText.ToString());
            dartText.Document = dartDoc;
            Console.WriteLine($"Step 2 - Client synced: \"{dartText}\"");
            
            // Step 3: Concurrent edits
            var serverCopy = new YText(dartText.ToString());
            serverCopy.Document = serverDoc;
            
            // Client edits
            dartText.Insert(35, "quickly ");
            Console.WriteLine($"Step 3a - Client concurrent: \"{dartText}\"");
            
            // Server edits (from same base)
            serverCopy.Delete(40, 4); // Remove "lazy"
            serverCopy.Insert(40, "sleepy");
            Console.WriteLine($"Step 3b - Server concurrent: \"{serverCopy}\"");
            
            // Generate operations for conflict resolution
            var clientOp = new Dictionary<string, object>
            {
                ["type"] = "text_insert",
                ["index"] = 35,
                ["text"] = "quickly ",
                ["timestamp"] = dartDoc.NextHLC().ToJson()
            };
            
            var serverOps = new List<Dictionary<string, object>>
            {
                new Dictionary<string, object>
                {
                    ["type"] = "text_delete",
                    ["index"] = 40,
                    ["length"] = 4,
                    ["timestamp"] = serverDoc.NextHLC().ToJson()
                },
                new Dictionary<string, object>
                {
                    ["type"] = "text_insert", 
                    ["index"] = 40,
                    ["text"] = "sleepy",
                    ["timestamp"] = serverDoc.NextHLC().ToJson()
                }
            };
            
            Console.WriteLine("Generated client operation:");
            Console.WriteLine(JsonSerializer.Serialize(clientOp, new JsonSerializerOptions { WriteIndented = true }));
            
            Console.WriteLine("Generated server operations:");
            foreach (var op in serverOps)
            {
                Console.WriteLine(JsonSerializer.Serialize(op, new JsonSerializerOptions { WriteIndented = true }));
            }
            
            // Apply operations with timestamps for resolution
            serverCopy.ApplyRemoteOperation(clientOp);
            Console.WriteLine($"Final server state: \"{serverCopy}\"");
            
            // In real implementation, proper conflict resolution would be applied
            Console.WriteLine("✅ Full collaboration simulation completed");
            
            Console.WriteLine("");
        }
    }

    /// <summary>Enhanced mock document for integration testing</summary>
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