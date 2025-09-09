using System;
using System.Collections.Generic;
using Xunit;
using YjsCrdtSharp.Core;
using YjsCrdtSharp.Counters;
using YjsCrdtSharp.Types;
using YjsCrdtSharp.Extensions;

namespace YjsCrdtSharp.Tests
{
    /// <summary>
    /// Unit tests for Hybrid Logical Clock implementation
    /// </summary>
    public class HLCTests
    {
        [Fact]
        public void HLC_ShouldCreateWithCurrentTime()
        {
            var nodeId = "test-node";
            var hlc = HLC.Now(nodeId);
            
            Assert.Equal(nodeId, hlc.NodeId);
            Assert.Equal(0, hlc.LogicalCounter);
            Assert.True(hlc.PhysicalTime > 0);
        }

        [Fact]
        public void HLC_ShouldIncrementCorrectly()
        {
            var hlc1 = HLC.Now("node1");
            var hlc2 = hlc1.Increment();
            
            Assert.True(hlc2.PhysicalTime >= hlc1.PhysicalTime);
            Assert.True(hlc1.HappensBefore(hlc2));
        }

        [Fact]
        public void HLC_ShouldHandleEventReception()
        {
            var hlc1 = new HLC(1000, 0, "node1");
            var hlc2 = new HLC(1500, 5, "node2");
            
            var result = hlc1.ReceiveEvent(hlc2);
            
            Assert.True(result.PhysicalTime >= Math.Max(hlc1.PhysicalTime, hlc2.PhysicalTime));
            Assert.Equal("node1", result.NodeId);
        }

        [Fact]
        public void HLC_ShouldSerializeToJson()
        {
            var hlc = new HLC(1234567890, 5, "test-node");
            var json = hlc.ToJson();
            
            Assert.Equal(1234567890L, json["physicalTime"]);
            Assert.Equal(5, json["logicalCounter"]);
            Assert.Equal("test-node", json["nodeId"]);
        }

        [Fact]
        public void HLC_ShouldDeserializeFromJson()
        {
            var json = new Dictionary<string, object>
            {
                ["physicalTime"] = 1234567890L,
                ["logicalCounter"] = 5,
                ["nodeId"] = "test-node"
            };
            
            var hlc = HLC.FromJson(json);
            
            Assert.Equal(1234567890L, hlc.PhysicalTime);
            Assert.Equal(5, hlc.LogicalCounter);
            Assert.Equal("test-node", hlc.NodeId);
        }
    }

    /// <summary>
    /// Unit tests for GCounter CRDT
    /// </summary>
    public class GCounterTests
    {
        [Fact]
        public void GCounter_ShouldStartWithZeroValue()
        {
            var counter = new GCounter();
            Assert.Equal(0, counter.Value);
        }

        [Fact]
        public void GCounter_ShouldIncrementCorrectly()
        {
            var counter = new GCounter();
            counter.Increment(1, 5);
            counter.Increment(2, 10);
            
            Assert.Equal(15, counter.Value);
        }

        [Fact]
        public void GCounter_ShouldMergeCorrectly()
        {
            var counter1 = new GCounter();
            var counter2 = new GCounter();
            
            counter1.Increment(1, 5);
            counter1.Increment(2, 10);
            
            counter2.Increment(2, 8);  // Should take max
            counter2.Increment(3, 15);
            
            counter1.Merge(counter2);
            
            Assert.Equal(30, counter1.Value); // 5 + 10 + 15
        }

        [Fact]
        public void GCounter_ShouldNotAllowNegativeIncrements()
        {
            var counter = new GCounter();
            Assert.Throws<ArgumentException>(() => counter.Increment(1, -5));
        }

        [Fact]
        public void GCounter_ShouldSerializeAndDeserialize()
        {
            var counter = new GCounter();
            counter.Increment(1, 10);
            counter.Increment(2, 20);
            
            var json = counter.ToJson();
            var restored = GCounter.FromJson(json);
            
            Assert.Equal(counter.Value, restored.Value);
            Assert.True(counter.Equals(restored));
        }
    }

    /// <summary>
    /// Unit tests for PNCounter CRDT
    /// </summary>
    public class PNCounterTests
    {
        [Fact]
        public void PNCounter_ShouldStartWithZeroValue()
        {
            var counter = new PNCounter();
            Assert.Equal(0, counter.Value);
        }

