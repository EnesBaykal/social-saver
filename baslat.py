"""
SocialSaver — Tek Dosya Backend + Kurulum
==========================================
Kullanım:
    python baslat.py           → kurulum yapar ve sunucuyu başlatır
    python baslat.py --kur     → sadece bağımlılıkları kurar
    python baslat.py --ip      → PC'nin yerel IP adresini gösterir

Desteklenen platformlar: YouTube, TikTok, Instagram, Facebook, Twitter/X
"""

import sys
import os
import subprocess
import io

# Windows konsolunda Türkçe/Unicode karakterlerin bozulmaması için UTF-8 zorla
if sys.stdout and hasattr(sys.stdout, 'buffer'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'buffer'):
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# --------------------------------------------------------------------------- #
#  ADIM 1: Bağımlılıkları kur (yoksa)
# --------------------------------------------------------------------------- #
REQUIRED = ["fastapi", "uvicorn", "yt_dlp", "aiosqlite", "aiofiles", "httpx"]


def _kur_bagimliliklar():
    eksik = []
    for pkg in REQUIRED:
        try:
            __import__(pkg)
        except ImportError:
            eksik.append(pkg)

    if eksik:
        print(f"[KURULUM] Eksik paketler kuruluyor: {', '.join(eksik)}")
        subprocess.check_call([
            sys.executable, "-m", "pip", "install",
            "fastapi==0.115.0",
            "uvicorn[standard]==0.30.0",
            "yt-dlp",          # her zaman son sürüm
            "aiosqlite==0.20.0",
            "aiofiles==24.1.0",
            "python-dotenv==1.0.0",
            "httpx",
            "-q",
        ])
        print("[OK] Paketler kuruldu.\n")


if "--kur" in sys.argv:
    _kur_bagimliliklar()
    sys.exit(0)

# Bağımlılıkları kontrol et
_kur_bagimliliklar()

# --------------------------------------------------------------------------- #
#  ADIM 2: Import'lar (paketler kurulduktan sonra)
# --------------------------------------------------------------------------- #
import asyncio
import uuid
import socket
from datetime import datetime
from contextlib import asynccontextmanager
from typing import Optional
from pathlib import Path

import aiosqlite
import yt_dlp
from fastapi import FastAPI, BackgroundTasks, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# --------------------------------------------------------------------------- #
#  AYARLAR
# --------------------------------------------------------------------------- #
DOWNLOAD_DIR = Path(os.getenv("DOWNLOAD_DIR", "./downloads"))
DB_PATH      = "socialsaver.db"
HOST         = os.getenv("HOST", "0.0.0.0")
PORT         = int(os.getenv("PORT", "8000"))

# Aktif görev deposu (bellekte tutulur)
tasks: dict[str, dict] = {}


# --------------------------------------------------------------------------- #
#  PYDANTIC MODELLERİ
# --------------------------------------------------------------------------- #
class VideoFormat(BaseModel):
    format_id: str
    ext: str
    resolution: str
    filesize_approx: Optional[int] = None

    @property
    def label(self) -> str:
        size = ""
        if self.filesize_approx and self.filesize_approx > 0:
            mb = self.filesize_approx / (1024 * 1024)
            size = f" • ~{mb:.1f} MB"
        if self.resolution == "audio":
            return f"Audio Only • MP3{size}"
        if self.resolution == "En İyi Kalite":
            return "Best Quality • MP4"
        return f"{self.resolution} • {self.ext.upper()}{size}"


class VideoInfo(BaseModel):
    title: str
    thumbnail: str
    duration: int
    platform: str
    formats: list[VideoFormat]
    original_url: str


class DownloadRequest(BaseModel):
    url: str
    format_id: str = "best"


class DownloadTask(BaseModel):
    id: str
    url: str
    title: str
    status: str        # pending | downloading | completed | error
    progress: float = 0.0
    filename: Optional[str] = None
    error: Optional[str] = None
    created_at: str


class HistoryItem(BaseModel):
    id: str
    title: str
    platform: str
    filename: Optional[str] = None
    downloaded_at: str
    thumbnail: Optional[str] = None


