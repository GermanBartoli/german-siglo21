function Test-Camara {
 $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
 $listener.Start()
 $port = $listener.LocalEndpoint.Port
 $token = [Guid]::NewGuid().ToString('N')
 $profile = Join-Path $env:TEMP ('german-siglo21-camara-' + $token)
 $answer = @{ok=$false; detail='No se completo la prueba en 60 segundos.'}
 $page = @'
<!doctype html><html lang="es"><meta charset="utf-8"><title>German Siglo21 | Camara</title>
<style>body{background:#0b1220;color:#edf3ff;font:20px Segoe UI;text-align:center;margin:32px}video{width:80vw;height:65vh;object-fit:contain;background:black}p{margin:12px}</style>
<h1>German Siglo21 · Camara</h1><p id="status">Permiti el acceso a la camara. No se graba ni se envia imagen.</p><video autoplay muted playsinline></video>
<script>
const video=document.querySelector('video'),status=document.querySelector('#status');
let stream,ended=false,frames=0,first,last,watchdog;
async function finish(ok,detail){if(ended)return;ended=true;clearInterval(watchdog);if(stream)stream.getTracks().forEach(t=>t.stop());video.srcObject=null;status.textContent=detail;try{await fetch('/result?token=TOKEN&ok='+ok+'&detail='+encodeURIComponent(detail));}catch(e){status.textContent+=' No se pudo informar a la terminal.';}}
async function iniciarCamara(){try{stream=await navigator.mediaDevices.getUserMedia({video:true,audio:false});if(ended){stream.getTracks().forEach(t=>t.stop());return;}video.srcObject=stream;await video.play();watchdog=setInterval(()=>{if(last&&performance.now()-last>1500)finish(false,'ERROR: la camara dejo de entregar imagenes.');},250);function frame(now){if(ended)return;frames++;first??=now;last=now;status.textContent='Camara en vivo: '+Math.max(0,5-(now-first)/1000).toFixed(1)+' s';if(now-first>=5000){finish(true,'OK: imagen recibida durante 5 segundos ('+frames+' cuadros, '+video.videoWidth+'x'+video.videoHeight+').');return;}video.requestVideoFrameCallback(frame);}video.requestVideoFrameCallback(frame);}catch(e){finish(false,'ERROR de camara: '+e.name+'. '+e.message);}}
iniciarCamara();
setTimeout(()=>finish(false,'ERROR: tiempo de espera agotado.'),55000);
</script></html>
'@
 $page = $page.Replace('TOKEN',$token)
 try {
  $edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $edge) { throw 'Microsoft Edge no esta instalado.' }
  Write-Host 'Se abrira la prueba. Permite el acceso si Edge lo solicita; se muestra durante 5 segundos.'
  $previewProcess = Start-Process -PassThru -FilePath $edge -ArgumentList @('--no-first-run',('--user-data-dir="'+$profile+'"'),('--app=http://127.0.0.1:'+ $port +'/'))
  $deadline = [DateTime]::UtcNow.AddSeconds(60)
  while ([DateTime]::UtcNow -lt $deadline) {
   if (-not $listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
   $client = $listener.AcceptTcpClient()
   try {
    $client.ReceiveTimeout=2000; $client.SendTimeout=2000
    $net=$client.GetStream(); $reader=[IO.StreamReader]::new($net)
    $line=$reader.ReadLine(); if (-not $line) { continue }
    do { $header=$reader.ReadLine() } while ($header)
    $path=($line -split ' ')[1]; $body=$page; $done=$false
    if ($path.StartsWith('/result?')) {
     $query=@{}; foreach ($pair in $path.Substring(8).Split('&')) { $kv=$pair.Split('=',2); if($kv.Count -eq 2){$query[$kv[0]]=[Uri]::UnescapeDataString($kv[1])} }
     if ($query.token -eq $token) { $answer=@{ok=($query.ok -eq 'true');detail=$query.detail}; $done=$true; $body='Resultado recibido. Podes cerrar esta ventana.' }
    }
    $bytes=[Text.Encoding]::UTF8.GetBytes($body)
    $headers=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n")
    $net.Write($headers,0,$headers.Length); $net.Write($bytes,0,$bytes.Length)
    if ($done) { break }
   } catch { Write-Host ('Aviso de conexion local: '+$_.Exception.Message) } finally { $client.Close() }
  }
 } catch { $answer=@{ok=$false;detail=$_.Exception.Message} }
 finally {
  $listener.Stop()
  try { Get-CimInstance Win32_Process -Filter "name='msedge.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$token*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } } catch { Write-Host 'No se pudo consultar el cierre de la ventana de prueba.' }; if ($previewProcess) { Stop-Process -Id $previewProcess.Id -Force -ErrorAction SilentlyContinue }
 }
 return $answer
}
