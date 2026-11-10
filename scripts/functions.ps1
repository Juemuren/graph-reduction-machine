function Invoke-Compiler {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [string]$File,

        [string[]]$Source,

        [Parameter(ValueFromRemainingArguments)]
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
        if (-not $File -and -not $inputSource.Count) {
            throw "No input from file or pipe."
        }

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
        if (-not $File -and -not $inputSource.Count) {
            throw "No input from file or pipe."
        }

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

        [ValidateSet('church', 'scott')]
        [string]$Encode = 'church',

        [ValidateSet('natural', 'scott-natural', 'boolean', 'integer', 'rational', 'real')]
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
