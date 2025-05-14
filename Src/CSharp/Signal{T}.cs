//------------------------------------------------------------------------------
// <copyright file="Signal{T}.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>
//------------------------------------------------------------------------------

namespace SignalGraph
{
    using System;
    using System.Runtime.Serialization;

    public class Signal<T> : Signal, ISignal<T>
    {
        public Signal()
        {
            try
            {
                this.Result = (T)Activator.CreateInstance(typeof(T));
            }
            catch
            {
                // Swallow creation error.
            }
        }

        public Signal(bool createDefaultResult = true, params Signal[] priorExecutionResults)
            : base(priorExecutionResults)
        {
            if (createDefaultResult)
            {
                this.Result = (T)Activator.CreateInstance(typeof(T));
            }
        }

        public Signal(T defaultResult, params Signal[] priorExecutionResults)
            : base(priorExecutionResults)
        {
            this.Result = defaultResult;
        }

        [DataMember]
        public T Result { get; set; }

        public bool HasValue => this.Result != null;
    }
}