# --------------------------------------------------------------------------- #
#  VERİTABANI
# --------------------------------------------------------------------------- #
async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS downloads (
                id          TEXT PRIMARY KEY,
                url         TEXT NOT NULL,
                title       TEXT NOT NULL,
                platform    TEXT NOT NULL,
                filename    TEXT,
                thumbnail   TEXT,
                status      TEXT NOT NULL DEFAULT 'completed',
                created_at  TEXT NOT NULL
            )
        """)
        await db.commit()


async def db_save(task: DownloadTask, platform: str, thumbnail: str = ""):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT OR REPLACE INTO downloads "
            "(id, url, title, platform, filename, thumbnail, status, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (task.id, task.url, task.title, platform,
             task.filename, thumbnail, task.status, task.created_at),
        )
        await db.commit()


async def db_get_history() -> list[HistoryItem]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM downloads ORDER BY created_at DESC"
        ) as cur:
            rows = await cur.fetchall()
    return [HistoryItem(
        id=r["id"], title=r["title"], platform=r["platform"],
        filename=r["filename"], downloaded_at=r["created_at"],
        thumbnail=r["thumbnail"],
    ) for r in rows]


async def db_delete(item_id: str) -> bool:
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute("DELETE FROM downloads WHERE id = ?", (item_id,))
        await db.commit()
        return cur.rowcount > 0


async def db_clear():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("DELETE FROM downloads")
        await db.commit()


# --------------------------------------------------------------------------- #
#  PLATFORM TESPİTİ
# --------------------------------------------------------------------------- #
def detect_platform(url: str) -> str:
    u = url.lower()
    if "youtube.com" in u or "youtu.be" in u: return "youtube"
    if "tiktok.com" in u:                      return "tiktok"
    if "instagram.com" in u:                   return "instagram"
    if "twitter.com" in u or "x.com" in u:     return "twitter"
    return "other"


SUPPORTED = ["youtube.com", "youtu.be", "tiktok.com", "instagram.com",
             "twitter.com", "x.com"]


def is_supported(url: str) -> bool:
    return any(d in url.lower() for d in SUPPORTED)


# --------------------------------------------------------------------------- #
#  URL ÖN İŞLEME
# --------------------------------------------------------------------------- #
def _resolve_url(url: str) -> str:
    """
    Kısaltılmış / share URL'lerini gerçek URL'ye çevirir.
    Örn: fb.com/share/r/ID → fb.com/reel/123456
         vt.tiktok.com/XXX → tiktok.com/...
    """
    import urllib.request
    needs_resolve = any(p in url.lower() for p in [
        "vt.tiktok.com", "vm.tiktok.com",
        "instagram.com/share",
    ])
    if not needs_resolve:
        return url
    try:
        req = urllib.request.Request(url, headers={"User-Agent": _BROWSER_HEADERS["User-Agent"]})
        with urllib.request.urlopen(req, timeout=10) as resp:
            resolved = resp.url
            # Gereksiz query parametrelerini temizle
            if "?" in resolved:
                base = resolved.split("?")[0]
                # Sadece temiz URL'yi döndür
                return base
            return resolved
    except Exception:
        return url  # resolve edilemezse orijinali kullan


# --------------------------------------------------------------------------- #
#  YT-DLP: BİLGİ ÇEKME
# --------------------------------------------------------------------------- #
_BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


COOKIES_FILE = Path("cookies.txt")   # Netscape format cookie dosyası (opsiyonel)

def _export_browser_cookies() -> bool:
    """
    rookiepy ile Edge/Chrome cookie'lerini Netscape formatında dışa aktarır.
    Chrome v130+ app-bound encryption nedeniyle admin yetkisi gerekir.
    """
    try:
        import rookiepy

        def _to_netscape(cookies: list, path: Path):
            lines = ["# Netscape HTTP Cookie File"]
            for c in cookies:
                domain    = c.get("domain", "")
                flag      = "TRUE" if domain.startswith(".") else "FALSE"
                secure    = "TRUE" if c.get("secure") else "FALSE"
                expires   = str(int(c.get("expires", 0) or 0))
                name      = c.get("name", "")
                value     = c.get("value", "")
                path_c    = c.get("path", "/")
                lines.append(f"{domain}\t{flag}\t{path_c}\t{secure}\t{expires}\t{name}\t{value}")
            path.write_text("\n".join(lines), encoding="utf-8")

        for browser_fn, name in [
            (rookiepy.edge,   "Edge"),
            (rookiepy.chrome, "Chrome"),
        ]:
            try:
                cj = browser_fn(["instagram.com"])
                if cj:
                    _to_netscape(cj, COOKIES_FILE)
                    print(f"[OK] {name} cookies exported -> cookies.txt ({len(cj)} entries)")
                    return True
            except (Exception, BaseException) as e:
                msg = str(e).lower()
                if "admin" in msg or "appbound" in msg or "encryption" in msg:
                    print(f"[WARN] {name} cookies require admin rights (app-bound encryption).")
                    print("  -> Right-click baslat.py > 'Run as administrator'.")
                continue
    except (ImportError, Exception):
        pass
    return False


def _apply_cookies(opts: dict, url: str = "") -> dict:
    """Cookie dosyası geçerliyse ve platform gerektiriyorsa opts'a ekler."""
    needs_cookie = any(d in url.lower() for d in ["instagram.com", "twitter.com", "x.com"])
    if needs_cookie and COOKIES_FILE.exists() and COOKIES_FILE.stat().st_size > 100:
        opts["cookiefile"] = str(COOKIES_FILE)
    return opts


