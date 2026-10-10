# i2ME 1.0.2

A Java ME game emulator for older iOS devices. Made by Griszek (with help of ChatGPT 6.1).

Based on [JarBox](https://github.com/ccbkv/J2MEEmulator-iOS) and powered by miniJVM. This is an early release; compatibility varies between games.

## Requirements and installation

- **ARMv7**, minimum **iOS 5.0**, built with the iOS 6.1 SDK. Primary target: iPhone 4 running iOS 6.
- The release IPA is **unsigned**. Installation requires your own signing certificate and provisioning profile, or a jailbroken device configured to install unsigned apps. Jailbreak alone may not be enough.
- The updated build was confirmed working by the project owner on an iPhone 4 running iOS 7.1.2. ARMv6 and iOS 3 are not supported.
- Testing was performed in the iOS 6.1 simulator. No commercial games or user data are included.

## Using i2ME

1. Copy your own JAR files into the app's Documents folder using iTunes File Sharing, or open a JAR with i2ME.
2. Refresh the library. On a game's first launch, choose its screen resolution and FPS limit.
3. Swipe a game row right to reveal the blue **Edit** button, or left to reveal the red **Delete** button.
4. Edit the game's name, icon, resolution and FPS limit.
5. Open **Settings** in the top-left corner to select one of 11 languages and view app information. Some help text falls back to English.

## Save backups

Backups contain **RMS data**, the game's persistent saved data. Full JVM save states are not implemented: backups do not capture the current frame, JVM memory or thread stacks.

Opening backups during gameplay stops the MIDlet and displays the backup list. Opening the list does not create a backup. Tap **+** to create one, select a backup to restore it, or swipe its row to delete it. Games may save their own RMS data when they close.

## Building

Verified build environment: OS X 10.8.5, Xcode 4.6 and the iOS 6.1 SDK. The script expects Xcode at `/Applications/Xcode.app`.

```sh
bash build.sh iphoneos armv7
bash build.sh iphonesimulator i386
```

Output: `build/armv7/LegacyJ2ME.app` or `build/i386/LegacyJ2ME.app`. The executable and bundle identifier retain the port's internal names; the displayed app name is i2ME.

To create an IPA, place the ARMv7 app inside a `Payload` folder, keep the `.app` extension, and ZIP the Payload folder into a file with the `.ipa` extension. Signing is a separate step.

The build uses the included runtime JAR files. Java ME API sources are in `JavaAPI/src`. After changing them, rebuild `Resources/j2me_api.jar` separately using a JDK that supports `javac --release 8`. After changing C headers, remove your generated `build` directory before rebuilding to avoid reusing outdated object files.

## Testing and known limitations

- ARMv7 and i386 builds completed successfully. The device executable declares a minimum iOS version of 5.0 and SDK version 6.1.
- Demo testing covered 2D rendering, keypad input and RMS in the simulator.
- A private Plants vs Zombies test passed startup after working around an AudioToolbox crash. A full playthrough has not been verified.
- On iPhone 4, enabling sound in Plants vs Zombies causes severe slowdown; keep sound disabled for now.
- MIDI is muted in the simulator because the legacy AudioToolbox crashed when the VM had no audio device. The device build retains MIDI playback, but device audio performance needs further work.
- Full JVM save states are not available. 3D compatibility and complete MIDP form support need further testing.

## Credits and licenses

See [THIRD_PARTY.md](THIRD_PARTY.md), [LICENSE](LICENSE) and the `Licenses` directory. Original author notices are preserved in the sources. Public releases should include the matching source package, including the modified M3G sources.

The app icon was generated using a Java-inspired coffee motif and the i2ME name. It is not an official Java asset. This project is not affiliated with Oracle or Apple.

## Changes in 1.0.1

Simplified the native Canvas UI transition; the owner confirmed this build resolves the gray screen on iPhone 4 with iOS 7.1.2. Added startup/render diagnostics in `Documents/i2me.log`; the log is overwritten when the app starts.

## Changes in 1.0.2

Audio playback is disabled globally to avoid severe slowdown on iPhone 4. Java media calls use silent placeholder players; enabling sound in a game produces no output and creates no audio device or synthesizer. Full game compatibility still requires testing.
