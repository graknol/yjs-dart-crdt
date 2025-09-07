using System;
using System.Collections.Generic;
using YjsCrdtSharp.Core;
using YjsCrdtSharp.Types;
using YjsCrdtSharp.Counters;
using YjsCrdtSharp.Extensions;

namespace YjsCrdtSharp.Examples
{
    /// <summary>
    /// Basic usage examples for Y.js CRDT Sharp library
    /// Demonstrates core CRDT operations and server-client synchronization patterns
    /// </summary>
    public class BasicExample
    {
        public static void RunExample()
        {
            Console.WriteLine("=== Y.js CRDT Sharp Example ===\n");

            // Example 1: HLC (Hybrid Logical Clock) Usage
            Console.WriteLine("--- HLC Example ---");
            var nodeId = GuidExtensions.GenerateGuidV4();
            var hlc1 = HLC.Now(nodeId);
            var hlc2 = hlc1.Increment();
            
            Console.WriteLine($"Initial HLC: {hlc1}");
            Console.WriteLine($"Incremented HLC: {hlc2}");
            Console.WriteLine($"HLC1 happens before HLC2: {hlc1.HappensBefore(hlc2)}");

            // Example 2: YMap usage
            Console.WriteLine("\n--- YMap Example ---");
            var map = new YMap();
            
            map.Set("name", "Alice");
            map.Set("age", 30);
            map.Set("active", true);

            Console.WriteLine($"Map count: {map.Count}");
            Console.WriteLine($"Name: {map.Get<string>("name")}");
            Console.WriteLine($"Age: {map.Get<object>("age")}");
            Console.WriteLine($"Has email: {map.Has("email")}");
            
            // Demonstrate JSON serialization
            var mapJson = map.ToJson();
            Console.WriteLine($"Map as JSON keys: [{string.Join(", ", mapJson.Keys)}]");

            // Example 3: GCounter usage
            Console.WriteLine("\n--- GCounter Example ---");
            var progress = new GCounter();
            
            progress.Increment(1, 25); // Client 1 adds 25%
            progress.Increment(2, 35); // Client 2 adds 35%
            
            Console.WriteLine($"Progress value: {progress.Value}%");
            
            // Merge with another counter
            var otherProgress = new GCounter();
            otherProgress.Increment(3, 20); // Client 3 adds 20%
            progress.Merge(otherProgress);
            
            Console.WriteLine($"After merge: {progress.Value}%");

            // Example 4: PNCounter usage
            Console.WriteLine("\n--- PNCounter Example ---");
            var hours = new PNCounter();
            
            hours.Increment(1, 8);  // Client 1: 8 hours worked
            hours.Decrement(1, 1);  // Client 1: correction -1 hour
            hours.Add(2, 5);        // Client 2: 5 hours
            hours.Add(2, -2);       // Client 2: correction -2 hours
            
            Console.WriteLine($"Total hours: {hours.Value}");

            // Example 5: Nested CRDT structures
            Console.WriteLine("\n--- Nested Types Example ---");
            var projectMap = new YMap();
            var teamProgress = new GCounter();
            var budgetCounter = new PNCounter();
            
            teamProgress.Increment(1, 15);
            teamProgress.Increment(2, 25);
            budgetCounter.Add(1, 10000);  // Initial budget
            budgetCounter.Add(2, -2500);  // Expense
            
            projectMap.Set("name", "Project Alpha");
            projectMap.Set("progress", teamProgress);
            projectMap.Set("budget", budgetCounter);
            
            Console.WriteLine($"Project: {projectMap.Get<string>("name")}");
            Console.WriteLine($"Team progress: {projectMap.Get<GCounter>("progress")?.Value}%");
            Console.WriteLine($"Remaining budget: ${projectMap.Get<PNCounter>("budget")?.Value}");

            // Example 6: Serialization
            Console.WriteLine("\n--- Serialization Example ---");
            var progressJson = progress.ToJson();
            var hoursJson = hours.ToJson();
            
            Console.WriteLine($"Progress JSON type: {progressJson["type"]}");
            Console.WriteLine($"Hours JSON type: {hoursJson["type"]}");
            
            // Deserialize
            var restoredProgress = GCounter.FromJson(progressJson);
            var restoredHours = PNCounter.FromJson(hoursJson);
            
            Console.WriteLine($"Restored progress: {restoredProgress.Value}%");
            Console.WriteLine($"Restored hours: {restoredHours.Value}");
            
            // Verify equality
            Console.WriteLine($"Counters equal after serialization: {progress.Equals(restoredProgress)}");

            Console.WriteLine("\n=== Example Complete ===");
        }
    }
    
