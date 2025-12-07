# Test Fixtures

This directory contains sample media files for testing filter logic.

## Creating Test Files

### Audio File (test-audio.mp3)
```bash
# Create a simple MP3 file with known properties
ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" -b:a 128k test-audio.mp3
```

Properties:
- Format: MPEG Audio
- Bitrate: 128000
- Duration: 5s

### Video File (test-video.mp4)
```bash
# Create a simple MP4 file with known properties
ffmpeg -f lavfi -i "testsrc=duration=5:size=1280x720:rate=30" \
       -c:v libx264 -b:v 800k test-video.mp4
```

Properties:
- Format: AVC (H.264)
- Resolution: 1280x720
- Bitrate: ~800000

### Image File (test-image.jpg)
```bash
# Create a simple JPEG file
convert -size 800x600 xc:blue test-image.jpg
```

Properties:
- Format: JPEG
- Size: 800x600

### Text File (test-file.txt)
```bash
echo "Test content for filter matching" > test-file.txt
```

Properties:
- MimeType: text/plain

## Alternative: Using Provided Samples

If ffmpeg/imagemagick are not available, you can use any media files with similar properties.
The tests will use `mediainfo` to verify actual properties match expected values.
