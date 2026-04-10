# SocialSaver

A video downloader for YouTube, TikTok, Instagram, and Twitter/X.

## Architecture

- **Backend**: Python FastAPI + yt-dlp (`baslat.py`)
- **Frontend**: Flutter Windows desktop app (`flutter_app/`)

## Setup

### Backend

```bash
python baslat.py
```

Installs all dependencies automatically on first run, then starts the server at `http://localhost:8000`.

### Flutter App

```bash
cd flutter_app
flutter pub get
flutter run -d windows
```

## Features

- Download videos from YouTube, YouTube Shorts, TikTok, Instagram, Twitter/X
- Select video quality / format
- Audio-only download (MP3)
- Download history
- Instagram cookie support (for login-required content)
- Saves files to `~/Downloads/SocialSaver/` on Windows

## Instagram

Instagram requires authentication cookies. In the app's Settings screen, upload a `cookies.txt` file exported from your browser using the "Get cookies.txt LOCALLY" extension (Edge/Chrome).

## Requirements

- Python 3.10+
- Flutter 3.24+
- FFmpeg (must be in PATH) — https://ffmpeg.org/download.html

## API

Swagger UI available at `http://localhost:8000/docs`
