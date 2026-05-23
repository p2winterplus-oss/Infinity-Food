$port = 8080
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving at http://localhost:$port/"

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response

        $urlPath = $request.Url.LocalPath
        if ($urlPath -eq '/') { $urlPath = '/index.html' }

        $filePath = Join-Path $root "public$urlPath"

        if (Test-Path $filePath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $ext   = [System.IO.Path]::GetExtension($filePath).ToLower()
            $response.ContentType = switch ($ext) {
                '.html' { 'text/html; charset=utf-8' }
                '.css'  { 'text/css; charset=utf-8' }
                '.js'   { 'application/javascript; charset=utf-8' }
                '.json' { 'application/json; charset=utf-8' }
                default { 'application/octet-stream' }
            }
            $response.StatusCode      = 200
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $msg = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
            $response.StatusCode      = 404
            $response.ContentLength64 = $msg.Length
            $response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $response.OutputStream.Flush()
        $response.OutputStream.Close()
    } catch { }
}
