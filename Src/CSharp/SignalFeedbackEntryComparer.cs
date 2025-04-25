// <copyright file="SignalFeedbackEntryComparer.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>

namespace SignalCore
{
    using System.Collections.Generic;

    public class SignalFeedbackEntryComparer : IEqualityComparer<SignalFeedbackEntry>
    {
        public bool Equals(SignalFeedbackEntry g1, SignalFeedbackEntry g2)
        {
            return g1.CreatedDate == g2.CreatedDate && g1.Message == g2.Message && g1.Nature == g2.Nature;
        }

        public int GetHashCode(SignalFeedbackEntry g)
        {
            return (g.CreatedDate.ToString() + g.Message + g.Nature.ToString()).GetHashCode();
        }
    }
}
