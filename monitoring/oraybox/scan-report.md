# Oraybox LAN scan — 192.168.3.0/24

- **Scan time:** 2026-09-21T15:57:04Z
- **Scanner:** `ght-faceid-server` (`192.168.3.100`)
- **Range:** `192.168.3.1`–`192.168.3.254` (`192.168.3.2/24` ≡ `192.168.3.0/24`)
- **Method:** `curl http://<ip>/` (connect timeout 1s, total 3s, follow up to 2 redirects)
- **Match:** response body contains `oraybox` (case-insensitive)
- **Parallelism:** 50 concurrent curls

## Result

**4 Oraybox devices found.** All four return the same landing page (蒲公英 / Oray) that JS-redirects to `oraybox/index.html`.

| IP | HTTP | Latency | MAC (`br1`) | Device clock (`Date`) | Admin UI |
|----|------|---------|-------------|------------------------|----------|
| [192.168.3.2](http://192.168.3.2/) | 200 | 3 ms | `a0:c5:f2:b6:be:9c` | Sat, 30 May 2026 14:23:16 GMT | [oraybox/index.html](http://192.168.3.2/oraybox/index.html) |
| [192.168.3.3](http://192.168.3.3/) | 200 | 55 ms | `a0:c5:f2:b6:c0:52` | Sat, 31 Oct 2020 09:24:27 GMT | [oraybox/index.html](http://192.168.3.3/oraybox/index.html) |
| [192.168.3.10](http://192.168.3.10/) | 200 | 4 ms | `a0:c5:f2:b6:be:b8` | Thu, 20 Aug 2026 09:07:53 GMT | [oraybox/index.html](http://192.168.3.10/oraybox/index.html) |
| [192.168.3.80](http://192.168.3.80/) | 200 | 55 ms | `a0:c5:f2:b6:be:ae` | Sat, 09 Oct 2021 13:03:48 GMT | [oraybox/index.html](http://192.168.3.80/oraybox/index.html) |

OUI `a0:c5:f2` is consistent across all four (Oray / 蒲公英). Firmware fingerprint is identical:

- `GET /` ETag `"a62-250-5f544c60"`, Last-Modified `Sun, 06 Sep 2020 02:41:36 GMT`, 592 bytes
- `GET /oraybox/index.html` ETag `"a4b-7d0-5f3cec7c"`, Last-Modified `Wed, 19 Aug 2020 09:10:20 GMT`, 2000 bytes
- Title: **蒲公英**
- Login form: `POST /cgi-bin/oraybox_login`
- Cloud portal link: `http://pgybox.oray.com/passport/login`

Device clocks on `.3` and `.80` are years behind (2020 / 2021). `.2` and `.10` are closer to the scan date but still off.

## Fingerprint (`GET /`)

All four bodies match this pattern (the match string is `oraybox`):

```html
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="refresh" content="20; URL=oraybox/index.html" />
<script language="Javascript">
        var visit_url = window.location.href;
        if (visit_url.indexOf("a.oraybox.com") != -1)
                window.location.href = "oraybox/notice.html";
        else
                window.location.href = "oraybox/index.html";
</script>
</head>
<body style="background-color: black">
</body>
</html>
```

## Scan stats

| Metric | Count |
|--------|------:|
| Hosts probed | 254 |
| HTTP responders (`code != 000`) | 29 |
| Body contains `oraybox` | **4** |

HTTP hosts that answered but did **not** contain `oraybox`:

| IP | HTTP | Effective URL | Title |
|----|------|---------------|-------|
| 192.168.3.1 | 302 | `https://192.168.3.1:443/` | |
| 192.168.3.7 | 200 | `/` | *(empty)* |
| 192.168.3.9 | 200 | `/` | |
| 192.168.3.19 | 200 | `/` | *(empty)* |
| 192.168.3.20 | 200 | `/` | *(empty)* |
| 192.168.3.22 | 200 | `/` | WEB SERVICE |
| 192.168.3.41 | 200 | `/` | *(empty)* |
| 192.168.3.42 | 200 | `/` | *(empty)* |
| 192.168.3.43 | 200 | `/` | *(empty)* |
| 192.168.3.44 | 200 | `/` | WEB |
| 192.168.3.55 | 200 | `/signin?next=%2F` | *(empty)* |
| 192.168.3.101 | 404 | `/` | |
| 192.168.3.102 | 200 | `/` | Intelligent Analysis System |
| 192.168.3.103 | 200 | `/` | |
| 192.168.3.104 | 404 | `/` | |
| 192.168.3.105 | 200 | `/` | Intelligent Analysis System |
| 192.168.3.150 | 200 | `/` | WEB |
| 192.168.3.200 | 200 | `/` | *(empty)* |
| 192.168.3.201 | 200 | `/` | *(empty)* |
| 192.168.3.203 | 200 | `/` | *(empty)* |
| 192.168.3.204 | 200 | `/` | *(empty)* |
| 192.168.3.205 | 200 | `/` | *(empty)* |
| 192.168.3.206 | 200 | `/` | *(empty)* |
| 192.168.3.223 | 200 | `/` | *(empty)* |
| 192.168.3.231 | 200 | `/` | *(empty)* |

## Reproduce

```bash
seq 1 254 | xargs -P 50 -I{} bash -c '
  ip="192.168.3.{}"
  body=$(curl -sS --max-time 3 --connect-timeout 1 -L --max-redirs 2 "http://${ip}/")
  printf "%s" "$body" | grep -qi oraybox && echo "$ip"
'
```
