# Local Cloudflare Tunnel

The SGU demo's primary public address is `https://sgu.lucasact4.com.br/`, served through the named tunnel `sgu-lucasact4`. The root domain `https://lucasact4.com.br/` also remains routed to the same local application. It works behind CGNAT without forwarding router ports. The domain remains registered at Registro.br; Cloudflare provides its authoritative DNS.

Cloudflare activation is complete. On **2026-10-19**, the coordinator verified HTTP 200 over HTTPS for `/`, `/up`, and `/apresentacao` on both `sgu.lucasact4.com.br` and `lucasact4.com.br`. The `sgu` DNS CNAME, tunnel ingress, and Rails allowed host are in place; the root route remains available.

The earlier HTTP 502 was caused by the Rails containers/application being stopped. Starting Docker and the Dev Container, running `bin/dev`, and restoring VS Code forwarding to Windows `127.0.0.1:3000` restored public access. The normal startup requirements below still apply.

## Installed components

Windows PowerShell paths:

| Component | Location |
| --- | --- |
| Official `cloudflared` executable, version installed: 2026.10.1 | `$env:LOCALAPPDATA\Programs\cloudflared\cloudflared.exe` |
| Account certificate, tunnel credentials, and configuration | `$env:USERPROFILE\.cloudflared` |
| Named tunnel configuration | `$env:USERPROFILE\.cloudflared\sgu-lucasact4.yml` |
| Connector log, JSON at `info` level | `$env:USERPROFILE\.cloudflared\sgu-lucasact4.log` |
| Login startup shortcut | `SGU Cloudflare Tunnel.lnk` in the current user's Windows Startup folder |

The executable directory was added to the user's PATH. Open a new PowerShell session to pick up that change, or use the full executable path below. Keep the account certificate and tunnel credentials outside the repository; do not copy their contents into issues, screenshots, or documentation.

The named configuration maps both `sgu.lucasact4.com.br` and `lucasact4.com.br` to `http://127.0.0.1:3000` on Windows and returns HTTP 404 for unmatched hostnames. Rails development configuration explicitly allows both hosts.

## Normal startup and checks

1. Start Docker, open this project in its VS Code Dev Container, and run `bin/dev` in the container terminal if Rails is not already running.
2. In VS Code **Ports**, verify that this project's container port 3000 forwards to Windows port 3000. Compose does not publish a host port itself. Another local application also uses port 3000, so verify the forwarded address belongs to SGU rather than relying on an HTTP success status alone.
3. On Windows, open `http://127.0.0.1:3000/apresentacao` and check the SGU presentation title and content. If VS Code selected another local port, resolve the conflict and restore local port 3000 before using this tunnel configuration.
4. The startup shortcut launches the connector when the Windows user signs in. It does not start Docker, Rails, or VS Code forwarding. Check the connector before starting another copy:

   ```powershell
   Get-CimInstance Win32_Process -Filter "Name = 'cloudflared.exe'" |
     Where-Object { $_.CommandLine -like '*sgu-lucasact4.yml*' } |
     Select-Object ProcessId, CommandLine
   ```

5. Check `https://sgu.lucasact4.com.br/`, `https://sgu.lucasact4.com.br/up`, and `https://sgu.lucasact4.com.br/apresentacao` for HTTP 200. Open the presentation from a phone using mobile data and confirm its SGU title and content before sharing the link. Recheck the root-domain routes after the ingress change.

Keep the PC awake, its Internet connection available, Rails running, VS Code port forwarding active, and the connector running throughout the demo. A connected tunnel alone does not confirm that Rails is reachable.

## Restart the connector

Run in Windows PowerShell as the same user who installed the tunnel. Stop only connector processes using this named configuration before launching a replacement:

```powershell
$sguConnector = Join-Path $env:LOCALAPPDATA 'Programs\cloudflared\cloudflared.exe'
$sguConfig = Join-Path $env:USERPROFILE '.cloudflared\sgu-lucasact4.yml'

Get-CimInstance Win32_Process -Filter "Name = 'cloudflared.exe'" |
  Where-Object { $_.CommandLine -like '*sgu-lucasact4.yml*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId }

& $sguConnector tunnel --config $sguConfig run sgu-lucasact4
```

This manual run stays attached to the terminal; leave it open during use and press Ctrl+C to stop it. When diagnosing connection failures, first confirm the local presentation works from Windows, then inspect the connector output and Cloudflare's tunnel status. If Rails reports a blocked host, confirm the development server restarted after the allowed-host change.

Read recent connector messages in Windows PowerShell:

```powershell
Get-Content -LiteralPath (Join-Path $env:USERPROFILE '.cloudflared\sgu-lucasact4.log') -Tail 30
```

The connector launched during setup also redirects process output to `$env:TEMP\sgu-cloudflared-run.txt` and `$env:TEMP\sgu-cloudflared-run-err.txt`. Those temporary files belong to that launch; use the configured log above for subsequent runs. Four QUIC connections were observed during setup. Connector status alone does not establish application availability; use the local and public checks above.

## Disable login startup

Delete only the installed shortcut:

```powershell
$sguStartup = [Environment]::GetFolderPath('Startup')
Remove-Item -LiteralPath (Join-Path $sguStartup 'SGU Cloudflare Tunnel.lnk')
```

Removing the shortcut prevents future automatic launches; it does not stop a connector that is already running or delete its credentials.

## Presentation QR code and deployment scope

The public presentation address is `https://sgu.lucasact4.com.br/apresentacao#s-capa`. `links.apresentacao` in [entrega.yml](../config/presentation/entrega.yml) now uses that address. Regenerate `app/assets/images/presentation/acesso/apresentacao-qr.png` with the exact same URL, including the fragment. The [QR generator](../script/gerar_qr_apresentacao.py) uses high error correction (H) and centers the existing `app/assets/images/brand/sgu-simbolo.png` on a white badge by default; no branding option is required. The coordinator decoded the served QR PNG to that exact URL and the local branded PNG at 784, 328, 240, and 180 pixels. See [presentation QR instructions](../config/presentation/LEIAME.md#presentation-timer-and-public-access) and [Run and export PDF](../config/presentation/LEIAME.md#run-and-export-pdf).

The public presentation HTML contains the new URL and no ngrok references; all 30 HTML-referenced local assets returned HTTP 200 over HTTPS. The public PDF download with CSRF also returned HTTP 200, with 14 pages and annotation links using the new subdomain without ngrok. See [dated verification results](apresentacao-refinamento-revisao.md#19102026--public-subdomain-verification) for the test result and export artifact. The new PDF's QR raster and physical-phone scanning were not tested.

Previously exported PDFs and printed QR codes that contain the former ngrok address or the root-domain presentation address must be regenerated and replaced before redistribution. Updating the source URL and PNG does not update existing exports or printed copies.

This workflow exposes the development application for a demo. Persistent public hosting needs a production configuration; the tunnel does not change development error reporting, mail delivery, storage, or process management. See [first deployment](first-deploy.md) when preparing that deployment.

Official references: [Cloudflare Tunnel setup](https://developers.cloudflare.com/tunnel/get-started/) and [Registro.br account and domain management](https://registro.br/ajuda/gerenciamento-de-conta).
