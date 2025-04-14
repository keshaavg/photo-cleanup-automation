# Photo Cleanup & Organization Automation

This PowerShell-based toolkit automates the process of deduplicating, organizing, and reviewing personal photo collections. It was built to handle large archives sourced from services like Google Photos, Amazon Photos, Dropbox, and Google Drive.

---

## ✨ Features

- ✅ Detects and removes duplicate photos
- 📁 Sorts photos into folders by **Year/Month**
- 🧹 Separates orphaned metadata files for review
- 🧠 Infers missing EXIF dates from filenames
- 📦 Compatible with multiple cloud exports
- 🔁 Modular and reusable scripts
- 🔐 Designed to run locally, preserving privacy

---

## 🗂️ Folder Structure

```
photo-cleanup-automation/
├── README.md
├── LICENSE
├── scripts/
│   ├── 1_UnzipAndMoveTo_GooglePhotos.ps1
│   ├── 2_Organize-PhotosByYear.ps1
│   ├── 3_Update-Exif-And-Move.ps1
│   ├── 4_Filter-Orphan-Metadata.ps1
│   ├── 5_Media-Yearly-Summary.ps1
│   └── utils/
│       └── ProgressBar.psm1
└── Organized/
    ├── Images/
    ├── Videos/
    ├── metadata/
    └── Review/
```

---

## 🛠️ Requirements

- PowerShell 7+ (Core or Windows)
- Tools (optional but recommended):
  - [ExifTool](https://exiftool.org/)
  - [dupeGuru](https://dupeguru.voltaicideas.net/)
  - [VisiPics](http://www.visipics.info/)

---

## 🚀 How to Use

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/photo-cleanup-automation.git
   cd photo-cleanup-automation/scripts
   ```

2. **Run the scripts in order**

| Step | Script | Description |
|------|--------|-------------|
| 1 | `1_UnzipAndMoveTo_GooglePhotos.ps1` | Extract Google Takeout ZIPs |
| 2 | Manual (dupeGuru/VisiPics) | Review and remove duplicates |
| 3 | `2_Organize-PhotosByYear.ps1` | Organize photos/videos by year/month |
| 4 | `3_Update-Exif-And-Move.ps1` | Fix EXIF metadata from filename |
| 5 | `4_Filter-Orphan-Metadata.ps1` | Identify orphaned metadata JSONs |
| 6 | `5_Media-Yearly-Summary.ps1` | Generate yearly summary report |

---

## 📋 Notes

- All scripts include progress bars and clear logs
- Paths and folder names are modular and adjustable

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).