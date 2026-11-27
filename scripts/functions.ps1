[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseApprovedVerbs',
    '',
    Scope = 'Function',
    Target = '_GRM_GET-.*',
    Justification = 'Internal helper namespace'
)]
param()

function Invoke-Compiler {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [string]$File,

        [string[]]$Source,

        [Parameter(ValueFromRemainingArguments)]
        [ArgumentCompleter({
                _GRM_GET-OptionCompletion 'Invoke-Compiler' ([string]$args[2])
            })]
        [string[]]$Options,

        [Parameter(ValueFromPipeline)]
        [string]$PipelineItem
    )

    begin {
        $inputSource = [System.Collections.Generic.List[string]]::new()
        if ($Source) {
            $inputSource.AddRange($Source)
        }
    }

    process {
        if ($PSBoundParameters.ContainsKey('PipelineItem')) {
            $inputSource.Add($PipelineItem)
        }
    }

    end {
        $compiler = cabal list-bin exe:lambda-compiler
        if ($File) {
            & $compiler $File @Options
        }
        else {
            $inputSource | & $compiler @Options
        }
    }
}

function Invoke-Interpreter {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [string]$File,

        [string[]]$Source,

        [Parameter(ValueFromRemainingArguments)]
        [ArgumentCompleter({
                _GRM_GET-OptionCompletion 'Invoke-Interpreter' ([string]$args[2])
            })]
        [string[]]$Options,

        [Parameter(ValueFromPipeline)]
        [string]$PipelineItem
    )

    begin {
        $inputSource = [System.Collections.Generic.List[string]]::new()
        if ($Source) {
            $inputSource.AddRange($Source)
        }
    }

    process {
        if ($PSBoundParameters.ContainsKey('PipelineItem')) {
            $inputSource.Add($PipelineItem)
        }
    }

    end {
        $interpreter = cabal list-bin exe:ski-interpreter
        if ($File) {
            & $interpreter $File @Options
        }
        else {
            $inputSource | & $interpreter @Options
        }
    }
}

function Invoke-IntegrationStage {
    param(
        [string]$File,

        [string[]]$Source,

        [Parameter(Mandatory)]
        [string]$Stage,

        [string]$EncodeNatural = 'church',

        [string]$EncodeString = 'church<binary>',

        [string]$Decode = 'natural',

        [Parameter(ValueFromPipeline)]
        [string]$PipelineItem
    )

    begin {
        $inputSource = [System.Collections.Generic.List[string]]::new()
        if ($Source) {
            $inputSource.AddRange($Source)
        }
    }

    process {
        if ($PSBoundParameters.ContainsKey('PipelineItem')) {
            $inputSource.Add($PipelineItem)
        }
    }

    end {
        $headingStyle = $PSStyle.Bold + $PSStyle.Foreground.BrightCyan
        $resetStyle = $PSStyle.Reset
        $heading = $Stage.Substring(0, 1).ToUpperInvariant() + $Stage.Substring(1)
        Write-Output "${headingStyle}${heading}${resetStyle}"

        switch ($Stage) {
            'expand' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode-natural=$EncodeNatural",
                    "--encode-string=$EncodeString",
                    '--stop-after=expand'
                )
            }
            'reduce' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode-natural=$EncodeNatural",
                    "--encode-string=$EncodeString",
                    '--stop-after=reduce',
                    '--reduce=both'
                )
            }
            'compile' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode-natural=$EncodeNatural",
                    "--encode-string=$EncodeString"
                ) | Join-String -Separator "`t"
            }
            'interpret' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode-natural=$EncodeNatural",
                    "--encode-string=$EncodeString"
                ) | Invoke-Interpreter -Options @(
                    '--show-steps'
                ) | Join-String -Separator "`t"
            }
            'decode' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode-natural=$EncodeNatural",
                    "--encode-string=$EncodeString"
                ) | Invoke-Interpreter -Options @(
                    '--show-steps',
                    '--max-steps=infty',
                    "--decode=$Decode"
                )
            }
        }
    }
}

function Invoke-IntegrationSequence {
    param(
        [Parameter(Position = 0)]
        [string]$File,

        [string[]]$Source,

        [string[]]$Stages = @('decode'),

        [string]$EncodeNatural = 'church',

        [string]$EncodeString = 'church<binary>',

        [string]$Decode = 'natural',

        [Parameter(ValueFromPipeline)]
        [string]$PipelineItem
    )

    begin {
        $inputSource = [System.Collections.Generic.List[string]]::new()
        if ($Source) {
            $inputSource.AddRange($Source)
        }
    }

    process {
        if ($PSBoundParameters.ContainsKey('PipelineItem')) {
            $inputSource.Add($PipelineItem)
        }
    }

    end {
        foreach ($stage in @(_GRM_GET-StageCompletion '')) {
            if ($Stages -contains $stage) {
                Invoke-IntegrationStage -File $File -Source $inputSource `
                    -Stage $stage `
                    -EncodeNatural $EncodeNatural `
                    -EncodeString $EncodeString `
                    -Decode $Decode
            }
        }
    }
}

function _GRM_GET-StageCompletion {
    param([string]$Prefix)

    foreach ($stage in @('expand', 'reduce', 'compile', 'interpret', 'decode')) {
        if ($stage.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $stage
        }
    }
}

function _GRM_GET-EncodeNaturalCompletion {
    param([string]$Prefix)

    foreach ($type in @('church', 'scott', 'binary')) {
        if ($type.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $type
        }
    }
}

function _GRM_GET-EncodeStringCompletion {
    param([string]$Prefix)

    foreach ($type in @('church<church>', 'church<scott>', 'church<binary>', 'scott<church>', 'scott<scott>', 'scott<binary>')) {
        if ($type.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $type
        }
    }
}

