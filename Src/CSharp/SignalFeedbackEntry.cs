//------------------------------------------------------------------------------
// <copyright file="SignalFeedbackEntry.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>
//------------------------------------------------------------------------------

namespace SignalCore
{
    using System;
    using System.Runtime.Serialization;

    [DataContract]
    public class SignalFeedbackEntry : ISignalFeedbackEntry
    {
        public SignalFeedbackEntry()
        {
            this.CreatedDate = DateTime.Now;
        }

        public SignalFeedbackEntry(SignalFeedbackLevel severity, string message, Exception exception = null)
        {
            this.CreatedDate = DateTime.Now;
            this.Level = severity;
            this.Message = message;
            this.Exception = exception;
        }

        public SignalFeedbackEntry(SignalFeedbackLevel severity, string message, SignalFeedbackNature nature, Exception exception = null)
        {
            this.CreatedDate = DateTime.Now;
            this.Level = severity;
            this.Nature = nature;
            this.Message = message;
            this.Exception = exception;
        }

        public Exception Exception { get; set; }

        [DataMember]
        public string Message { get; set; }

        [DataMember]
        public string MessageFull { get; set; }

        [DataMember]
        public SignalFeedbackLevel Level { get; set; }

        [DataMember]
        public SignalFeedbackNature Nature { get; set; }

        [DataMember]
        public DateTime? CreatedDate { get; set; }

        [DataMember]
        public DateTime? LastModifiedDate { get; set; }

        [DataMember]
        public string CreatedBy { get; set; }

        [DataMember]
        public string LastModifiedBy { get; set; }

        [DataMember]
        public Guid Version { get; set; }

        [DataMember]
        public bool IsReadOnly { get; set; }
    }
}
