param(
    [Parameter(Position = 0)]
    [string]$InputFile,

    [ValidateSet('natural', 'boolean', 'integer', 'rational', 'real')]
    [string]$Decode = "natural"
)

$compiler = cabal list-bin exe:lambda-compiler
$interpreter = cabal list-bin exe:ski-interpreter

$headingStyle = $PSStyle.Bold + $PSStyle.Foreground.BrightCyan
$resetStyle = $PSStyle.Reset

Write-Output "${headingStyle}Expand${resetStyle}"
& $compiler $InputFile --stop-after=expand

Write-Output "${headingStyle}Reduce${resetStyle}"
& $compiler $InputFile --stop-after=reduce --enable-reduce=both

Write-Output "${headingStyle}Compile${resetStyle}"
& $compiler $InputFile | Join-String -Separator "`t"

Write-Output "${headingStyle}Interpret${resetStyle}"
& $compiler $InputFile | & $interpreter --show-steps | Join-String -Separator "`t"

Write-Output "${headingStyle}Decode${resetStyle}"
& $compiler $InputFile | & $interpreter --show-steps --decode="$Decode"
