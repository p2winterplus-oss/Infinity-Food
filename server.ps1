# =====================================================
#  Infinity Frozen Food — PowerShell Backend Server
#  รัน: powershell -ExecutionPolicy Bypass -File server.ps1
# =====================================================
param([int]$Port = 8080)
$ErrorActionPreference = 'Continue'

$ADMIN_PWD   = 'infinity@2025'
$ROOT        = Split-Path -Parent $MyInvocation.MyCommand.Path
$DATA_DIR    = Join-Path $ROOT 'data'
$MENU_FILE   = Join-Path $DATA_DIR 'menu.json'
$ORDERS_FILE = Join-Path $DATA_DIR 'orders.json'
$ENC         = [System.Text.Encoding]::UTF8

# ─── HELPERS ─────────────────────────────────────────────────

function ReadJSON($file) {
    try {
        $raw = [System.IO.File]::ReadAllText($file, $ENC)
        if (-not $raw -or $raw.Trim() -eq '' -or $raw.Trim() -eq 'null') { return ,@() }
        return ,@(ConvertFrom-Json $raw)
    } catch { return ,@() }
}

function WriteJSON($file, $data) {
    $arr  = @($data)
    $json = ConvertTo-Json -InputObject $arr -Depth 10
    [System.IO.File]::WriteAllText($file, $json, $ENC)
}

function SendJSON($res, $data, [int]$code = 200) {
    $json = if ($data -is [array]) {
        ConvertTo-Json -InputObject $data -Depth 10 -Compress
    } else { $data | ConvertTo-Json -Depth 10 -Compress }
    if (-not $json) { $json = '{}' }
    $bytes = $ENC.GetBytes($json)
    $res.StatusCode      = $code
    $res.ContentType     = 'application/json; charset=utf-8'
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}

