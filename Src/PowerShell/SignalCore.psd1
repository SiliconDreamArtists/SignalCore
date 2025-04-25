New-ModuleManifest -Path ./SignalCore.psd1 `
  -RootModule 'SignalCore.psm1' `
  -ModuleVersion '1.0.0' `
  -Author 'Silicon Dream Artists' `
  -CompanyName 'Silicon Dream Artists' `
  -Description 'Native PowerShell implementation of the Signal protocol format, used in SovereignTrust for verifiable, structured execution results.' `
  -Tags 'Signal' 'SovereignTrust' 'Messaging' 'StructuredLog' `
  -LicenseUri 'https://opensource.org/licenses/MIT' `
  -ProjectUri 'https://github.com/SiliconDreamArtists/signal-core' `
  -CompatiblePSEditions 'Core' `
  -PowerShellVersion '5.1'




  Import-Module SignalCore