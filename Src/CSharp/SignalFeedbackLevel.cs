// <copyright file="SignalFeedbackLevel.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>

namespace SignalCore
{
    public enum SignalFeedbackLevel
    {
        Unspecified = 0,

        SensitiveInformation = 1,

        VerboseInformation = 2,

        Information = 4,

        Warning = 8,

        Retry = 16,

        Critical = 32,
    }
}
