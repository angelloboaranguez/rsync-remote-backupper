# Rsync Remote Backupper 🚀

A light Bash script to perform incremental backups to a remote server using `rsync` and a custom list of files/directories.

## 📋 Requirements

- **rsync**: Installed locally and remotely.
- **SSH Key**: Access by private key to the remote server (recommended for automation without a password).

## 📁 Project Structure

- `rsync_remote.sh`: The main execution script.
- `backup_list.json`: List of absolute paths to backups.
- `.env`: Environment variables (IP, user, paths).

## ⚙️ Configuration

1. **Define paths:** Edit `backup_list.json` and include the absolute source/target paths of the files/directories you want to backup:
   ```json
   [
     {
       "source": "/var/www/html/",
       "target": "/path/to/remote/backup/web/",
       "retention_days": 90
     },
     {
       "source": "/etc/nginx/conf.d/",
       "target": "/path/to/remote/backup/nginx/",
       "retention_days": 30
     },
     {
       "source": "/home/user/data/",
       "target": "/path/to/remote/backup/data/",
       "retention_days": 180
     }
   ]

2. **Configure variables:** Edit `.env` with your credentials and paths:
   ```env
   REMOTE_USER=your_user
   REMOTE_HOST=your_remote_host
   REMOTE_BACKUPS_PATH=/path/to/remote/backup
   SSH_KEY_PATH="/path/to/your/private_key"
   DRY_RUN=false
   ```

## 📦 Usage

1. **Run the script:**
   ```bash
   ./rsync_remote.sh
   ```

2. **Schedule the sync:**
   ```bash
   crontab -e
   ```
   Add:
   ```bash
   0 2 * * * /path/to/rsync_remote.sh
   ```
   (Syncs daily at 2:00 AM)

## 📊 Notes

- The script uses `rsync` with options for incremental backups and compression.
- It is recommended to configure SSH keys without a password for automation.
- The script can be customized to include more `rsync` options.
