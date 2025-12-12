# VLC Real-Debrid Player (macOS)

A lightweight VLC Extension that allows you to stream torrents directly from Real-Debrid without downloading them first. It handles magnet links, automatically selects the largest file (movie), and avoids duplicate torrents.

## Features

- **Zero-Download Streaming:** Plays cached torrents instantly.
- **Smart Resume:** Detects if a magnet is already in your RD cloud to prevent duplicates.
- **Auto-Select:** Automatically identifies the largest file (the movie) in the torrent.
- **Persistent Settings:** Remembers your API Token so you only enter it once.
- **Smart Focus:** Automatically places your cursor in the correct input box based on whether your token is saved.
- **Clean UI:** Handles long filenames gracefully without breaking the dialog box.

## Installation

1.  **Download the Script**

    - Save the `real_debrid_player.lua` file to your computer.

2.  **Locate VLC Extensions Folder**

    - Open **Finder**.
    - Press `Cmd + Shift + G` (Go to Folder).
    - Paste the following path:
      ```bash
      ~/Library/Application Support/org.videolan.vlc/lua/extensions/
      ```
    - _Note: If the `lua` or `extensions` folders do not exist, create them manually._

3.  **Install**
    - Drag and drop `real_debrid_player.lua` into that folder.
    - Restart VLC.

## How to Use

1.  **Open the Extension**

    - Open VLC.
    - Go to the top menu bar: **VLC** -> **Extensions** -> **Real-Debrid Selector**.

2.  **First Time Setup**

    - **API Token:** Paste your Real-Debrid API Token into the top box.
      - _Get your token here: [https://real-debrid.com/apitoken](https://real-debrid.com/apitoken)_
    - **Magnet:** Paste your Magnet link.
    - Click **Load Files**.

3.  **Streaming**

    - The extension will fetch the file list.
    - It will automatically select the largest file (usually the main movie).
    - Click **Start & Play**.
    - The dialog will close, and your movie will start streaming in a few seconds.

4.  **Subsequent Use**
    - Next time you open the extension, your API Token will be pre-filled.
    - The cursor will automatically jump to the **Magnet** box so you can just `Cmd+V` and go.

## Troubleshooting

- **"Error: Torrent not Cached"**
  - This means the torrent is not on Real-Debrid's servers yet. This extension is designed for _cached_ content (instant streaming). If the torrent is new/rare, you must wait for RD to download it first.
- **"Error: Unrestrict failed"**
  - This usually happens if your Real-Debrid subscription has expired. Check your account status.
- **Dialog box looks empty or weird**
  - Restart VLC. Lua extensions sometimes glitch if VLC has been open for a long time.

## License

MIT License. Free to use and modify.
