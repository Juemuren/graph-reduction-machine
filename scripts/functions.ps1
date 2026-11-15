function Invoke-Compiler {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [string]$File,

        [string[]]$Source,

        [Parameter(ValueFromRemainingArguments)]
        [ArgumentCompleter({
                Get-ToolOptionCompletion 'Invoke-Compiler' ([string]$args[2])
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
                Get-ToolOptionCompletion 'Invoke-Interpreter' ([string]$args[2])
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

function Invoke-LambdaStage {
    param(
        [string]$File,

        [string[]]$Source,

        [Parameter(Mandatory)]
        [ValidateSet('expand', 'reduce', 'compile', 'interpret', 'decode')]
        [string]$Stage,

        [ArgumentCompleter({
                foreach ($completion in Get-EncodeTypeCompletion ([string]$args[2]).Trim("'`"")) {
                    [System.Management.Automation.CompletionResult]::new($completion, $completion, 'ParameterValue', $completion)
                }
            })]
        [string]$Encode = 'church',

        [ArgumentCompleter({
                foreach ($completion in Get-DecodeTypeCompletion ([string]$args[2]).Trim("'`"")) {
                    [System.Management.Automation.CompletionResult]::new("'$completion'", $completion, 'ParameterValue', $completion)
                }
            })]
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
                    "--encode=$Encode",
                    '--stop-after=expand'
                )
            }
            'reduce' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode=$Encode",
                    '--stop-after=reduce',
                    '--enable-reduce=both'
                )
            }
            'compile' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode=$Encode"
                ) | Join-String -Separator "`t"
            }
            'interpret' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode=$Encode"
                ) | Invoke-Interpreter -Options @(
                    '--show-steps'
                ) | Join-String -Separator "`t"
            }
            'decode' {
                Invoke-Compiler -File $File -Source $inputSource -Options @(
                    "--encode=$Encode"
                ) | Invoke-Interpreter -Options @(
                    '--show-steps',
                    '--no-step-limit',
                    "--decode=$Decode"
                )
            }
        }
    }
}

function Get-EncodeTypeCompletion {
    param([string]$Prefix)

    foreach ($type in @('church', 'scott', 'binary')) {
        if ($type.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $type
        }
    }
}

function Get-DecodeTypeCompletion {
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

function Get-ToolOptionCompletion {
    param(
        [string]$CommandName,
        [string]$Word
    )

    $word = $Word.Trim("'`"")
    if ($CommandName -eq 'Invoke-Compiler' -and $word.StartsWith('--encode=')) {
        $values = Get-EncodeTypeCompletion $word.Substring(9) | ForEach-Object { "--encode=$_" }
    }
    elseif ($CommandName -eq 'Invoke-Interpreter' -and $word.StartsWith('--decode=')) {
        $values = Get-DecodeTypeCompletion $word.Substring(9) | ForEach-Object { "--decode=$_" }
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
    Get-ToolOptionCompletion $commandName ([string]$args[0])
}
