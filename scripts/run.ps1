param(
    [Parameter(Position = 0)]
    [string]$File,

    [ValidateSet('expand', 'reduce', 'compile', 'interpret', 'decode')]
    [string[]]$Stages = @('decode'),

    [ValidateSet('church', 'scott')]
    [string]$Encode = "church",

    [ValidateSet('natural', 'scott-natural', 'boolean', 'integer', 'rational', 'real')]
    [string]$Decode = "natural",

    [Parameter(ValueFromPipeline)]
    [string]$PipelineItem
)

begin {
    . (Join-Path $PSScriptRoot 'functions.ps1')
    $source = [System.Collections.Generic.List[string]]::new()
}

process {
    if ($PSBoundParameters.ContainsKey('PipelineItem')) {
        $source.Add($PipelineItem)
    }
}

end {
    foreach ($stage in @('expand', 'reduce', 'compile', 'interpret', 'decode')) {
        if ($Stages -contains $stage) {
            Invoke-LambdaStage -Stage $stage -File $File -Source $source -Encode $Encode -Decode $Decode
        }
    }
}