function _GRM_GET-DecodeCompletion {
    param([string]$InputType)

    $remaining = $InputType
    $prefix = ''
    $expected = 'type'
    $stack = [System.Collections.Generic.List[string]]::new()
    $atomPattern = '^(natural|scott-natural|binary-natural|boolean|integer|rational|string|real)(?=[,>]|$)'

    while ($remaining.Length -gt 0) {
        if ($expected -eq 'type') {
            if ($remaining.StartsWith('list<')) {
                $stack.Add('list')
                $prefix += 'list<'
                $remaining = $remaining.Substring(5)
            }
            elseif ($remaining.StartsWith('pair<')) {
                $stack.Add('pair-first')
                $prefix += 'pair<'
                $remaining = $remaining.Substring(5)
            }
            elseif ($remaining -match $atomPattern -and ($Matches[1] -ne 'real' -or $stack.Count -eq 0)) {
                $prefix += $Matches[1]
                $remaining = $remaining.Substring($Matches[1].Length)
                $expected = 'after'
            }
            else {
                break
            }
        }
        else {
            $top = if ($stack.Count -gt 0) { $stack[$stack.Count - 1] } else { '' }
            if ($top -eq 'pair-first' -and $remaining.StartsWith(',')) {
                $stack[$stack.Count - 1] = 'pair-second'
                $prefix += ','
                $remaining = $remaining.Substring(1)
                $expected = 'type'
            }
            elseif (($top -eq 'list' -or $top -eq 'pair-second') -and $remaining.StartsWith('>')) {
                $stack.RemoveAt($stack.Count - 1)
                $prefix += '>'
                $remaining = $remaining.Substring(1)
            }
            else {
                break
            }
        }
    }

    if ($expected -eq 'type') {
        $types = @('natural', 'scott-natural', 'binary-natural', 'boolean', 'integer', 'rational', 'string', 'list<', 'pair<')
        if ($stack.Count -eq 0) {
            $types += 'real'
        }
        foreach ($type in $types) {
            if ($type.StartsWith($remaining, [System.StringComparison]::OrdinalIgnoreCase)) {
                "$prefix$type"
            }
        }
    }
    elseif ($remaining.Length -eq 0 -and $stack.Count -gt 0) {
        switch ($stack[$stack.Count - 1]) {
            'list' { "$prefix>" }
            'pair-first' { "$prefix," }
            'pair-second' { "$prefix>" }
        }
    }
}

function _GRM_GET-OptionCompletion {
    param(
        [string]$CommandName,
        [string]$Word
    )

    $word = $Word.Trim("'`"")
    if ($CommandName -eq 'Invoke-Compiler' -and $word.StartsWith('--encode-natural=')) {
        $values = _GRM_GET-EncodeNaturalCompletion $word.Substring(17) | ForEach-Object { "--encode-natural=$_" }
    }
    elseif ($CommandName -eq 'Invoke-Compiler' -and $word.StartsWith('--encode-string=')) {
        $values = _GRM_GET-EncodeStringCompletion $word.Substring(16) | ForEach-Object { "--encode-string=$_" }
    }
    elseif ($CommandName -eq 'Invoke-Interpreter' -and $word.StartsWith('--decode=')) {
        $values = _GRM_GET-DecodeCompletion $word.Substring(9) | ForEach-Object { "--decode=$_" }
    }
    else {
        return
    }

    foreach ($value in $values) {
        [System.Management.Automation.CompletionResult]::new("'$value'", $value, 'ParameterValue', $value)
    }
}

# Arguments after -- use native completion; -Options uses the parameter completers above.
Register-ArgumentCompleter -Native -CommandName Invoke-Compiler, Invoke-Interpreter -ScriptBlock {
    $commandName = $args[1].CommandElements[0].Value
    _GRM_GET-OptionCompletion $commandName ([string]$args[0])
}

Register-ArgumentCompleter -CommandName Invoke-IntegrationStage, Invoke-IntegrationSequence -ParameterName EncodeNatural -ScriptBlock {
    $prefix = ([string]$args[2]).Trim("'`"")
    foreach ($completion in _GRM_GET-EncodeNaturalCompletion $prefix) {
        [System.Management.Automation.CompletionResult]::new($completion, $completion, 'ParameterValue', $completion)
    }
}

Register-ArgumentCompleter -CommandName Invoke-IntegrationStage, Invoke-IntegrationSequence -ParameterName EncodeString -ScriptBlock {
    $prefix = ([string]$args[2]).Trim("'`"")
    foreach ($completion in _GRM_GET-EncodeStringCompletion $prefix) {
        [System.Management.Automation.CompletionResult]::new("'$completion'", $completion, 'ParameterValue', $completion)
    }
}

Register-ArgumentCompleter -CommandName Invoke-IntegrationStage, Invoke-IntegrationSequence -ParameterName Decode -ScriptBlock {
    $prefix = ([string]$args[2]).Trim("'`"")
    foreach ($completion in _GRM_GET-DecodeCompletion $prefix) {
        [System.Management.Automation.CompletionResult]::new("'$completion'", $completion, 'ParameterValue', $completion)
    }
}

foreach ($parameter in @('Stage', 'Stages')) {
    Register-ArgumentCompleter -CommandName Invoke-IntegrationStage, Invoke-IntegrationSequence -ParameterName $parameter -ScriptBlock {
        $prefix = ([string]$args[2]).Trim("'`"")
        foreach ($completion in _GRM_GET-StageCompletion $prefix) {
            [System.Management.Automation.CompletionResult]::new($completion, $completion, 'ParameterValue', $completion)
        }
    }
}
