using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using YjsCrdtSharp.Core;

namespace YjsCrdtSharp.Types
{
    /// <summary>
    /// Collaborative Text CRDT for character-level editing
    /// Supports concurrent text operations with conflict resolution using HLC timestamps
    /// </summary>
    public class YText : AbstractType
    {
        private readonly List<TextItem> _items;
        private readonly ReaderWriterLockSlim _itemsLock;

        /// <summary>Create a new YText with optional initial content</summary>
        public YText(string? initialContent = null)
        {
            _items = new List<TextItem>();
            _itemsLock = new ReaderWriterLockSlim();

            if (!string.IsNullOrEmpty(initialContent))
            {
                // Add initial content as a single operation
                var timestamp = _document?.GetCurrentHLC() ?? HLC.Now("unknown");
                for (int i = 0; i < initialContent.Length; i++)
                {
                    _items.Add(new TextItem
                    {
                        Character = initialContent[i],
                        Timestamp = timestamp,
                        IsDeleted = false,
                        OriginNodeId = timestamp.NodeId
                    });
                }
            }
        }

        /// <summary>Current length of visible (non-deleted) text</summary>
        public int Length
        {
            get
            {
                _itemsLock.EnterReadLock();
                try
                {
                    return _items.Count(item => !item.IsDeleted);
                }
                finally
                {
                    _itemsLock.ExitReadLock();
                }
            }
        }

        /// <summary>Insert text at the specified index</summary>
        public void Insert(int index, string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            if (index < 0 || index > Length) 
                throw new ArgumentOutOfRangeException(nameof(index));

            var timestamp = _document?.GetCurrentHLC() ?? HLC.Now("unknown");

            _itemsLock.EnterWriteLock();
            try
            {
                // Find the insertion point
                var insertionPoint = FindInsertionPoint(index);
                
                // Create text items for each character
                var newItems = new List<TextItem>();
                for (int i = 0; i < text.Length; i++)
                {
                    newItems.Add(new TextItem
                    {
                        Character = text[i],
                        Timestamp = timestamp.Increment(), // Each character gets unique timestamp
                        IsDeleted = false,
                        OriginNodeId = timestamp.NodeId
                    });
                }

                // Insert all items at the insertion point
                _items.InsertRange(insertionPoint, newItems);

                // Track operation for synchronization
                AddOperation("text_insert", new Dictionary<string, object>
                {
                    ["index"] = index,
                    ["text"] = text,
                    ["timestamp"] = timestamp.ToJson()
                });
            }
            finally
            {
                _itemsLock.ExitWriteLock();
            }
        }

        /// <summary>Delete characters starting at index</summary>
        public void Delete(int index, int length)
        {
            if (length <= 0) return;
            if (index < 0 || index >= Length) return;

            var timestamp = _document?.GetCurrentHLC() ?? HLC.Now("unknown");

            _itemsLock.EnterWriteLock();
            try
            {
                int deletedCount = 0;
                int currentIndex = 0;

                for (int i = 0; i < _items.Count && deletedCount < length; i++)
                {
                    var item = _items[i];
                    if (!item.IsDeleted)
                    {
                        if (currentIndex >= index && deletedCount < length)
                        {
                            item.IsDeleted = true;
                            deletedCount++;
                        }
                        currentIndex++;
                    }
                }

                AddOperation("text_delete", new Dictionary<string, object>
                {
                    ["index"] = index,
                    ["length"] = length,
                    ["timestamp"] = timestamp.ToJson()
                });
            }
            finally
            {
                _itemsLock.ExitWriteLock();
            }
        }

        /// <summary>Get character at the specified index</summary>
        public char? CharAt(int index)
        {
            if (index < 0 || index >= Length) return null;

            _itemsLock.EnterReadLock();
            try
            {
                int currentIndex = 0;
                foreach (var item in _items)
                {
                    if (!item.IsDeleted)
                    {
                        if (currentIndex == index)
                            return item.Character;
                        currentIndex++;
                    }
                }
                return null;
            }
            finally
            {
                _itemsLock.ExitReadLock();
            }
        }

