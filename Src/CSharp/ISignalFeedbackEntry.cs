// <copyright file="ISignalFeedbackEntry.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>

namespace SignalGraph
{
    using System;

    public interface ISignalFeedbackEntry
    {
        string Message { get; set; }
        string MessageFull { get; set; }
        SignalFeedbackLevel Level { get; set; }
        SignalFeedbackNature Nature { get; set; }

        Exception Exception { get; set; }
    }
}