def _yt_opts_base(url: str = "") -> dict:
    """Tüm platformlar için ortak yt-dlp seçenekleri"""
    opts: dict = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "http_headers": _BROWSER_HEADERS,
    }
    return _apply_cookies(opts, url)


async def get_video_info(url: str) -> VideoInfo:
    url = _resolve_url(url)

    # Instagram/Facebook için cookie yoksa otomatik dışa aktar
    platform = detect_platform(url)
    if platform in ("instagram", "twitter") and not COOKIES_FILE.exists():
        loop0 = asyncio.get_event_loop()
        await loop0.run_in_executor(None, _export_browser_cookies)

    opts = _yt_opts_base(url)

    def _extract():
        with yt_dlp.YoutubeDL(opts) as ydl:
            return ydl.extract_info(url, download=False)

    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _extract)

    platform = detect_platform(url)
    raw = info.get("formats", [])
    seen: set[str] = set()
    filtered: list[VideoFormat] = []

    for fmt in raw:
        vcodec = fmt.get("vcodec", "none")
        acodec = fmt.get("acodec", "none")
        ext    = fmt.get("ext", "")
        height = fmt.get("height")

        # Kombine stream (hem video hem ses aynı dosyada)
        has_video = vcodec not in (None, "none")
        has_audio = acodec not in (None, "none")

        if has_video and has_audio and ext in ("mp4", "webm", "m4v") and height:
            res = f"{height}p"
            if res not in seen:
                seen.add(res)
                filtered.append(VideoFormat(
                    format_id=fmt["format_id"], ext=ext, resolution=res,
                    filesize_approx=fmt.get("filesize") or fmt.get("filesize_approx"),
                ))

    filtered.sort(key=lambda f: int(f.resolution.replace("p", "")), reverse=True)

    # "En İyi Kalite" — yt-dlp kendi en iyi formatı seçsin
    filtered.insert(0, VideoFormat(
        format_id="bv*+ba/best", ext="mp4", resolution="Best Quality"))
    # Audio only
    filtered.append(VideoFormat(
        format_id="ba/best", ext="mp3", resolution="audio"))

    return VideoInfo(
        title=info.get("title", "Untitled"),
        thumbnail=info.get("thumbnail", ""),
        duration=int(info.get("duration", 0) or 0),
        platform=platform,
        formats=filtered,
        original_url=url,
    )


