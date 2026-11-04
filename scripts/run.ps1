param(
    [Parameter(Position = 0)]
    [string]$InputFile,

    [ValidateSet('natural', 'boolean', 'integer', 'rational')]
    [string]$Decode = "natural"
)

$compiler = cabal list-bin exe:lambda-to-graph
$interpreter = cabal list-bin exe:ski-interpreter

$headingStyle = $PSStyle.Bold + $PSStyle.Foreground.BrightCyan
$resetStyle = $PSStyle.Reset

Write-Output "${headingStyle}expand${resetStyle}"
& $compiler $InputFile --stop-after=expand
Write-Output "${headingStyle}reduce${resetStyle}"
& $compiler $InputFile --stop-after=reduce
Write-Output "${headingStyle}compile${resetStyle}"
& $compiler $InputFile | Join-String -Separator "`t"
Write-Output "${headingStyle}interpret${resetStyle}"
& $compiler $InputFile | & $interpreter | Join-String -Separator "`t"
Write-Output "${headingStyle}decode${resetStyle}"
& $compiler $InputFile | & $interpreter --decode="$Decode"
