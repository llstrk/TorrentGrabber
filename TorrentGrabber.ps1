Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

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

function Get-TorrentRSSFeed-ezRSS {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RssUrl
    )

    $content = Invoke-WebRequest -Uri $RssUrl
    $xmlcontent = [xml]$content

    $results = @(($xmlcontent.rss.channel | where title -eq 'ezRSS - Search Results').item)
    $returnObjects = @()

    if ($results -eq $null -or $results.Count -eq 0 -or $results[0].GetType().Name -ne 'XmlElement') {
        Write-Verbose ('No items found in RSS feed for {0}' -f $RssUrl)
        return @()
    }

    foreach ($r in $results) {
        if ($r.description.'#cdata-section' -like '*season*episode*') {
            $newObj = New-TorrentObject

            $newObj.Title         = $r.title.'#cdata-section'
            $newObj.Description   = $r.description.'#cdata-section'
            $newObj.Link          = $r.link
            $newObj.FileName      = $r.torrent.FileName.'#cdata-section'.Replace('[','(').Replace(']',')')
            $newObj.ContentLength = [int]$r.torrent.ContentLength
            $newObj.Hash          = $r.torrent.InfoHash

            $arr = $newObj.Description.Split(';').Trim()
            $arr | % {
                if ($_.StartsWith('Season:')) {
                    $newObj.Season = ([int]$_.Replace('Season:', '').Trim())
                }
                if ($_.StartsWith('Episode:')) {
                    $newObj.Episode = ([int]$_.Replace('Episode:', '').Trim())
                }
            }

            if ($newObj.Season -eq 0 -or $newObj.Episode -eq 0) {
                Write-Verbose ('Skipping {0}, unable to resolve season and episode' -f $newObj.Title)
            }
        }
        else {
            Write-Verbose ('Skipping {0}, no season and episode found in description' -f $r.title.'#cdata-section')
        }

        Write-Verbose ('Adding {0} to return list' -f $newObj.Title)
        $returnObjects += $newObj
    }

    $returnObjects | select Title, Link, FileName, ContentLength, Season, Episode, Description, Hash
}

function Invoke-DownloadTorrentFile {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline=$true)]
        [PSObject[]]$TorrentObject,
        [Parameter(Mandatory)]
        [string]$OutDirectory
    )

    Begin {
        if (-not (Test-Path $OutDirectory)) {
            Write-Verbose "$OutDirectory not found, trying to create it..."
            New-Item -ItemType Directory $OutDirectory | Out-Null
            Write-Verbose "$OutDirectory created"
        }
    }

    Process {
        foreach ($t in $TorrentObject) {
            $outfile = Join-Path 'D:\Kode\Test' $t.FileName

            if (Test-Path $outfile) {
                Write-Verbose "$outfile already exists, skipping..."
            }
            else {
                Write-Verbose "Downloading $($t.FileName)"
                Invoke-WebRequest -Uri $t.Link -OutFile $outfile
            }
        }
    }
}

function Get-TorrentRSSFeed {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RssUrl
    )

    if ($RssUrl -like '*ezrss.it/*') {
        Get-TorrentRSSFeed-ezRSS -RssUrl $RssUrl
    }
    else {
        Write-Error ('Unknown RSS feed, unable to parse: {0}' -f $RssUrl)
    }
}

$shows = @(
    'https://ezrss.it/search/index.php?show_name=Gotham&quality=720P&mode=rss'
    'https://ezrss.it/search/index.php?show_name=How+I+Met+Your+Mother&quality=720P&mode=rss'
    'https://ezrss.it/search/index.php?show_name=The+Flash&quality=720P&mode=rss'
    'https://ezrss.it/search/index.php?show_name=Family+Guy&quality=720P&mode=rss'
    'https://ezrss.it/search/index.php?show_name=American+Dad&quality=720P&mode=rss'
    'https://ezrss.it/search/index.php?show_name=Arrow&quality=720P&mode=rss'
)

foreach ($s in $shows) {
    (Get-TorrentRSSFeed -RssUrl $s -Verbose | measure).Count
    Get-TorrentRSSFeed -RssUrl $s | Invoke-DownloadTorrentFile -ErrorAction Continue -Verbose -OutDirectory D:\Kode\Test
}