function SendFile($res, $filePath) {
    if (-not (Test-Path $filePath -PathType Leaf)) {
        $b = $ENC.GetBytes('404 Not Found')
        $res.StatusCode = 404; $res.ContentType = 'text/plain'
        $res.ContentLength64 = $b.Length
        $res.OutputStream.Write($b, 0, $b.Length)
        $res.OutputStream.Close(); return
    }
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $ext   = [System.IO.Path]::GetExtension($filePath).ToLower()
    $res.ContentType = switch ($ext) {
        '.html' { 'text/html; charset=utf-8' }
        '.css'  { 'text/css; charset=utf-8' }
        '.js'   { 'application/javascript; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        default { 'application/octet-stream' }
    }
    $res.StatusCode = 200
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}

function ReadBody($req) {
    try {
        $sr = [System.IO.StreamReader]::new($req.InputStream, $ENC)
        $raw = $sr.ReadToEnd()
        if ($raw) { ConvertFrom-Json $raw } else { $null }
    } catch { $null }
}

function IsAdmin($req) { $req.Headers['X-Admin-Password'] -eq $ADMIN_PWD }
function NowISO { (Get-Date).ToString('o') }
function NewID  { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }

# ─── INIT DATA ───────────────────────────────────────────────

if (-not (Test-Path $DATA_DIR)) { New-Item -ItemType Directory -Path $DATA_DIR | Out-Null }

if (-not (Test-Path $MENU_FILE)) {
    WriteJSON $MENU_FILE @(
        [ordered]@{id=1;name='ข้าวผัดกะเพราไก่';category='ข้าวผัด';price=45;description='ข้าวผัดกะเพราไก่สูตรต้นตำรับ รสชาติกลมกล่อม';emoji='🍚';available=$true;updatedAt=(NowISO)},
        [ordered]@{id=2;name='ข้าวมันไก่';category='ข้าวมัน';price=50;description='ข้าวมันไก่นุ่ม พร้อมน้ำจิ้มสูตรพิเศษ';emoji='🍗';available=$true;updatedAt=(NowISO)},
        [ordered]@{id=3;name='ผัดไทยกุ้ง';category='เส้น';price=55;description='ผัดไทยกุ้งสด หอมอร่อยเส้นนุ่ม';emoji='🍜';available=$true;updatedAt=(NowISO)},
        [ordered]@{id=4;name='ต้มยำกุ้ง';category='ซุป';price=65;description='ต้มยำกุ้งสูตรต้นตำรับ เผ็ดร้อนเต็มรส';emoji='🍲';available=$true;updatedAt=(NowISO)},
        [ordered]@{id=5;name='แกงเขียวหวานไก่';category='แกง';price=55;description='แกงเขียวหวานไก่สูตรโบราณ หอมกะทิ';emoji='🍛';available=$true;updatedAt=(NowISO)},
        [ordered]@{id=6;name='ข้าวผัดปู';category='ข้าวผัด';price=70;description='ข้าวผัดปูไข่เค็ม หอมมัน';emoji='🦀';available=$true;updatedAt=(NowISO)},
        [ordered]@{id=7;name='บะหมี่หมูแดง';category='เส้น';price=50;description='บะหมี่หมูแดงน้ำแดง หวานกลมกล่อม';emoji='🍝';available=$true;updatedAt=(NowISO)}
    )
}
if (-not (Test-Path $ORDERS_FILE)) { WriteJSON $ORDERS_FILE @() }

# ─── START LISTENER ──────────────────────────────────────────

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:${Port}/")
$listener.Start()

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host '   Infinity Frozen Food — Backend Server  ' -ForegroundColor White
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host "   หน้าลูกค้า : http://localhost:$Port"      -ForegroundColor Green
Write-Host "   หน้า Admin : http://localhost:$Port/admin.html" -ForegroundColor Yellow
Write-Host "   รหัส Admin : $ADMIN_PWD"                   -ForegroundColor Yellow
Write-Host "   ไฟล์ข้อมูล: $DATA_DIR"                    -ForegroundColor Gray
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host '   กด Ctrl+C เพื่อหยุดเซิร์ฟเวอร์'          -ForegroundColor Gray
Write-Host ''

# ─── REQUEST LOOP ────────────────────────────────────────────

while ($listener.IsListening) {
    $ctx = $null
    try {
        $ctx    = $listener.GetContext()
        $req    = $ctx.Request
        $res    = $ctx.Response
        $method = $req.HttpMethod
        $path   = $req.Url.LocalPath

        $res.AddHeader('Access-Control-Allow-Origin',  '*')
        $res.AddHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS')
        $res.AddHeader('Access-Control-Allow-Headers', 'Content-Type,X-Admin-Password')

        $ts = Get-Date -Format 'HH:mm:ss'
        Write-Host "$ts  $($method.PadRight(7)) $path" -ForegroundColor DarkGray

        # OPTIONS preflight
        if ($method -eq 'OPTIONS') { $res.StatusCode = 200; $res.Close(); continue }

        # ── Static files ──────────────────────────────────────
        if (-not $path.StartsWith('/api/')) {
            $fp = if ($path -eq '/') { Join-Path $ROOT 'public\index.html' }
                  else { Join-Path $ROOT ('public' + $path.Replace('/', '\')) }
            SendFile $res $fp; continue
        }

        # ── POST /api/admin/login ─────────────────────────────
        if ($method -eq 'POST' -and $path -eq '/api/admin/login') {
            $b = ReadBody $req
            if ($b.password -eq $ADMIN_PWD) { SendJSON $res @{success=$true} }
            else { SendJSON $res @{success=$false; message='รหัสผ่านไม่ถูกต้อง'} 401 }
            continue
        }

        # ── GET /api/menu ─────────────────────────────────────
        if ($method -eq 'GET' -and $path -eq '/api/menu') {
            SendJSON $res (ReadJSON $MENU_FILE); continue
        }

        # ── POST /api/menu ────────────────────────────────────
        if ($method -eq 'POST' -and $path -eq '/api/menu') {
            if (-not (IsAdmin $req)) { SendJSON $res @{success=$false;message='ไม่มีสิทธิ์'} 401; continue }
            $b = ReadBody $req
            if (-not $b.name -or -not $b.price) { SendJSON $res @{success=$false;message='กรุณากรอกชื่อและราคา'} 400; continue }
            $menu = ReadJSON $MENU_FILE
            $item = [ordered]@{
                id          = NewID
                name        = [string]$b.name
                category    = if ($b.category)    { [string]$b.category }    else { 'ทั่วไป' }
                price       = [int]$b.price
                description = if ($b.description) { [string]$b.description } else { '' }
                emoji       = if ($b.emoji)        { [string]$b.emoji }        else { '🍱' }
                available   = if ($null -ne $b.available) { [bool]$b.available } else { $true }
                updatedAt   = NowISO
            }
            WriteJSON $MENU_FILE (@($menu) + @($item))
            SendJSON $res @{success=$true; data=$item}; continue
        }

        # ── PUT / DELETE /api/menu/:id ────────────────────────
        if ($path -match '^/api/menu/(\d+)$') {
            $id = [long]$Matches[1]
            if (-not (IsAdmin $req)) { SendJSON $res @{success=$false;message='ไม่มีสิทธิ์'} 401; continue }
            $menu = @(ReadJSON $MENU_FILE)
            $idx  = -1; for ($i = 0; $i -lt $menu.Count; $i++) { if ([long]$menu[$i].id -eq $id) { $idx=$i; break } }
            if ($idx -eq -1) { SendJSON $res @{success=$false;message='ไม่พบเมนู'} 404; continue }

            if ($method -eq 'PUT') {
                $b = ReadBody $req; $m = $menu[$idx]
                if ($b.name)              { $m.name        = [string]$b.name }
                if ($b.category)          { $m.category    = [string]$b.category }
                if ($null -ne $b.price)   { $m.price       = [int]$b.price }
                if ($null -ne $b.description){ $m.description = [string]$b.description }
                if ($b.emoji)             { $m.emoji       = [string]$b.emoji }
                if ($null -ne $b.available){ $m.available  = [bool]$b.available }
                $m.updatedAt = NowISO; $menu[$idx] = $m
                WriteJSON $MENU_FILE $menu
                SendJSON $res @{success=$true; data=$m}
            } elseif ($method -eq 'DELETE') {
                WriteJSON $MENU_FILE @($menu | Where-Object { [long]$_.id -ne $id })
                SendJSON $res @{success=$true}
            }
            continue
        }

        # ── POST /api/orders ──────────────────────────────────
        if ($method -eq 'POST' -and $path -eq '/api/orders') {
            $b = ReadBody $req
            if (-not $b.customerName -or -not $b.phone -or -not $b.items -or $b.items.Count -eq 0) {
                SendJSON $res @{success=$false;message='กรุณากรอกข้อมูลให้ครบ'} 400; continue
            }
            if ($b.phone -notmatch '^\d{9,10}$') {
                SendJSON $res @{success=$false;message='เบอร์โทรต้องเป็นตัวเลข 9-10 หลัก'} 400; continue
            }
            $menuAll   = ReadJSON $MENU_FILE
            $oi = @(); $ok = $true
            foreach ($it in $b.items) {
                $m = @($menuAll | Where-Object { [long]$_.id -eq [long]$it.id })[0]
                if (-not $m) { SendJSON $res @{success=$false;message="ไม่พบเมนู id=$($it.id)"} 400; $ok=$false; break }
                $oi += [ordered]@{menuId=[long]$it.id;name=[string]$m.name;emoji=[string]$m.emoji;price=[int]$m.price;qty=[int]$it.qty}
            }
            if (-not $ok) { continue }
            $total = 0; foreach ($i in $oi) { $total += $i.price * $i.qty }
            $orders = @(ReadJSON $ORDERS_FILE)
            $order = [ordered]@{
                id           = NewID
                orderNumber  = "INF$(($orders.Count+1).ToString().PadLeft(4,'0'))"
                customerName = [string]$b.customerName
                phone        = [string]$b.phone
                address      = if ($b.address) { [string]$b.address } else { '' }
                items        = $oi
                total        = $total
                note         = if ($b.note) { [string]$b.note } else { '' }
                status       = 'pending'
                orderedAt    = NowISO
            }
            WriteJSON $ORDERS_FILE (@($orders) + @($order))
            Write-Host "   ✅ ออเดอร์ใหม่: $($order.orderNumber) | $($order.customerName) | ฿$total" -ForegroundColor Green
            SendJSON $res @{success=$true; data=$order}; continue
        }

        # ── GET /api/orders ───────────────────────────────────
        if ($method -eq 'GET' -and $path -eq '/api/orders') {
            if (-not (IsAdmin $req)) { SendJSON $res @{success=$false;message='ไม่มีสิทธิ์'} 401; continue }
            $orders = @(ReadJSON $ORDERS_FILE)
            $sf = $req.QueryString['status']; $q = $req.QueryString['search']
            if ($sf -and $sf -ne 'all') { $orders = @($orders | Where-Object { $_.status -eq $sf }) }
            if ($q) {
                $orders = @($orders | Where-Object {
                    $_.customerName -like "*$q*" -or $_.phone -like "*$q*" -or $_.orderNumber -like "*$q*"
                })
            }
            $orders = @($orders | Sort-Object { try{[datetime]$_.orderedAt}catch{[datetime]::MinValue} } -Descending)
            SendJSON $res $orders; continue
        }

        # ── PUT /api/orders/:id/status ────────────────────────
        if ($method -eq 'PUT' -and $path -match '^/api/orders/(\d+)/status$') {
            $id = [long]$Matches[1]
            if (-not (IsAdmin $req)) { SendJSON $res @{success=$false;message='ไม่มีสิทธิ์'} 401; continue }
            $b = ReadBody $req
            if (@('pending','confirmed','preparing','delivered','cancelled') -notcontains $b.status) {
                SendJSON $res @{success=$false;message='สถานะไม่ถูกต้อง'} 400; continue
            }
            $orders = @(ReadJSON $ORDERS_FILE)
            $idx = -1; for ($i=0;$i-lt$orders.Count;$i++) { if ([long]$orders[$i].id -eq $id) { $idx=$i; break } }
            if ($idx -eq -1) { SendJSON $res @{success=$false;message='ไม่พบออเดอร์'} 404; continue }
            $orders[$idx].status    = [string]$b.status
            $orders[$idx].updatedAt = NowISO
            WriteJSON $ORDERS_FILE $orders
            SendJSON $res @{success=$true; data=$orders[$idx]}; continue
        }

        # ── DELETE /api/orders/:id ────────────────────────────
        if ($method -eq 'DELETE' -and $path -match '^/api/orders/(\d+)$') {
            $id = [long]$Matches[1]
            if (-not (IsAdmin $req)) { SendJSON $res @{success=$false;message='ไม่มีสิทธิ์'} 401; continue }
            $orders = @(ReadJSON $ORDERS_FILE); $before = $orders.Count
            $orders = @($orders | Where-Object { [long]$_.id -ne $id })
            if ($orders.Count -eq $before) { SendJSON $res @{success=$false;message='ไม่พบออเดอร์'} 404; continue }
            WriteJSON $ORDERS_FILE $orders
            SendJSON $res @{success=$true}; continue
        }

        # ── GET /api/stats ────────────────────────────────────
        if ($method -eq 'GET' -and $path -eq '/api/stats') {
            if (-not (IsAdmin $req)) { SendJSON $res @{success=$false;message='ไม่มีสิทธิ์'} 401; continue }
            $orders = @(ReadJSON $ORDERS_FILE); $menu = @(ReadJSON $MENU_FILE)
            $today  = (Get-Date).Date
            $tod    = @($orders | Where-Object { try{[datetime]$_.orderedAt -ge $today}catch{$false} })
            $todRev = 0; foreach ($o in @($tod | Where-Object {$_.status -ne 'cancelled'})) { $todRev += [int]$o.total }
            $totRev = 0; foreach ($o in @($orders | Where-Object {$_.status -ne 'cancelled'})) { $totRev += [int]$o.total }
            SendJSON $res @{
                totalOrders   = $orders.Count
                todayOrders   = $tod.Count
                todayRevenue  = $todRev
                totalRevenue  = $totRev
                pendingOrders = @($orders | Where-Object {$_.status -eq 'pending'}).Count
                menuCount     = $menu.Count
                availableMenu = @($menu | Where-Object {$_.available -eq $true}).Count
            }; continue
        }

        # ── GET /api/export/orders ────────────────────────────
        if ($method -eq 'GET' -and $path -eq '/api/export/orders') {
            $pwd = $req.Headers['X-Admin-Password']
            if (-not $pwd) { $pwd = $req.QueryString['pwd'] }
            if ($pwd -ne $ADMIN_PWD) { SendJSON $res @{success=$false;message='ไม่มีสิทธิ์'} 401; continue }
            $orders = @(ReadJSON $ORDERS_FILE)
            $stTH   = @{pending='รอยืนยัน';confirmed='ยืนยันแล้ว';preparing='กำลังเตรียม';delivered='ส่งแล้ว';cancelled='ยกเลิก'}
            $rows   = @('เลขออเดอร์,ชื่อลูกค้า,เบอร์โทร,ที่อยู่,รายการ,ยอดรวม,สถานะ,วันที่สั่ง')
            foreach ($o in $orders) {
                $its  = ($o.items | ForEach-Object {"$($_.name)x$($_.qty)"}) -join ' | '
                $dt   = try{[datetime]$o.orderedAt|Get-Date -Format 'dd/MM/yyyy HH:mm'}catch{'-'}
                $st   = if ($stTH[$o.status]) {$stTH[$o.status]} else {$o.status}
                $rows += "`"$($o.orderNumber)`",`"$($o.customerName)`",`"$($o.phone)`",`"$($o.address)`",`"$its`",`"$($o.total)`",`"$st`",`"$dt`""
            }
            $bytes = $ENC.GetBytes([char]0xFEFF + ($rows -join "`n"))
            $res.StatusCode = 200; $res.ContentType = 'text/csv; charset=utf-8'
            $res.AddHeader('Content-Disposition','attachment; filename="orders.csv"')
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.OutputStream.Close(); continue
        }

        # ── 404 ───────────────────────────────────────────────
        SendJSON $res @{success=$false; message="ไม่พบ endpoint: $method $path"} 404

    } catch {
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        try { if ($ctx) { SendJSON $ctx.Response @{success=$false;message='Internal server error'} 500 } } catch {}
    }
}
