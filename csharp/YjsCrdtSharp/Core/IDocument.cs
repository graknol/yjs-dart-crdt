using System;

namespace YjsCrdtSharp.Core
{
    /// <summary>
    /// Interface for document container
    /// </summary>
    public interface IDocument
    {
        string NodeId { get; }
        int ClientId { get; }
        HLC GetCurrentHLC();
        HLC NextHLC();
    }
}