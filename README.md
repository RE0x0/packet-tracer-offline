# Cisco Packet Tracer 9.0.1 — (offline / no-login) patch

Run **Packet Tracer 9.0.1** on a machine with no internet and no Cisco
account: no login window, no *"main is shutting down."*, no *"DLL
Verification Failed."* — and **none of the guest-mode restrictions**.

One file does it all:

```
patch_pt.bat
```

Double-click it, approve the UAC prompt, done. Nothing else is required.

This is a port of the technique published in 
[*ByPassing Cisco Packet Tracer Login*](https://gist.github.com/ksl-fourwalls/b90aa797e3b14a2dcd41d4d803126ee9)
to **Packet Tracer 9.0.1**, whose binary layout differs from the build that
writeup targeted — and, crucially, whose **branch polarity is inverted**.

---

## The three problems it fixes

### 1. The startup "root check"

Packet Tracer shows a login dialog at startup. If you close it (or have no
account), it prints *"main is shutting down."* / *"Login Failed."* and quits
about six seconds later.

### 2. The startup DLL signature check

Packet Tracer installs a Windows loader-notification hook
(`LdrRegisterDllNotification`) and Authenticode-verifies roughly 40 of its own
DLLs — every Qt6 DLL, the Qt plugins, `libcrypto-3-x64.dll` /
`libssl-3-x64.dll` and the VC runtime. If one cannot be validated, PT shows:

> **Cisco Packet Tracer DLL Verification Failed.**
> The required DLL &lt;name&gt; cannot be verified.

…and then calls `QCoreApplication::quit()`.

Those DLLs are re-signed by **CISCO SYSTEMS, INC.**, whose code-signing
certificate chains up to `Sectigo Public Code Signing Root R46` /
`DigiCert CS RSA4096 Root G5`. Those CAs publish CRL/OCSP endpoints on the
internet, so the check can fail on a machine that cannot reach them.

### 3. Guest mode and its 3-save limit

Even with the login bypassed, the app would still identify itself as a
**guest**, and guest mode limits file saves (*"Guest users can save files up
to 3 times."*). This patch puts Packet Tracer into its **signed-in** state
instead, so none of the guest restrictions apply.

---

## Quick start

```bat
patch_pt.bat
```

| command | what it does |
|---|---|
| `patch_pt.bat` | apply the patch |
| `patch_pt.bat restore` | copy `PacketTracer.exe.bak` back over `PacketTracer.exe` |

The script:

1. asks for Administrator rights (re-launching itself elevated if needed);
2. finds `PacketTracer.exe` — next to the `.bat` first, otherwise via the
   Start Menu shortcut (`Cisco Packet Tracer.lnk` → `TargetPath`, both the
   all-users and the per-user menu), otherwise the default
   `C:\Program Files\Cisco Packet Tracer 9.0.1\bin\` path;
3. computes the **SHA-256** and refuses to touch anything that is not
   Packet Tracer 9.0.1;
4. keeps `PacketTracer.exe.bak` — the pristine original — and always patches
   that copy, so repeated runs give a byte-identical result;
5. kills any running `PacketTracer.exe` / `QtWebEngineProcess.exe`;
6. writes the bytes and prints the resulting SHA-256;
7. waits for you to press Enter before closing.

Console output:

```
  patch_pt.bat           apply patch
  patch_pt.bat restore   restore original

  elevating ...
  locating packet tracer ...
      C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe
  hashing ...
  backing up ...
  stopping packet tracer ...
  patching ...
  verifying ...
      df624dc8573abca6d54a735686accd64776eb8f8f444d97c87938f97a6f024c6
  done
```

### The backup file

```
C:\Program Files\Cisco Packet Tracer 9.0.1\bin\
    PacketTracer.exe         <- patched
    PacketTracer.exe.bak     <- pristine original
```

`patch_pt.bat restore` copies the `.bak` over the exe and leaves the `.bak`
in place, so you can restore again at any time.

---

## What it changes — 7 sites, 22 bytes

| # | file offset | VA | original | patched | effect |
|---|---|---|---|---|---|
| 1 | `0x0963880` | `0x140964480` | `0F B6 41 44 C3 CC` | `B0 00 C3 90 90 90` | the **guest flag** getter always returns 0 → never a guest |
| 2 | `0x24AAA30` | `0x1424AB630` | `8B 41 40` | `B0 01 C3` | the *"am I signed in?"* check always passes |
| 3 | `0x017DF40` | `0x14017EB40` | `8B 41 40 C3 CC` | `B8 01 00 00 00 C3` | the **portal** getter always returns 1 → the app reports `netspace` |
| 4 | `0x24A120A` | `0x1424A1E0A` | `FF D2` | `90 90` | `QDialog::exec()` is never called → no login window |
| 5 | `0x24AA8FC` | `0x1424AB4FC` | `75 15` | `EB 00` | the network reply always takes the "server did not answer" branch → the dialog is never re-shown |
| 6 | `0x24A17AA` | `0x1424A23AA` | `0F 85 59 04 00 00` | `E9 5A 04 00 00 90` | skips the netacad.com request and the *"Authentication Alert"* nag |
| 7 | `0x0127D10` | `0x140128910` | `48 89 5C 24 10` | `B0 01 C3 90 90` | the DLL signature check always reports "trusted" |

---

## Packet Tracer's own guest mode

PT 9.0.1 ships a **"Guest Login"** button in the login dialog. Its own text
says:

> *"A Cisco Netacad.com account is required to use the full features of
> Packet Tracer. Please sign in with your Netacad.com Credentials. **If you do
> not have a Netacad.com account, please click "Guest Login" button to
> proceed.**"*

That is the supported offline path if you are happy with the three-save cap.
This patch removes the cap as well.

---

## Hashes

| state | SHA-256 |
|---|---|
| pristine original | `843579cc806a41d57a4ca524d6805b97ee1f91e0ddd02ac09be8461db04b94a1` |
| patched (signed in) | `df624dc8573abca6d54a735686accd64776eb8f8f444d97c87938f97a6f024c6` |

---

## Test results

All of the following were actually run on a Windows 11 machine.

| binary | login window | after closing it | outcome |
|---|---|---|---|
| original | shows | *"Authentication Failed"* | **terminated after 6s** |
| patched | **never appears** | — | stays running, no DLL error |

`patch_pt.bat` was exercised through six scenarios: first run, second run
(idempotent), `restore`, a wrong file in the same folder (correctly refused,
file left untouched, no `.bak` created), patch again, and finally launching
the app.

---

## Caveats

* The executable is Authenticode-signed; patching invalidates that
  signature. Nothing inside Packet Tracer re-verifies it, but a **WDAC /
  AppLocker** policy on your machine could block the patched binary.
* The login path is disabled, so signing in with a real account is no longer
  possible until you restore the original.
* Site 7 disables the DLL signature check. Prefer the registry fix above if
  you want to keep that protection.

---

## Files

```
patch_pt.bat    the patcher - this is all you need
README.md       this file
```

---

## Credits

* The original technique: [*ByPassing Cisco Packet Tracer Login*](https://gist.github.com/ksl-fourwalls/b90aa797e3b14a2dcd41d4d803126ee9)
* Packet Tracer is a Cisco Systems product. This project is not affiliated
  with or endorsed by Cisco.

## Legal

This project exists for **offline / educational use of software you already
own and have installed**. It does not bypass, unlock or redistribute any
Cisco content, and it does not alter how Packet Tracer validates your
subscription. You are responsible for complying with the Cisco terms of
service that apply to your use of Packet Tracer.

## License

MIT.