        /// <summary>Get substring starting at index with specified length</summary>
        public string Substring(int start, int length)
        {
            if (start < 0 || start >= Length) return string.Empty;
            if (length <= 0) return string.Empty;

            _itemsLock.EnterReadLock();
            try
            {
                var result = new StringBuilder();
                int currentIndex = 0;
                int collected = 0;

                foreach (var item in _items)
                {
                    if (!item.IsDeleted)
                    {
                        if (currentIndex >= start && collected < length)
                        {
                            result.Append(item.Character);
                            collected++;
                        }
                        currentIndex++;
                        
                        if (collected >= length) break;
                    }
                }
                
                return result.ToString();
            }
            finally
            {
                _itemsLock.ExitReadLock();
            }
        }

        /// <summary>Convert the entire text to string</summary>
        public override string ToString()
        {
            _itemsLock.EnterReadLock();
            try
            {
                var result = new StringBuilder();
                foreach (var item in _items)
                {
                    if (!item.IsDeleted)
                    {
                        result.Append(item.Character);
                    }
                }
                return result.ToString();
            }
            finally
            {
                _itemsLock.ExitReadLock();
            }
        }

        /// <summary>Serialize to JSON format</summary>
        public override Dictionary<string, object> ToJson()
        {
            _itemsLock.EnterReadLock();
            try
            {
                var items = new List<Dictionary<string, object>>();
                var textBuilder = new StringBuilder();
                
                foreach (var item in _items)
                {
                    items.Add(new Dictionary<string, object>
                    {
                        ["char"] = item.Character.ToString(),
                        ["timestamp"] = item.Timestamp.ToJson(),
                        ["deleted"] = item.IsDeleted,
                        ["origin"] = item.OriginNodeId
                    });
                    
                    // Build text content without calling ToString() to avoid lock recursion
                    if (!item.IsDeleted)
                    {
                        textBuilder.Append(item.Character);
                    }
                }

                return new Dictionary<string, object>
                {
                    ["type"] = "YText",
                    ["items"] = items,
                    ["text"] = textBuilder.ToString() // For easy reading/debugging
                };
            }
            finally
            {
                _itemsLock.ExitReadLock();
            }
        }

        /// <summary>Create YText from JSON</summary>
        public static YText FromJson(Dictionary<string, object> json)
        {
            var ytext = new YText();

            if (json.ContainsKey("items") && json["items"] is List<object> itemsList)
            {
                ytext._itemsLock.EnterWriteLock();
                try
                {
                    foreach (var itemObj in itemsList)
                    {
                        if (itemObj is Dictionary<string, object> itemData)
                        {
                            var character = itemData["char"].ToString()?[0] ?? ' ';
                            var timestamp = HLC.FromJson((Dictionary<string, object>)itemData["timestamp"]);
                            var deleted = (bool)itemData["deleted"];
                            var origin = itemData["origin"].ToString() ?? "unknown";

                            ytext._items.Add(new TextItem
                            {
                                Character = character,
                                Timestamp = timestamp,
                                IsDeleted = deleted,
                                OriginNodeId = origin
                            });
                        }
                    }
                }
                finally
                {
                    ytext._itemsLock.ExitWriteLock();
                }
            }
            else if (json.ContainsKey("text") && json["text"] is string textContent)
            {
                // Simple text content - create with current timestamp
                var timestamp = HLC.Now("import");
                ytext._itemsLock.EnterWriteLock();
                try
                {
                    for (int i = 0; i < textContent.Length; i++)
                    {
                        ytext._items.Add(new TextItem
                        {
                            Character = textContent[i],
                            Timestamp = timestamp,
                            IsDeleted = false,
                            OriginNodeId = timestamp.NodeId
                        });
                    }
                }
                finally
                {
                    ytext._itemsLock.ExitWriteLock();
                }
            }

            return ytext;
        }

