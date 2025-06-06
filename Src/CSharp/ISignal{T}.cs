//------------------------------------------------------------------------------
// <copyright file="ISignal{T}.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>
//------------------------------------------------------------------------------

namespace SignalCore
{
    public interface ISignal<T> : ISignal
    {
        T Result { get; set; }
        bool HasValue { get; }
    }
}
