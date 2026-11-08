param(
    [Parameter(Position = 0)]
    [string]$File,

    [ValidateSet('church', 'scott')]
    [string]$Encode = "church",

    [ValidateSet('natural', 'boolean', 'integer', 'rational', 'scott-natural', 'real')]
    [string]$Decode = "natural",

    [ValidateSet('expand', 'reduce', 'compile', 'interpret', 'decode')]
    [string[]]$Stages = @('decode'),

    [Parameter(ValueFromPipeline)]
    [string]$PipelineItem
)

begin {
    $source = [System.Collections.Generic.List[string]]::new()
}

process {
    if ($PSBoundParameters.ContainsKey('PipelineItem')) {
        $source.Add($PipelineItem)
    }
}

end {
    function Write-Heading {
        param([string]$Name)

        $headingStyle = $PSStyle.Bold + $PSStyle.Foreground.BrightCyan
        $resetStyle = $PSStyle.Reset
        Write-Output "${headingStyle}${Name}${resetStyle}"
    }

    function Invoke-Compiler {
        param(
            [string]$Path,
            [string[]]$Source,
            [string[]]$Options
        )

        $compiler = cabal list-bin exe:lambda-compiler
        if ($Path) {
            & $compiler $Path @Options
        }
        elseif ($Source) {
            $Source | & $compiler @Options
        }
        else {
            Write-Error "No input from file or pipe."
            exit(1)
        }
    }

    function Invoke-Interpreter {
        param(
            [Parameter(ValueFromPipeline)]
            [string]$PipelineItem,
            [string[]]$Options
        )

        begin {
            $source = [System.Collections.Generic.List[string]]::new()
        }

        process {
            if ($PSBoundParameters.ContainsKey('PipelineItem')) {
                $source.Add($PipelineItem)
            }
        }

        end {
            $interpreter = cabal list-bin exe:ski-interpreter
            $source | & $interpreter @Options
        }
    }

    if ($Stages -contains 'expand') {
        Write-Heading 'Expand'
        Invoke-Compiler -Path $File -Source $source -Options @(
            "--encode=$Encode",
            '--stop-after=expand'
        )
    }

    if ($Stages -contains 'reduce') {
        Write-Heading 'Reduce'
        Invoke-Compiler -Path $File -Source $source -Options @(
            "--encode=$Encode",
            '--stop-after=reduce',
            '--enable-reduce=both'
        )
    }

    if ($Stages -contains 'compile') {
        Write-Heading 'Compile'
        Invoke-Compiler -Path $File -Source $source -Options @(
            "--encode=$Encode"
        )
        | Join-String -Separator "`t"
    }

    if ($Stages -contains 'interpret') {
        Write-Heading 'Interpret'
        Invoke-Compiler -Path $File -Source $source -Options @(
            "--encode=$Encode"
        )
        | Invoke-Interpreter -Options @(
            '--show-steps'
        )
        | Join-String -Separator "`t"
    }

    if ($Stages -contains 'decode') {
        Write-Heading 'Decode'
        Invoke-Compiler -Path $File -Source $source -Options @(
            "--encode=$Encode"
        )
        | Invoke-Interpreter -Options @(
            '--show-steps',
            "--decode=$Decode"
        )
    }
}