        [Fact]
        public void PNCounter_ShouldIncrementAndDecrement()
        {
            var counter = new PNCounter();
            counter.Increment(1, 10);
            counter.Decrement(1, 3);
            counter.Add(2, 5);
            counter.Add(2, -2);
            
            Assert.Equal(10, counter.Value); // 10 - 3 + 5 - 2
        }

        [Fact]
        public void PNCounter_ShouldMergeCorrectly()
        {
            var counter1 = new PNCounter();
            var counter2 = new PNCounter();
            
            counter1.Increment(1, 10);
            counter1.Decrement(1, 2);
            
            counter2.Increment(2, 15);
            counter2.Decrement(2, 5);
            
            counter1.Merge(counter2);
            
            Assert.Equal(18, counter1.Value); // (10-2) + (15-5)
        }

        [Fact]
        public void PNCounter_ShouldSerializeAndDeserialize()
        {
            var counter = new PNCounter();
            counter.Increment(1, 10);
            counter.Decrement(2, 5);
            
            var json = counter.ToJson();
            var restored = PNCounter.FromJson(json);
            
            Assert.Equal(counter.Value, restored.Value);
            Assert.True(counter.Equals(restored));
        }
    }

    /// <summary>
    /// Unit tests for YMap CRDT
    /// </summary>
    public class YMapTests
    {
        [Fact]
        public void YMap_ShouldSetAndGetValues()
        {
            var map = new YMap();
            map.Set("key1", "value1");
            map.Set("key2", 42);
            
            Assert.Equal("value1", map.Get<string>("key1"));
            Assert.Equal(42, map.Get<object>("key2"));
        }

        [Fact]
        public void YMap_ShouldCheckKeyExistence()
        {
            var map = new YMap();
            map.Set("existing", "value");
            
            Assert.True(map.Has("existing"));
            Assert.False(map.Has("nonexistent"));
        }

        [Fact]
        public void YMap_ShouldDeleteKeys()
        {
            var map = new YMap();
            map.Set("key", "value");
            
            Assert.True(map.Has("key"));
            map.Delete("key");
            Assert.False(map.Has("key"));
        }

        [Fact]
        public void YMap_ShouldSupportCounterValues()
        {
            var map = new YMap();
            var counter = new GCounter();
            counter.Increment(1, 25);
            
            map.Set("progress", counter);
            var retrieved = map.Get<GCounter>("progress");
            
            Assert.NotNull(retrieved);
            Assert.Equal(25, retrieved!.Value);
        }

        [Fact]
        public void YMap_ShouldSerializeToJson()
        {
            var map = new YMap();
            map.Set("name", "Alice");
            map.Set("age", 30);
            
            var json = map.ToJson();
            
            Assert.Equal("Alice", json["name"]);
            Assert.Equal(30, json["age"]);
        }

        [Fact]
        public void YMap_ShouldCreateFromJson()
        {
            var json = new Dictionary<string, object>
            {
                ["name"] = "Bob",
                ["age"] = 25
            };
            
            var map = YMap.FromJson(json);
            
            Assert.Equal("Bob", map.Get<string>("name"));
            Assert.Equal(25, map.Get<object>("age"));
        }
    }

    /// <summary>
    /// Unit tests for GUID extensions
    /// </summary>
    public class GuidExtensionsTests
    {
        [Fact]
        public void GenerateGuidV4_ShouldReturnValidGuid()
        {
            var guid = GuidExtensions.GenerateGuidV4();
            
            Assert.NotNull(guid);
            Assert.True(Guid.TryParse(guid, out _));
        }

        [Fact]
        public void GenerateSecureGuidV4_ShouldReturnValidGuid()
        {
            var guid = GuidExtensions.GenerateSecureGuidV4();
            
            Assert.NotNull(guid);
            Assert.True(Guid.TryParse(guid, out _));
        }

        [Fact]
        public void GenerateGuidV4_ShouldReturnUniqueValues()
        {
            var guid1 = GuidExtensions.GenerateGuidV4();
            var guid2 = GuidExtensions.GenerateGuidV4();
            
            Assert.NotEqual(guid1, guid2);
        }
    }
}