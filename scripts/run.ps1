param(
    [Parameter(Position = 0)]
    [string]$InputFile,

    [ValidateSet('natural', 'boolean', 'integer', 'rational', 'real')]
    [string]$Decode = "natural",

    [ValidateSet('expand', 'reduce', 'compile', 'interpret', 'decode')]
    [string[]]$Stages = @('expand', 'reduce', 'compile', 'interpret', 'decode')
)

$compiler = cabal list-bin exe:lambda-compiler
$interpreter = cabal list-bin exe:ski-interpreter

$headingStyle = $PSStyle.Bold + $PSStyle.Foreground.BrightCyan
$resetStyle = $PSStyle.Reset

if ($Stages -contains 'expand') {
    Write-Output "${headingStyle}Expand${resetStyle}"
    & $compiler $InputFile --stop-after=expand
}

if ($Stages -contains 'reduce') {
    Write-Output "${headingStyle}Reduce${resetStyle}"
    & $compiler $InputFile --stop-after=reduce --enable-reduce=both
}

if ($Stages -contains 'compile') {
    Write-Output "${headingStyle}Compile${resetStyle}"
    & $compiler $InputFile | Join-String -Separator "`t"
}

if ($Stages -contains 'interpret') {
    Write-Output "${headingStyle}Interpret${resetStyle}"
    & $compiler $InputFile | & $interpreter --show-steps | Join-String -Separator "`t"
}

if ($Stages -contains 'decode') {
    Write-Output "${headingStyle}Decode${resetStyle}"
    & $compiler $InputFile | & $interpreter --show-steps --decode="$Decode"
}
