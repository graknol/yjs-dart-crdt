using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using YjsCrdtSharp.Core;

namespace YjsCrdtSharp.Counters
{
    /// <summary>
    /// G-Counter (Grow-only Counter) CRDT
    /// A counter that can only be incremented and never decremented.
    /// Each client has its own increment counter, and the total value
    /// is the sum of all client counters.
    /// Thread-safe for concurrent access.
    /// </summary>
    public class GCounter
    {
        /// <summary>Map from client ID to their current count</summary>
        private readonly ConcurrentDictionary<int, long> _state;

        /// <summary>Create a new G-Counter</summary>
        public GCounter()
        {
            _state = new ConcurrentDictionary<int, long>();
        }

        /// <summary>Create a G-Counter with initial state</summary>
        public GCounter(Dictionary<int, long> initialState)
        {
            _state = new ConcurrentDictionary<int, long>(initialState);
        }

        /// <summary>Get the current total value</summary>
        public long Value
        {
            get
            {
                long sum = 0;
                foreach (var count in _state.Values)
                {
                    sum += count;
                }
                return sum;
            }
        }

        /// <summary>Increment the counter for a given client</summary>
        /// <param name="clientId">Client identifier</param>
        /// <param name="amount">Amount to increment (must be non-negative)</param>
        public void Increment(int clientId, long amount = 1)
        {
            if (amount < 0)
            {
                throw new ArgumentException("GCounter can only increment by non-negative amounts", nameof(amount));
            }

            _state.AddOrUpdate(clientId, amount, (key, current) => current + amount);
        }

        /// <summary>Merge with another G-Counter</summary>
        /// <param name="other">Other counter to merge</param>
        public void Merge(GCounter other)
        {
            if (other == null) throw new ArgumentNullException(nameof(other));

            foreach (var entry in other._state)
            {
                var clientId = entry.Key;
                var otherCount = entry.Value;

                _state.AddOrUpdate(clientId, otherCount, (key, current) => Math.Max(current, otherCount));
            }
        }

        /// <summary>Get a copy of the internal state</summary>
        public Dictionary<int, long> GetState()
        {
            return new Dictionary<int, long>(_state);
        }

        /// <summary>Create a copy of this counter</summary>
        public GCounter Clone()
        {
            return new GCounter(GetState());
        }

        /// <summary>Convert to JSON for serialization</summary>
        public Dictionary<string, object> ToJson()
        {
            var stateDict = new Dictionary<string, object>();
            foreach (var entry in _state)
            {
                stateDict[entry.Key.ToString()] = entry.Value;
            }

            return new Dictionary<string, object>
            {
                ["type"] = "GCounter",
                ["state"] = stateDict
            };
        }

        /// <summary>Create G-Counter from JSON</summary>
        public static GCounter FromJson(Dictionary<string, object> json)
        {
            if (json["type"].ToString() != "GCounter")
            {
                throw new ArgumentException("Invalid JSON type for GCounter");
            }

            var state = new Dictionary<int, long>();
            var stateDict = (Dictionary<string, object>)json["state"];

            foreach (var entry in stateDict)
            {
                state[int.Parse(entry.Key)] = Convert.ToInt64(entry.Value);
            }

            return new GCounter(state);
        }

        public override bool Equals(object? obj)
        {
            if (obj is not GCounter other) return false;
            if (_state.Count != other._state.Count) return false;

            foreach (var entry in _state)
            {
                if (!other._state.TryGetValue(entry.Key, out var otherValue) || otherValue != entry.Value)
                {
                    return false;
                }
            }

            return true;
        }

        public override int GetHashCode()
        {
            var hash = new HashCode();
            foreach (var entry in _state)
            {
                hash.Add(entry.Key);
                hash.Add(entry.Value);
            }
            return hash.ToHashCode();
        }

        public override string ToString()
        {
            return $"GCounter(Value: {Value}, Nodes: {_state.Count})";
        }
    }
}