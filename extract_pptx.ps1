Add-Type -AssemblyName System.IO.Compression.FileSystem
$file = Get-ChildItem "C:\Users\asus\Desktop" -Filter "*poster_son*" | Select-Object -First 1
Write-Host "Opening: $($file.FullName)"
$zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
$slides = $zip.Entries | Where-Object { $_.FullName -like 'ppt/slides/slide*.xml' }
foreach($s in $slides) {
    Write-Host "`n=== $($s.FullName) ==="
    $reader = New-Object System.IO.StreamReader($s.Open())
    $content = $reader.ReadToEnd()
    $reader.Close()
    $matches = [regex]::Matches($content, '<a:t>([^<]+)</a:t>')
    foreach($m in $matches) {
        Write-Host $m.Groups[1].Value
    }
}
$zip.Dispose()
