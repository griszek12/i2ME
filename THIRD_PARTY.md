# Third-party notices

i2ME contains a legacy iOS port of JarBox, upstream revision `8afc8d808ca22160139333d1d58138c7dca91169`:
https://github.com/ccbkv/J2MEEmulator-iOS

The upstream Apache-2.0 license is retained in LICENSE and Licenses/Apache-2.0.txt.
Port contributions by Griszek with assistance from ChatGPT: UIKit library/settings UI, RMS backup management, old SDK compatibility, legacy MIDI backend, build script and demo.

Components retain their individual licenses; the root license does not replace them:

- miniJVM native engine: Gust / digitalgust, MIT. See Licenses/miniJVM-LICENSE.txt and https://github.com/digitalgust/miniJVM . The upstream license separately identifies Java runtime sources as GPL-2.0 and describes the prebuilt runtime JAR distribution. This package retains the prebuilt runtime provided by JarBox.
- Java ME implementation: derived through JarBox from J2ME-Loader; https://github.com/niclet/J2ME-Loader . The corresponding Java API sources are in JavaAPI/src.
- M3G: Nokia Corporation and contributors, Eclipse Public License 1.0. See NativeBridge/m3g and Licenses/EPL-1.0.html. Port changes rename Rect to M3GLegacyRect to avoid an Apple SDK type conflict and adapt atomics for the old compiler. Modified sources are included in the source package under the same EPL terms.
- mbed TLS: ARM Limited and contributors, Apache-2.0; original notices retained in minijvm/utils/https/mbedtls.
- tinycthread: Marcus Geelnard and Evan Nemerson, zlib-style license; full notice retained in minijvm/utils/tinycthread.c and .h. Atomic compatibility changes elsewhere are identified as port changes.
- GeneralUser GS 1.471: S. Christian Collins. See Licenses/GeneralUser-GS-LICENSE.txt, extracted from the included SoundFont's embedded license comment; https://schristiancollins.com/generaluser.php .
- Other bundled source files retain their original copyright and license notices.

No commercial game JARs are included. i2ME is not affiliated with Oracle, Apple, Electronic Arts or the upstream developers.
