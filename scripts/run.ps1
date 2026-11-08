param(
    [Parameter(Position = 0)]
    [string]$File,

    [string[]]$Source,

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
    foreach ($stage in @('expand', 'reduce', 'compile', 'interpret', 'decode')) {
        if ($Stages -contains $stage) {
            Invoke-LambdaStage -File $File -Source $inputSource `
                -Stage $stage `
                -Encode $Encode `
                -Decode $Decode
        }
    }
}
