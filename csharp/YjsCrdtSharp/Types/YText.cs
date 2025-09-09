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
                // Add initial content as separate character items
                var timestamp = _document?.GetCurrentHLC() ?? HLC.Now("unknown");
                TextItem? previousItem = null;
                
                for (int i = 0; i < initialContent.Length; i++)
                {
                    var itemTimestamp = timestamp.Increment();
                    var itemId = TextItem.GenerateItemId(itemTimestamp);
                    
                    var item = new TextItem
                    {
                        Character = initialContent[i],
                        Timestamp = itemTimestamp,
                        IsDeleted = false,
                        OriginNodeId = itemTimestamp.NodeId,
                        ItemId = itemId,
                        OriginLeft = previousItem?.ItemId,
                        OriginRight = null,
                        Left = previousItem,
                        Right = null
                    };
                    
                    if (previousItem != null)
                    {
                        previousItem.Right = item;
                    }
                    
                    _items.Add(item);
                    previousItem = item;
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

        /// <summary>Insert text at the specified index using YATA algorithm</summary>
        public void Insert(int index, string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            if (index < 0 || index > Length) 
                throw new ArgumentOutOfRangeException(nameof(index));

            var timestamp = _document?.GetCurrentHLC() ?? HLC.Now("unknown");

            _itemsLock.EnterWriteLock();
            try
            {
                // Find the YATA position (left and right origins)
                var (leftItem, rightItem) = FindYataPosition(index);
                
                // Create text items for each character with YATA origin tracking
                var newItems = new List<TextItem>();
                TextItem? previousNewItem = leftItem;
                
                for (int i = 0; i < text.Length; i++)
                {
                    var itemTimestamp = timestamp.Increment();
                    var itemId = TextItem.GenerateItemId(itemTimestamp);
                    
                    var newItem = new TextItem
                    {
                        Character = text[i],
                        Timestamp = itemTimestamp,
                        IsDeleted = false,
                        OriginNodeId = itemTimestamp.NodeId,
                        ItemId = itemId,
                        OriginLeft = previousNewItem?.ItemId,
                        OriginRight = (i == 0) ? rightItem?.ItemId : null,
                        Left = previousNewItem,
                        Right = (i == 0) ? rightItem : null
                    };

                    newItems.Add(newItem);
                    
                    // Update links for flat list structure
                    if (previousNewItem != null)
                    {
                        previousNewItem.Right = newItem;
                    }
                    
                    previousNewItem = newItem;
                }
                
                // Update right item's left pointer
                if (rightItem != null && newItems.Count > 0)
                {
                    rightItem.Left = newItems.Last();
                    newItems.Last().Right = rightItem;
                }

                // Insert using YATA positioning algorithm
                InsertItemsWithYata(newItems, leftItem, rightItem);

                // Track operation for synchronization
                AddOperation("text_insert", new Dictionary<string, object>
                {
                    ["index"] = index,
                    ["text"] = text,
                    ["timestamp"] = timestamp.ToJson(),
                    ["origin_left"] = leftItem?.ItemId,
                    ["origin_right"] = rightItem?.ItemId
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

        /// <summary>Serialize to JSON format with YATA structure</summary>
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
                        ["origin"] = item.OriginNodeId,
                        ["item_id"] = item.ItemId,
                        ["origin_left"] = item.OriginLeft ?? "",
                        ["origin_right"] = item.OriginRight ?? ""
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

        /// <summary>Create YText from JSON with YATA structure</summary>
        public static YText FromJson(Dictionary<string, object> json)
        {
            var ytext = new YText();

            if (json.ContainsKey("items") && json["items"] is List<object> itemsList)
            {
                ytext._itemsLock.EnterWriteLock();
                try
                {
                    var itemsToLink = new List<TextItem>();
                    
                    foreach (var itemObj in itemsList)
                    {
                        if (itemObj is Dictionary<string, object> itemData)
                        {
                            var character = itemData["char"].ToString()?[0] ?? ' ';
                            var timestamp = HLC.FromJson((Dictionary<string, object>)itemData["timestamp"]);
                            var deleted = (bool)itemData["deleted"];
                            var origin = itemData["origin"].ToString() ?? "unknown";
                            var itemId = itemData.ContainsKey("item_id") ? 
                                itemData["item_id"].ToString() : 
                                TextItem.GenerateItemId(timestamp);
                            var originLeft = itemData.ContainsKey("origin_left") ? 
                                itemData["origin_left"].ToString() : null;
                            var originRight = itemData.ContainsKey("origin_right") ? 
                                itemData["origin_right"].ToString() : null;

                            var item = new TextItem
                            {
                                Character = character,
                                Timestamp = timestamp,
                                IsDeleted = deleted,
                                OriginNodeId = origin,
                                ItemId = itemId,
                                OriginLeft = string.IsNullOrEmpty(originLeft) ? null : originLeft,
                                OriginRight = string.IsNullOrEmpty(originRight) ? null : originRight
                            };
                            
                            ytext._items.Add(item);
                            itemsToLink.Add(item);
                        }
                    }
                    
                    // Update flat list links
                    ytext.UpdateFlatListLinks();
                }
                finally
                {
                    ytext._itemsLock.ExitWriteLock();
                }
            }
            else if (json.ContainsKey("text") && json["text"] is string textContent)
            {
                // Simple text content - create with YATA structure
                var timestamp = HLC.Now("import");
                ytext._itemsLock.EnterWriteLock();
                try
                {
                    TextItem? previousItem = null;
                    
                    for (int i = 0; i < textContent.Length; i++)
                    {
                        var itemTimestamp = timestamp.Increment();
                        var itemId = TextItem.GenerateItemId(itemTimestamp);
                        
                        var item = new TextItem
                        {
                            Character = textContent[i],
                            Timestamp = itemTimestamp,
                            IsDeleted = false,
                            OriginNodeId = itemTimestamp.NodeId,
                            ItemId = itemId,
                            OriginLeft = previousItem?.ItemId,
                            OriginRight = null
                        };
                        
                        ytext._items.Add(item);
                        previousItem = item;
                    }
                    
                    ytext.UpdateFlatListLinks();
                }
                finally
                {
                    ytext._itemsLock.ExitWriteLock();
                }
            }

            return ytext;
        }

        /// <summary>Apply a remote operation using YATA conflict resolution</summary>
        public override void ApplyRemoteOperation(Dictionary<string, object> operation)
        {
            var operationType = operation["type"].ToString();
            var timestamp = HLC.FromJson((Dictionary<string, object>)operation["timestamp"]);

            switch (operationType)
            {
                case "text_insert":
                    var insertIndex = Convert.ToInt32(operation["index"]);
                    var insertText = operation["text"].ToString()!;
                    var originLeft = operation.ContainsKey("origin_left") ? operation["origin_left"]?.ToString() : null;
                    var originRight = operation.ContainsKey("origin_right") ? operation["origin_right"]?.ToString() : null;
                    ApplyRemoteYataInsert(insertIndex, insertText, timestamp, originLeft, originRight);
                    break;

                case "text_delete":
                    var deleteIndex = Convert.ToInt32(operation["index"]);
                    var deleteLength = Convert.ToInt32(operation["length"]);
                    ApplyRemoteDelete(deleteIndex, deleteLength, timestamp);
                    break;
            }
        }

        /// <summary>Create a deep copy with YATA structure</summary>
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
                        OriginNodeId = item.OriginNodeId,
                        ItemId = item.ItemId,
                        OriginLeft = item.OriginLeft,
                        OriginRight = item.OriginRight
                    });
                }
                
                // Update flat list links
                clone.UpdateFlatListLinks();
                return clone;
            }
            finally
            {
                _itemsLock.ExitReadLock();
            }
        }

        /// <summary>Find the YATA position (left and right origins) for inserting at logical index</summary>
        private (TextItem? leftItem, TextItem? rightItem) FindYataPosition(int logicalIndex)
        {
            if (logicalIndex == 0)
            {
                return (null, _items.FirstOrDefault(item => !item.IsDeleted));
            }

            int currentIndex = 0;
            TextItem? leftItem = null;

            foreach (var item in _items)
            {
                if (!item.IsDeleted)
                {
                    if (currentIndex == logicalIndex)
                    {
                        return (leftItem, item);
                    }
                    leftItem = item;
                    currentIndex++;
                }
            }

            // Insert at end
            return (leftItem, null);
        }

        /// <summary>Insert items using YATA conflict resolution algorithm</summary>
        private void InsertItemsWithYata(List<TextItem> newItems, TextItem? leftOrigin, TextItem? rightOrigin)
        {
            if (newItems.Count == 0) return;

            // Find the correct insertion position using YATA algorithm
            int insertionIndex = 0;
            
            if (leftOrigin != null)
            {
                // Find position after left origin
                var leftIndex = _items.IndexOf(leftOrigin);
                if (leftIndex >= 0)
                {
                    insertionIndex = leftIndex + 1;
                    
                    // YATA conflict resolution: scan forward to find correct position
                    // If there are concurrent inserts with same left origin, 
                    // use timestamp comparison to determine order
                    while (insertionIndex < _items.Count)
                    {
                        var currentItem = _items[insertionIndex];
                        
                        // Stop if we reach the right origin
                        if (rightOrigin != null && currentItem == rightOrigin)
                            break;
                            
                        // Stop if we reach an item with different origin
                        if (currentItem.OriginLeft != leftOrigin?.ItemId)
                            break;
                            
                        // Use timestamp for ordering concurrent inserts
                        if (newItems[0].Timestamp.HappensAfter(currentItem.Timestamp))
                        {
                            break;
                        }
                        
                        insertionIndex++;
                    }
                }
            }
            else if (rightOrigin != null)
            {
                // Insert at beginning, before right origin
                var rightIndex = _items.IndexOf(rightOrigin);
                if (rightIndex >= 0)
                {
                    insertionIndex = rightIndex;
                }
            }

            // Insert all new items at the determined position
            _items.InsertRange(insertionIndex, newItems);
            
            // Update the flat list structure links
            UpdateFlatListLinks();
        }

        /// <summary>Update the flat list structure links for efficient traversal</summary>
        private void UpdateFlatListLinks()
        {
            for (int i = 0; i < _items.Count; i++)
            {
                var current = _items[i];
                current.Left = (i > 0) ? _items[i - 1] : null;
                current.Right = (i < _items.Count - 1) ? _items[i + 1] : null;
            }
        }

        /// <summary>Apply remote insert operation using YATA conflict resolution</summary>
        private void ApplyRemoteYataInsert(int index, string text, HLC timestamp, string? originLeft, string? originRight)
        {
            _itemsLock.EnterWriteLock();
            try
            {
                // Find the origin items by their IDs
                TextItem? leftOriginItem = null;
                TextItem? rightOriginItem = null;
                
                if (originLeft != null)
                {
                    leftOriginItem = _items.FirstOrDefault(item => item.ItemId == originLeft);
                }
                
                if (originRight != null)
                {
                    rightOriginItem = _items.FirstOrDefault(item => item.ItemId == originRight);
                }

                // Create items for the remote text with YATA tracking
                var newItems = new List<TextItem>();
                TextItem? previousNewItem = leftOriginItem;
                
                for (int i = 0; i < text.Length; i++)
                {
                    var itemTimestamp = timestamp.Increment();
                    var itemId = TextItem.GenerateItemId(itemTimestamp);
                    
                    var newItem = new TextItem
                    {
                        Character = text[i],
                        Timestamp = itemTimestamp,
                        IsDeleted = false,
                        OriginNodeId = itemTimestamp.NodeId,
                        ItemId = itemId,
                        OriginLeft = (i == 0) ? originLeft : previousNewItem?.ItemId,
                        OriginRight = (i == 0) ? originRight : null
                    };

                    newItems.Add(newItem);
                    previousNewItem = newItem;
                }

                // Apply YATA positioning for conflict resolution
                InsertItemsWithYata(newItems, leftOriginItem, rightOriginItem);
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
    /// Internal text item for CRDT operations following YATA algorithm
    /// Each character is represented as a separate Item for proper conflict resolution
    /// </summary>
    internal class TextItem
    {
        public char Character { get; set; }
        public HLC Timestamp { get; set; }
        public bool IsDeleted { get; set; }
        public string OriginNodeId { get; set; } = string.Empty;
        
        // YATA-specific fields for proper conflict resolution
        public string? OriginLeft { get; set; }  // ID of left origin item
        public string? OriginRight { get; set; } // ID of right origin item
        public string ItemId { get; set; } = string.Empty; // Unique item identifier
        
        // Links for efficient traversal (flat list optimization)
        public TextItem? Left { get; set; }  // Previous item in document order
        public TextItem? Right { get; set; } // Next item in document order
        
        /// <summary>Generate unique item ID from HLC</summary>
        public static string GenerateItemId(HLC hlc)
        {
            return $"{hlc.NodeId}:{hlc.PhysicalTime}:{hlc.LogicalCounter}";
        }
    }
}