    /// <summary>
    /// Advanced example showing server-client synchronization patterns
    /// </summary>
    public class ServerClientExample
    {
        public static void RunExample()
        {
            Console.WriteLine("\n=== Server-Client Synchronization Example ===\n");

            // Server setup
            Console.WriteLine("--- Server Setup ---");
            var serverNodeId = "server-main";
            var serverHLC = HLC.Now(serverNodeId);
            
            var serverMap = new YMap();
            serverMap.Set("document_name", "Collaborative Document");
            serverMap.Set("version", 1);
            
            var serverProgress = new GCounter();
            serverProgress.Increment(0, 10); // Server initial progress
            serverMap.Set("progress", serverProgress);
            
            Console.WriteLine($"Server initialized with HLC: {serverHLC}");
            Console.WriteLine($"Server document: {serverMap.Get<string>("document_name")}");

            // Client 1 setup
            Console.WriteLine("\n--- Client 1 Operations ---");
            var client1NodeId = GuidExtensions.GenerateGuidV4();
            var client1HLC = HLC.Now(client1NodeId);
            
            var client1Map = YMap.FromJson(serverMap.ToJson()); // Simulate initial sync
            var client1Progress = client1Map.Get<GCounter>("progress")!.Clone() as GCounter;
            
            // Client 1 makes changes
            client1Progress.Increment(1, 25);
            client1Map.Set("progress", client1Progress);
            client1Map.Set("client1_note", "Added by client 1");
            
            Console.WriteLine($"Client 1 progress contribution: 25%");
            Console.WriteLine($"Client 1 total progress: {client1Progress.Value}%");

            // Client 2 setup (concurrent with Client 1)
            Console.WriteLine("\n--- Client 2 Operations ---");
            var client2NodeId = GuidExtensions.GenerateGuidV4();
            var client2HLC = HLC.Now(client2NodeId);
            
            var client2Map = YMap.FromJson(serverMap.ToJson()); // Simulate initial sync
            var client2Progress = client2Map.Get<GCounter>("progress")!.Clone() as GCounter;
            
            // Client 2 makes different changes
            client2Progress.Increment(2, 35);
            client2Map.Set("progress", client2Progress);
            client2Map.Set("client2_note", "Added by client 2");
            
            Console.WriteLine($"Client 2 progress contribution: 35%");
            Console.WriteLine($"Client 2 total progress: {client2Progress.Value}%");

            // Server merge (conflict resolution)
            Console.WriteLine("\n--- Server Merge Operations ---");
            
            // Merge Client 1 changes
            var finalProgress = serverMap.Get<GCounter>("progress")!;
            finalProgress.Merge(client1Progress);
            serverMap.Set("progress", finalProgress);
            serverMap.Set("client1_note", client1Map.Get<string>("client1_note")!);
            
            // Merge Client 2 changes
            finalProgress.Merge(client2Progress);
            serverMap.Set("progress", finalProgress);
            serverMap.Set("client2_note", client2Map.Get<string>("client2_note")!);
            
            Console.WriteLine($"Final merged progress: {finalProgress.Value}%");
            Console.WriteLine($"Server has client1_note: {serverMap.Has("client1_note")}");
            Console.WriteLine($"Server has client2_note: {serverMap.Has("client2_note")}");
            
            // Demonstrate CRDT properties
            Console.WriteLine("\n--- CRDT Properties Demonstration ---");
            
            // Create separate counter instances and merge in different orders
            var counter1 = new GCounter();
            var counter2 = new GCounter();
            var counter3 = new GCounter();
            
            // Same operations in different orders
            counter1.Increment(1, 10);
            counter1.Increment(2, 20);
            counter1.Increment(3, 30);
            
            counter2.Increment(3, 30);
            counter2.Increment(1, 10);
            counter2.Increment(2, 20);
            
            counter3.Increment(2, 20);
            counter3.Increment(3, 30);
            counter3.Increment(1, 10);
            
            Console.WriteLine($"Counter 1 (order: 1,2,3): {counter1.Value}");
            Console.WriteLine($"Counter 2 (order: 3,1,2): {counter2.Value}");
            Console.WriteLine($"Counter 3 (order: 2,3,1): {counter3.Value}");
            Console.WriteLine($"All counters equal: {counter1.Equals(counter2) && counter2.Equals(counter3)}");
            
            // Idempotency test
            var mergedCounter = counter1.Clone();
            var beforeMerge = mergedCounter.Value;
            
            mergedCounter.Merge(counter2); // Should not change
            var afterFirstMerge = mergedCounter.Value;
            
            mergedCounter.Merge(counter2); // Merge again (idempotent)
            var afterSecondMerge = mergedCounter.Value;
            
            Console.WriteLine($"\nCRDT Idempotency test:");
            Console.WriteLine($"Before merge: {beforeMerge}");
            Console.WriteLine($"After first merge: {afterFirstMerge}");
            Console.WriteLine($"After redundant merge: {afterSecondMerge}");
            Console.WriteLine($"Idempotent: {afterFirstMerge == afterSecondMerge}");

            Console.WriteLine("\n=== Server-Client Example Complete ===");
        }
    }
}