# --------------------------------------------------------------------------- #
#  YT-DLP: İNDİRME
# --------------------------------------------------------------------------- #
async def download_video(task_id: str, req: DownloadRequest,
                         on_progress) -> str:
    req.url = _resolve_url(req.url)
    task_dir = DOWNLOAD_DIR / task_id
    task_dir.mkdir(parents=True, exist_ok=True)
    downloaded: list[str] = []

    def hook(d):
        if d["status"] == "downloading":
            total = d.get("total_bytes") or d.get("total_bytes_estimate", 0)
            dl    = d.get("downloaded_bytes", 0)
            if total > 0:
                on_progress(round(dl / total * 100, 1))
        elif d["status"] == "finished":
            on_progress(99.0)
            if d.get("filename"):
                downloaded.append(d["filename"])

    is_audio = req.format_id in ("ba/best", "bestaudio/best")
    pp = []
    if is_audio:
        pp.append({"key": "FFmpegExtractAudio",
                   "preferredcodec": "mp3", "preferredquality": "192"})

    # Belirtilen format_id mevcut değilse fallback zincirleri
    fmt = req.format_id
    if not is_audio and fmt not in ("bv*+ba/best", "bestvideo+bestaudio/best"):
        # Önce seçilen kalite, bulunamazsa bir alt kalite, en son "best"
        fmt = f"{fmt}/bv*+ba/best/best"

    opts = {
        "format": fmt,
        "outtmpl": str(task_dir / "%(title)s.%(ext)s"),
        "progress_hooks": [hook],
        "merge_output_format": "mp4",
        "quiet": True,
        "no_warnings": True,
        "postprocessors": pp,
    }
    opts = _apply_cookies(opts, req.url)

    def _run():
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([req.url])

    loop = asyncio.get_event_loop()
    try:
        await loop.run_in_executor(None, _run)
    except yt_dlp.DownloadError as e:
        err = str(e).lower()
        if "private" in err or "login" in err or "sign in" in err:
            raise ValueError("This content is private or requires login.")
        if "blocked" in err or "ip" in err:
            raise ValueError("IP blocked on this platform. Try a different connection.")
        if "not available" in err or "requested format" in err:
            # Retry with "best" format as fallback
            opts["format"] = "best"
            try:
                await loop.run_in_executor(None, _run)
            except Exception as e2:
                raise ValueError(f"Download failed: {str(e2)[:200]}")
            return  # fallback succeeded
        if "copyright" in err or "removed" in err:
            raise ValueError("This content has been removed due to copyright.")
        if "geo" in err or "country" in err or "region" in err:
            raise ValueError("This content is not available in your region.")
        raise ValueError(f"Download error: {str(e)[:200]}")

    # Find downloaded file
    if downloaded:
        return downloaded[-1]
    for f in task_dir.iterdir():
        return str(f)
    raise ValueError("Downloaded file not found.")


# --------------------------------------------------------------------------- #
#  ARKA PLAN GÖREVİ
# --------------------------------------------------------------------------- #
async def run_download_task(task_id: str, req: DownloadRequest):
    t = tasks[task_id]
    t["status"] = "downloading"

    # Video başlığını al
    try:
        info = await get_video_info(req.url)
        t["title"]     = info.title
        t["thumbnail"] = info.thumbnail
        t["platform"]  = info.platform
    except Exception:
        info = None

    def on_progress(pct: float):
        t["progress"] = pct

    try:
        filepath = await download_video(task_id, req, on_progress)
        fname = f"{task_id}/{Path(filepath).name}"
        t["status"]   = "completed"
        t["progress"] = 100.0
        t["filename"] = fname

        # Veritabanına kaydet
        task_obj = DownloadTask(
            id=task_id, url=req.url, title=t["title"],
            status="completed", progress=100.0,
            filename=fname, created_at=t["created_at"],
        )
        await db_save(
            task_obj,
            platform=t.get("platform", "other"),
            thumbnail=t.get("thumbnail", ""),
        )
    except ValueError as e:
        t["status"] = "error"
        t["error"]  = str(e)
    except Exception as e:
        t["status"] = "error"
        t["error"]  = f"Unexpected error: {str(e)[:200]}"


# --------------------------------------------------------------------------- #
#  FASTAPI UYGULAMASI
# --------------------------------------------------------------------------- #
@asynccontextmanager
async def lifespan(app: FastAPI):
    DOWNLOAD_DIR.mkdir(exist_ok=True)
    await init_db()

    # Instagram/Facebook için cookie export dene
    if not (COOKIES_FILE.exists() and COOKIES_FILE.stat().st_size > 100):
        try:
            loop = asyncio.get_event_loop()
            ok = await loop.run_in_executor(None, _export_browser_cookies)
        except Exception:
            ok = False
        if not ok:
            print("[WARN] Instagram cookies could not be exported.")
            print("  Fix 1: Run baslat.py as Administrator (right-click -> Run as admin).")
            print("  Fix 2: Install 'Get cookies.txt LOCALLY' in Edge/Chrome,")
            print("         login to Instagram, export -> cookies.txt")

    local_ip = _get_local_ip()
    print("\n" + "=" * 52)
    print("  SocialSaver Backend Started!")
    print("=" * 52)
    print(f"  Local   : http://localhost:{PORT}")
    print(f"  Network : http://{local_ip}:{PORT}")
    print(f"  Swagger : http://localhost:{PORT}/docs")
    cookie_status = "OK" if (COOKIES_FILE.exists() and COOKIES_FILE.stat().st_size > 100) else "MISSING (Instagram won't work)"
    print(f"  Cookie  : {cookie_status}")
    print("=" * 52 + "\n")
    yield


