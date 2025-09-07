using System;
using System.Collections.Generic;
using YjsCrdtSharp.Core;

namespace YjsCrdtSharp.Types
{
    /// <summary>
    /// Base interface for all CRDT types
    /// </summary>
    public interface IAbstractType
    {
        /// <summary>Reference to the containing document</summary>
        IDocument? Document { get; set; }
        
        /// <summary>Serialize to JSON format</summary>
        Dictionary<string, object> ToJson();
        
        /// <summary>Apply a remote operation to this type</summary>
        void ApplyRemoteOperation(Dictionary<string, object> operation);
        
        /// <summary>Create a deep copy of this type</summary>
        IAbstractType Clone();
    }

    /// <summary>
    /// Base class for CRDT types with common functionality
    /// </summary>
    public abstract class AbstractType : IAbstractType
    {
        protected IDocument? _document;
        protected readonly object _lock = new object();

        public IDocument? Document 
        { 
            get => _document; 
            set => _document = value; 
        }

        public abstract Dictionary<string, object> ToJson();
        public abstract void ApplyRemoteOperation(Dictionary<string, object> operation);
        public abstract IAbstractType Clone();

        /// <summary>Add an operation to the document's history</summary>
        protected void AddOperation(string type, Dictionary<string, object> data)
        {
            if (_document != null)
            {
                // This would be implemented when we have the full Document class
                // _document.AddOperation(new Operation { Type = type, Data = data });
            }
        }
    }
}