        /// <summary>Apply a remote operation</summary>
        public override void ApplyRemoteOperation(Dictionary<string, object> operation)
        {
            var operationType = operation["type"].ToString();
            var timestamp = HLC.FromJson((Dictionary<string, object>)operation["timestamp"]);

            switch (operationType)
            {
                case "text_insert":
                    var insertIndex = Convert.ToInt32(operation["index"]);
                    var insertText = operation["text"].ToString()!;
                    ApplyRemoteInsert(insertIndex, insertText, timestamp);
                    break;

                case "text_delete":
                    var deleteIndex = Convert.ToInt32(operation["index"]);
                    var deleteLength = Convert.ToInt32(operation["length"]);
                    ApplyRemoteDelete(deleteIndex, deleteLength, timestamp);
                    break;
            }
        }

        /// <summary>Create a deep copy</summary>
        public override IAbstractType Clone()
        {
            _itemsLock.EnterReadLock();
            try
            {
                var clone = new YText();
                foreach (var item in _items)
                {
                    clone._items.Add(new TextItem
                    {
                        Character = item.Character,
                        Timestamp = item.Timestamp,
                        IsDeleted = item.IsDeleted,
                        OriginNodeId = item.OriginNodeId
                    });
                }
                return clone;
            }
            finally
            {
                _itemsLock.ExitReadLock();
            }
        }

        /// <summary>Find the insertion point for a given logical index</summary>
        private int FindInsertionPoint(int logicalIndex)
        {
            if (logicalIndex == 0) return 0;

            int currentIndex = 0;
            for (int i = 0; i < _items.Count; i++)
            {
                if (!_items[i].IsDeleted)
                {
                    if (currentIndex == logicalIndex)
                        return i;
                    currentIndex++;
                }
            }
            return _items.Count; // Insert at end
        }

        /// <summary>Apply remote insert operation with conflict resolution</summary>
        private void ApplyRemoteInsert(int index, string text, HLC timestamp)
        {
            _itemsLock.EnterWriteLock();
            try
            {
                var insertionPoint = FindInsertionPoint(index);

                // Create items for the remote text
                var newItems = new List<TextItem>();
                for (int i = 0; i < text.Length; i++)
                {
                    newItems.Add(new TextItem
                    {
                        Character = text[i],
                        Timestamp = timestamp.Increment(),
                        IsDeleted = false,
                        OriginNodeId = timestamp.NodeId
                    });
                }

                // Insert with proper conflict resolution
                // In a full implementation, we'd use the YATA algorithm for positioning
                _items.InsertRange(insertionPoint, newItems);
            }
            finally
            {
                _itemsLock.ExitWriteLock();
            }
        }

        /// <summary>Apply remote delete operation</summary>
        private void ApplyRemoteDelete(int index, int length, HLC timestamp)
        {
            _itemsLock.EnterWriteLock();
            try
            {
                int deletedCount = 0;
                int currentIndex = 0;

                for (int i = 0; i < _items.Count && deletedCount < length; i++)
                {
                    var item = _items[i];
                    if (!item.IsDeleted)
                    {
                        if (currentIndex >= index && deletedCount < length)
                        {
                            // Only delete if the remote timestamp is newer than local
                            if (timestamp.HappensAfter(item.Timestamp))
                            {
                                item.IsDeleted = true;
                                deletedCount++;
                            }
                        }
                        currentIndex++;
                    }
                }
            }
            finally
            {
                _itemsLock.ExitWriteLock();
            }
        }
    }

    /// <summary>
    /// Internal text item for CRDT operations
    /// </summary>
    internal class TextItem
    {
        public char Character { get; set; }
        public HLC Timestamp { get; set; }
        public bool IsDeleted { get; set; }
        public string OriginNodeId { get; set; } = string.Empty;
    }
}