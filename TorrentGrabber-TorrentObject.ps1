function New-TorrentObject {
    [Cmdletbinding()]
    param()

    New-Object -TypeName PSObject -Property @{
        Title         = ''
        Link          = ''
        Description   = ''
        FileName      = ''
        ContentLength = 0
        Hash          = ''
        Season        = 0
        Episode       = 0
    }
}