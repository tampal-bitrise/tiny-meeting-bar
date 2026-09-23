# MeetingBar

A tiny macOS menu bar app that shows your next calendar meeting and how soon it starts.

- Menu bar shows the next meeting's title and time (e.g. `Standup · in 12m`), or a calendar icon when nothing is coming up
- Click it to see the next few meetings in the coming 36 hours
- Skips all-day events and meetings you've declined
- Reads from macOS Calendar, so any account added there (iCloud, Google, Exchange…) works

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (for `swiftc` and `codesign`):

  ```sh
  xcode-select --install
  ```

## Install

1. Clone and build:

   ```sh
   git clone <repo-url> meeting-bar
   cd meeting-bar
   ./build.sh
   ```

   This produces an ad-hoc signed app at `build/MeetingBar.app`.

2. Copy it to Applications and launch it:

   ```sh
   cp -R build/MeetingBar.app /Applications/
   open /Applications/MeetingBar.app
   ```

3. Grant calendar access when prompted. If you denied it, click the `⚠︎ Calendar` item in the menu bar and choose **Open Privacy Settings…**, or go to **System Settings → Privacy & Security → Calendars** and enable MeetingBar.

### Launch at login

Open **System Settings → General → Login Items** and add `MeetingBar.app` under **Open at Login**.

## Uninstall

```sh
pkill -x MeetingBar || true
rm -rf /Applications/MeetingBar.app
tccutil reset Calendar com.tampal.meetingbar
```
