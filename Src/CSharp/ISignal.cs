//------------------------------------------------------------------------------
// <copyright file="ISignalFeedback.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>
//------------------------------------------------------------------------------

namespace SignalCore
{
    using System;
    using System.Collections.Generic;
    using Microsoft.Extensions.Logging;

    public interface ISignal
    {
        IEnumerable<SignalFeedbackEntry> CriticalEntries { get; }

        IEnumerable<string> CriticalEntryMessages { get; }

        string CriticalSummary { get; }

        List<SignalFeedbackEntry> Entries { get; set; }

        IEnumerable<string> EntryMessages { get; }

        SignalFeedbackLevel Level { get; set; }

        bool Failure { get; }

        string LevelName { get; }

        bool Success { get; }

        IDisposable BeginScope<TState>(TState state);

        bool CheckForLevelFailure(bool allowEquals = false, SignalFeedbackLevel passingSeverity = SignalFeedbackLevel.Warning);

        bool CheckForLevelSuccess(bool allowEquals = true, SignalFeedbackLevel passingSeverity = SignalFeedbackLevel.Warning);

        string GetExceptionMessage(Exception ex);

        IEnumerable<string> GetFeedbackEntries(SignalFeedbackLevel minimumSeverityToGet);

        Signal MergeFeedback(params Signal[] priorExecutionResults);

        bool MergeFeedbackAndCheckForFail(params Signal[] priorExecutionResults);

        bool MergeFeedbackAndCheckForSuccess(params Signal[] priorExecutionResults);

        bool IsEnabled(LogLevel logLevel);

        void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception exception, Func<TState, Exception, string> formatter);

        SignalFeedbackEntry LogCritical(string message, Exception exception = null);

        SignalFeedbackEntry LogInformation(string message, Exception exception = null);

        SignalFeedbackEntry LogMessage(SignalFeedbackLevel severity, string message, Exception exception = null);

        SignalFeedbackEntry LogWarning(string message, Exception exception = null);

        SignalFeedbackLevel SetFeedbackLevel();

        SignalFeedbackLevel SetFeedbackLevel(SignalFeedbackLevel signalLevel);

        void CreateFeedbackEntry(SignalFeedbackLevel severity, string message, Exception exception = null);

        string ToJson();
    }
}
