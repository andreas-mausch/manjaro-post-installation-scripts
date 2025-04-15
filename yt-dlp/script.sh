sudo pacman -S --needed --noconfirm yt-dlp
mkdir -p ~/.config/yt-dlp/
cp ./config ~/.config/yt-dlp/

# https://www.reddit.com/r/youtubedl/comments/rwk1bu/download_all_playlists_by_a_youtube_channel_in/
# Example call to download all playlists from a channel:
# yt-dlp -o "%(playlist_title)s/%(upload_date>%Y-%m-%d)s - %(title)+.100U [%(id)s]" --download-archive yt-dlp-archive.txt "https://www.youtube.com/@channelname/playlists" "https://www.youtube.com/@channelname"
