using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using YjsCrdtSharp.Core;

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

        /// <summary>Create a new YMap</summary>
        public YMap()
        {
            _items = new ConcurrentDictionary<string, object>();
            _keyTimestamps = new ConcurrentDictionary<string, HLC>();
        }

        /// <summary>Get or set value by key</summary>
        public object this[string key]
        {
            get => _items.TryGetValue(key, out var value) ? value : throw new KeyNotFoundException();
            set => Set(key, value);
        }

        /// <summary>Number of items in the map</summary>
        public int Count => _items.Count;

        /// <summary>Always false for YMap</summary>
        public bool IsReadOnly => false;

        /// <summary>Collection of all keys</summary>
        public ICollection<string> Keys => _items.Keys;

        /// <summary>Collection of all values</summary>
        public ICollection<object> Values => _items.Values;

        /// <summary>Set a value for a key</summary>
        public void Set(string key, object value)
        {
            if (key == null) throw new ArgumentNullException(nameof(key));

            var timestamp = _document?.GetCurrentHLC() ?? HLC.Now("unknown");
            
            // Check if we should update based on timestamp
            if (_keyTimestamps.TryGetValue(key, out var existingTimestamp))
            {
                if (timestamp.HappensBefore(existingTimestamp))
                {
                    // Our timestamp is older, ignore the update
                    return;
                }
            }

            _items[key] = value;
            _keyTimestamps[key] = timestamp;

            AddOperation("map_set", new Dictionary<string, object>
            {
                ["key"] = key,
                ["value"] = value,
                ["timestamp"] = timestamp.ToJson()
            });
        }

        /// <summary>Get a value by key with type casting</summary>
        public T? Get<T>(string key) where T : class
        {
            return _items.TryGetValue(key, out var value) ? (T)value : default;
        }

        /// <summary>Check if a key exists</summary>
        public bool Has(string key) => _items.ContainsKey(key);

        /// <summary>Delete a key</summary>
        public void Delete(string key)
        {
            if (_items.TryRemove(key, out _))
            {
                _keyTimestamps.TryRemove(key, out _);
                
                AddOperation("map_delete", new Dictionary<string, object>
                {
                    ["key"] = key
                });
            }
        }

        /// <summary>Clear all items</summary>
        public void Clear()
        {
            _items.Clear();
            _keyTimestamps.Clear();
            
            AddOperation("map_clear", new Dictionary<string, object>());
        }

        // IDictionary implementation
        public void Add(string key, object value) => Set(key, value);
        public bool Remove(string key) { Delete(key); return true; }
        public bool ContainsKey(string key) => _items.ContainsKey(key);
        public bool TryGetValue(string key, out object value) => _items.TryGetValue(key, out value);
        
        public void Add(KeyValuePair<string, object> item) => Set(item.Key, item.Value);
        public bool Remove(KeyValuePair<string, object> item) => _items.TryRemove(item.Key, out _);
        public bool Contains(KeyValuePair<string, object> item) => _items.Contains(item);
        public void CopyTo(KeyValuePair<string, object>[] array, int arrayIndex)
        {
            ((IDictionary<string, object>)_items).CopyTo(array, arrayIndex);
        }

        // IEnumerable implementation
        public IEnumerator<KeyValuePair<string, object>> GetEnumerator() => _items.GetEnumerator();
        IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

        /// <summary>Get all entries as key-value pairs</summary>
        public ICollection<KeyValuePair<string, object>> Entries => _items.ToList();

        /// <summary>Serialize to JSON</summary>
        public override Dictionary<string, object> ToJson()
        {
            var result = new Dictionary<string, object>();
            foreach (var item in _items)
            {
                if (item.Value is IAbstractType abstractType)
                {
                    result[item.Key] = abstractType.ToJson();
                }
                else
                {
                    result[item.Key] = item.Value;
                }
            }
            return result;
        }

        /// <summary>Create YMap from JSON</summary>
        public static YMap FromJson(Dictionary<string, object> json)
        {
            var map = new YMap();
            foreach (var item in json)
            {
                map.Set(item.Key, item.Value);
            }
            return map;
        }

        /// <summary>Apply a remote operation</summary>
        public override void ApplyRemoteOperation(Dictionary<string, object> operation)
        {
            var operationType = operation["type"].ToString();
            
            switch (operationType)
            {
                case "map_set":
                    var key = operation["key"].ToString()!;
                    var value = operation["value"];
                    var timestampData = (Dictionary<string, object>)operation["timestamp"];
                    var timestamp = HLC.FromJson(timestampData);
                    
                    // Apply if timestamp is newer
                    if (!_keyTimestamps.TryGetValue(key, out var existing) || timestamp.HappensAfter(existing))
                    {
                        _items[key] = value;
                        _keyTimestamps[key] = timestamp;
                    }
                    break;
                    
                case "map_delete":
                    var deleteKey = operation["key"].ToString()!;
                    _items.TryRemove(deleteKey, out _);
                    _keyTimestamps.TryRemove(deleteKey, out _);
                    break;
                    
                case "map_clear":
                    _items.Clear();
                    _keyTimestamps.Clear();
                    break;
            }
        }

        /// <summary>Create a deep copy</summary>
        public override IAbstractType Clone()
        {
            var clone = new YMap();
            foreach (var item in _items)
            {
                if (item.Value is IAbstractType abstractType)
                {
                    clone.Set(item.Key, abstractType.Clone());
                }
                else
                {
                    clone.Set(item.Key, item.Value);
                }
            }
            return clone;
        }

        public override string ToString()
        {
            return $"YMap(Count: {Count})";
        }
    }
}