class SignalEntry {
    [string]$Level
    [string]$Nature
    [string]$Message
    [string]$Exception
    [datetime]$CreatedDate
    [datetime]$LastModifiedDate
    [string]$CreatedBy
    [string]$LastModifiedBy
    [bool]$IsReadOnly
    [object]$Signal

    SignalEntry() {
        $this.CreatedDate = Get-Date
    }

    SignalEntry([object]$signal, [string]$level, [string]$message, [string]$nature = "Unspecified", [string]$exception = $null) {
        $this.Level = $level
        $this.Message = $message
        $this.Nature = $nature
        $this.CreatedDate = Get-Date
        $this.Exception = $exception
        $this.Signal = $signal
    }
}
