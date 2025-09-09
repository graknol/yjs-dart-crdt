using System;
using System.Collections.Generic;

namespace YjsCrdtSharp.Core
{
    /// <summary>
    /// Hybrid Logical Clock implementation for causality tracking and ordering.
    /// Combines physical time (wall clock) with logical counter and node ID
    /// to provide better ordering and causality detection than pure vector clocks.
    /// </summary>
    public readonly struct HLC : IComparable<HLC>, IEquatable<HLC>
    {
        /// <summary>Physical timestamp in milliseconds since Unix epoch</summary>
        public long PhysicalTime { get; }
        
        /// <summary>Logical counter for events within the same millisecond</summary>
        public int LogicalCounter { get; }
        
        /// <summary>Node identifier - GUID v4 for users, hardcoded for services</summary>
        public string NodeId { get; }

        public HLC(long physicalTime, int logicalCounter, string nodeId)
        {
            PhysicalTime = physicalTime;
            LogicalCounter = logicalCounter;
            NodeId = nodeId ?? throw new ArgumentNullException(nameof(nodeId));
        }

        /// <summary>Create HLC with current wall clock time</summary>
        public static HLC Now(string nodeId)
        {
            return new HLC(
                physicalTime: DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                logicalCounter: 0,
                nodeId: nodeId
            );
        }

        /// <summary>Create HLC from another HLC, incrementing logical counter</summary>
        public HLC Increment()
        {
            var currentTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            
            if (currentTime > PhysicalTime)
            {
                // Wall clock advanced, reset logical counter
                return new HLC(currentTime, 0, NodeId);
            }
            else
            {
                // Same millisecond, increment logical counter
                return new HLC(PhysicalTime, LogicalCounter + 1, NodeId);
            }
        }

        /// <summary>Update HLC based on receiving an event from another node</summary>
        public HLC ReceiveEvent(HLC other)
        {
            var currentTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            var maxTime = Math.Max(Math.Max(PhysicalTime, other.PhysicalTime), currentTime);
            
            int newLogicalCounter;
            if (maxTime == PhysicalTime && maxTime == other.PhysicalTime)
            {
                // Same millisecond as both events
                newLogicalCounter = Math.Max(LogicalCounter, other.LogicalCounter) + 1;
            }
            else if (maxTime == PhysicalTime)
            {
                // Our time is the maximum
                newLogicalCounter = LogicalCounter + 1;
            }
            else if (maxTime == other.PhysicalTime)
            {
                // Other time is the maximum
                newLogicalCounter = other.LogicalCounter + 1;
            }
            else
            {
                // Current time is the maximum
                newLogicalCounter = 0;
            }
            
            return new HLC(maxTime, newLogicalCounter, NodeId);
        }

        /// <summary>Check if this HLC happens before another</summary>
        public bool HappensBefore(HLC other)
        {
            if (PhysicalTime < other.PhysicalTime) return true;
            if (PhysicalTime > other.PhysicalTime) return false;
            if (LogicalCounter < other.LogicalCounter) return true;
            if (LogicalCounter > other.LogicalCounter) return false;
            return string.CompareOrdinal(NodeId, other.NodeId) < 0;
        }

        /// <summary>Check if this HLC happens after another</summary>
        public bool HappensAfter(HLC other) => other.HappensBefore(this);

        /// <summary>Compare two HLCs for ordering</summary>
        public int CompareTo(HLC other)
        {
            if (HappensBefore(other)) return -1;
            if (HappensAfter(other)) return 1;
            return 0;
        }

        /// <summary>Check equality with another HLC</summary>
        public bool Equals(HLC other)
        {
            return PhysicalTime == other.PhysicalTime &&
                   LogicalCounter == other.LogicalCounter &&
                   NodeId == other.NodeId;
        }

        public override bool Equals(object? obj) => obj is HLC other && Equals(other);

        public override int GetHashCode()
        {
            return HashCode.Combine(PhysicalTime, LogicalCounter, NodeId);
        }

        public static bool operator ==(HLC left, HLC right) => left.Equals(right);
        public static bool operator !=(HLC left, HLC right) => !(left == right);
        public static bool operator <(HLC left, HLC right) => left.HappensBefore(right);
        public static bool operator >(HLC left, HLC right) => left.HappensAfter(right);
        public static bool operator <=(HLC left, HLC right) => !left.HappensAfter(right);
        public static bool operator >=(HLC left, HLC right) => !left.HappensBefore(right);

        /// <summary>Convert to JSON for serialization</summary>
        public Dictionary<string, object> ToJson()
        {
            return new Dictionary<string, object>
            {
                ["physicalTime"] = PhysicalTime,
                ["logicalCounter"] = LogicalCounter,
                ["nodeId"] = NodeId
            };
        }

        /// <summary>Create HLC from JSON</summary>
        public static HLC FromJson(Dictionary<string, object> json)
        {
            return new HLC(
                physicalTime: Convert.ToInt64(json["physicalTime"]),
                logicalCounter: Convert.ToInt32(json["logicalCounter"]),
                nodeId: json["nodeId"].ToString()!
            );
        }

        public override string ToString()
        {
            return $"HLC({PhysicalTime}:{LogicalCounter}@{NodeId})";
        }
    }
}