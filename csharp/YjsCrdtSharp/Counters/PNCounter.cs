using System;
using System.Collections.Generic;
using YjsCrdtSharp.Core;

namespace YjsCrdtSharp.Counters
{
    /// <summary>
    /// PN-Counter (Positive-Negative Counter) CRDT
    /// A counter that supports both increment and decrement operations.
    /// Implemented using two G-Counters: one for increments, one for decrements.
    /// Thread-safe for concurrent access.
    /// </summary>
    public class PNCounter
    {
        private readonly GCounter _positiveCounter;
        private readonly GCounter _negativeCounter;

        /// <summary>Create a new PN-Counter</summary>
        public PNCounter()
        {
            _positiveCounter = new GCounter();
            _negativeCounter = new GCounter();
        }

        /// <summary>Create a PN-Counter with initial state</summary>
        public PNCounter(Dictionary<int, long> positiveState, Dictionary<int, long> negativeState)
        {
            _positiveCounter = new GCounter(positiveState);
            _negativeCounter = new GCounter(negativeState);
        }

        /// <summary>Get the current net value (positive - negative)</summary>
        public long Value => _positiveCounter.Value - _negativeCounter.Value;

        /// <summary>Increment the counter for a given client</summary>
        /// <param name="clientId">Client identifier</param>
        /// <param name="amount">Amount to increment</param>
        public void Increment(int clientId, long amount = 1)
        {
            if (amount < 0)
            {
                throw new ArgumentException("Use Decrement() for negative amounts", nameof(amount));
            }
            _positiveCounter.Increment(clientId, amount);
        }

        /// <summary>Decrement the counter for a given client</summary>
        /// <param name="clientId">Client identifier</param>
        /// <param name="amount">Amount to decrement</param>
        public void Decrement(int clientId, long amount = 1)
        {
            if (amount < 0)
            {
                throw new ArgumentException("Use Increment() for negative amounts", nameof(amount));
            }
            _negativeCounter.Increment(clientId, amount);
        }

        /// <summary>Add a value (positive or negative) to the counter</summary>
        /// <param name="clientId">Client identifier</param>
        /// <param name="amount">Amount to add (can be positive or negative)</param>
        public void Add(int clientId, long amount)
        {
            if (amount >= 0)
            {
                _positiveCounter.Increment(clientId, amount);
            }
            else
            {
                _negativeCounter.Increment(clientId, -amount);
            }
        }

        /// <summary>Merge with another PN-Counter</summary>
        /// <param name="other">Other counter to merge</param>
        public void Merge(PNCounter other)
        {
            if (other == null) throw new ArgumentNullException(nameof(other));

            _positiveCounter.Merge(other._positiveCounter);
            _negativeCounter.Merge(other._negativeCounter);
        }

        /// <summary>Get the positive counter state</summary>
        public Dictionary<int, long> GetPositiveState() => _positiveCounter.GetState();

        /// <summary>Get the negative counter state</summary>
        public Dictionary<int, long> GetNegativeState() => _negativeCounter.GetState();

        /// <summary>Create a copy of this counter</summary>
        public PNCounter Clone()
        {
            return new PNCounter(GetPositiveState(), GetNegativeState());
        }

        /// <summary>Convert to JSON for serialization</summary>
        public Dictionary<string, object> ToJson()
        {
            return new Dictionary<string, object>
            {
                ["type"] = "PNCounter",
                ["positive"] = _positiveCounter.ToJson()["state"]!,
                ["negative"] = _negativeCounter.ToJson()["state"]!
            };
        }

        /// <summary>Create PN-Counter from JSON</summary>
        public static PNCounter FromJson(Dictionary<string, object> json)
        {
            if (json["type"].ToString() != "PNCounter")
            {
                throw new ArgumentException("Invalid JSON type for PNCounter");
            }

            var positiveState = new Dictionary<int, long>();
            var negativeState = new Dictionary<int, long>();

            var positiveDict = (Dictionary<string, object>)json["positive"];
            var negativeDict = (Dictionary<string, object>)json["negative"];

            foreach (var entry in positiveDict)
            {
                positiveState[int.Parse(entry.Key)] = Convert.ToInt64(entry.Value);
            }

            foreach (var entry in negativeDict)
            {
                negativeState[int.Parse(entry.Key)] = Convert.ToInt64(entry.Value);
            }

            return new PNCounter(positiveState, negativeState);
        }

        public override bool Equals(object? obj)
        {
            if (obj is not PNCounter other) return false;
            return _positiveCounter.Equals(other._positiveCounter) && 
                   _negativeCounter.Equals(other._negativeCounter);
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(_positiveCounter, _negativeCounter);
        }

        public override string ToString()
        {
            return $"PNCounter(Value: {Value}, +: {_positiveCounter.Value}, -: {_negativeCounter.Value})";
        }
    }
}