app = FastAPI(
    title="SocialSaver API",
    description="YouTube · TikTok · Instagram downloader",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------------------------------- #
#  ENDPOINT'LER
# --------------------------------------------------------------------------- #
@app.get("/")
async def root():
    return {"message": "SocialSaver API is running", "version": "1.0.0"}


# --- /api/info ---
@app.post("/api/info", response_model=VideoInfo)
async def api_info(req: DownloadRequest):
    """Fetch video info from URL"""
    url = req.url.strip()
    if not url:
        raise HTTPException(400, "URL cannot be empty.")
    if not is_supported(url):
        raise HTTPException(422, "Unsupported platform. "
                            "YouTube/TikTok/Instagram are supported.")
    try:
        return await get_video_info(url)
    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception as e:
        err = str(e)
        if "login" in err.lower() or "sign in" in err.lower():
            raise HTTPException(400, "This content requires login.")
        if "private" in err.lower():
            raise HTTPException(400, "This content is private.")
        raise HTTPException(500, f"Failed to get info: {err[:200]}")


# --- /api/download ---
@app.post("/api/download")
async def api_download(req: DownloadRequest, bg: BackgroundTasks):
    """Start download task"""
    task_id = str(uuid.uuid4())
    tasks[task_id] = {
        "id": task_id, "url": req.url, "title": "Loading...",
        "status": "pending", "progress": 0.0,
        "filename": None, "error": None,
        "platform": "other", "thumbnail": "",
        "created_at": datetime.now().isoformat(),
    }
    bg.add_task(run_download_task, task_id, req)
    return {"task_id": task_id}


# --- /api/progress/{id} ---
@app.get("/api/progress/{task_id}", response_model=DownloadTask)
async def api_progress(task_id: str):
    """Query download progress"""
    t = tasks.get(task_id)
    if not t:
        raise HTTPException(404, "Task not found.")
    return DownloadTask(**{k: t[k] for k in DownloadTask.model_fields})


# --- /api/history ---
@app.get("/api/history", response_model=list[HistoryItem])
async def api_history():
    return await db_get_history()


@app.delete("/api/history/{item_id}")
async def api_delete_history(item_id: str):
    ok = await db_delete(item_id)
    if not ok:
        raise HTTPException(404, "Item not found.")
    return {"success": True}


@app.delete("/api/history")
async def api_clear_history():
    await db_clear()
    return {"success": True}


# --- /api/cookies ---
@app.post("/api/cookies")
async def api_set_cookies(request: Request):
    """Cookie dosyası yükle (Netscape format — Facebook/Instagram için)"""
    body = await request.body()
    if not body:
        raise HTTPException(400, "Cookie içeriği boş.")
    COOKIES_FILE.write_bytes(body)
    return {"success": True, "message": "Cookie dosyası kaydedildi."}


@app.get("/api/cookies/status")
async def api_cookie_status():
    """Cookie dosyası mevcut mu?"""
    return {"exists": COOKIES_FILE.exists(),
            "path": str(COOKIES_FILE) if COOKIES_FILE.exists() else None}


@app.post("/api/cookies/export")
async def api_export_cookies():
    """Tarayıcı cookie'lerini otomatik dışa aktar (admin yetkisi gerekebilir)."""
    loop = asyncio.get_event_loop()
    ok = await loop.run_in_executor(None, _export_browser_cookies)
    if ok:
        return {"success": True, "message": "Cookie'ler başarıyla dışa aktarıldı."}
    raise HTTPException(500,
        "Cookie dışa aktarılamadı. "
        "Lütfen baslat.py'yi 'Yönetici olarak çalıştır' ile başlatın veya "
        "manuel olarak cookies.txt dosyasını ekleyin."
    )


# --------------------------------------------------------------------------- #
#  STATIK DOSYALAR (indirilenler)
# --------------------------------------------------------------------------- #
DOWNLOAD_DIR.mkdir(exist_ok=True)
app.mount("/api/files", StaticFiles(directory=str(DOWNLOAD_DIR)), name="files")


# --------------------------------------------------------------------------- #
#  YARDIMCI
# --------------------------------------------------------------------------- #
def _get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


# --------------------------------------------------------------------------- #
#  BAŞLAT
# --------------------------------------------------------------------------- #
if __name__ == "__main__":
    if "--ip" in sys.argv:
        print(f"Telefon icin IP: http://{_get_local_ip()}:{PORT}")
        sys.exit(0)

    import uvicorn
    uvicorn.run("baslat:app", host=HOST, port=PORT, reload=False)
