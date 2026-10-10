# i2ME 1.0

Emulator gier Java ME dla starszych urządzeń iOS. Made by Griszek (with help of ChatGPT 6.1).

Port projektu [JarBox](https://github.com/ccbkv/J2MEEmulator-iOS), korzystający z miniJVM. To wczesna wersja: zgodność zależy od gry.

## Urządzenia i instalacja

- Wersja urządzeniowa: ARMv7, minimum iOS 5.0, SDK 6.1. Główny cel: iPhone 4 z iOS 6.
- IPA jest **niepodpisane**. Wymaga własnego podpisania i odpowiedniego profilu Apple albo urządzenia z jailbreakiem i obsługą instalowania niepodpisanych aplikacji. Sam jailbreak nie zawsze wystarcza.
- Nie testowano jeszcze na fizycznym iPhonie. ARMv6 / iOS 3 nie są obsługiwane.
- Testy wykonano w symulatorze iOS 6.1. Pakiet nie zawiera gier komercyjnych ani danych użytkownika.

## Używanie

1. Dodaj własny plik JAR do katalogu Documents aplikacji przez udostępnianie plików iTunes albo otwórz go w i2ME.
2. Odśwież bibliotekę. Przy pierwszym uruchomieniu ustaw rozdzielczość i limit FPS.
3. Przesuń wiersz gry w prawo, aby odsłonić niebieską opcję Edytuj, lub w lewo, aby odsłonić czerwone Usuń.
4. W edycji możesz zmienić nazwę, ikonę, rozdzielczość i FPS.
5. Ustawienia w lewym górnym rogu zawierają wybór 11 języków i informacje o aplikacji. Część opisów pomocniczych używa angielskiego tłumaczenia zastępczego.

## Zapisy

Kopie zapisów obejmują **dane RMS**, czyli trwałe zapisy gry. Nie są pełnym save state pamięci JVM i nie zapisują bieżącej klatki ani stosów wątków.

Przycisk zapisów podczas gry zatrzymuje MIDlet i otwiera listę kopii. Samo otwarcie listy nie tworzy kopii. Przycisk **+** tworzy ją jawnie; wybór istniejącej kopii pozwala ją przywrócić, a przesunięcie wiersza pozwala ją usunąć. Gra może samodzielnie zapisywać swoje RMS przy zamykaniu.

## Kompilacja

Sprawdzona konfiguracja: OS X 10.8.5, Xcode 4.6, SDK iOS 6.1. Skrypt zakłada instalację Xcode w `/Applications/Xcode.app`.

```sh
bash build.sh iphoneos armv7
bash build.sh iphonesimulator i386
```

Wynik: `build/armv7/LegacyJ2ME.app` albo `build/i386/LegacyJ2ME.app`. Plik wykonywalny i identyfikator pakietu zachowują wewnętrzne nazwy portu; wyświetlana nazwa to i2ME.

Do przygotowania IPA umieść wersję ARMv7 w katalogu `Payload`, zachowując rozszerzenie `.app`, i spakuj katalog Payload jako ZIP z rozszerzeniem `.ipa`. Podpisywanie jest osobnym krokiem.

Skrypt korzysta z dołączonych plików runtime JAR. Źródła warstwy Java ME znajdują się w `JavaAPI/src`; po ich zmianie trzeba osobno przebudować `Resources/j2me_api.jar`, używając JDK z obsługą `javac --release 8`. Po zmianach nagłówków C usuń własny katalog `build`, aby uniknąć ponownego użycia starszych obiektów.

## Sprawdzone i ograniczenia

- Kompilacja ARMv7 i i386; nagłówek Mach-O deklaruje minimum iOS 5.0 i SDK 6.1.
- Demo: renderowanie 2D, obsługa klawiszy i RMS w symulatorze.
- Prywatny test Plants vs Zombies: gra przeszła uruchomienie po obejściu awarii AudioToolbox. Całej rozgrywki nie zweryfikowano.
- W symulatorze MIDI jest wyciszone: stary AudioToolbox crashował przy braku urządzenia audio w VM. Wersja urządzeniowa zachowuje odtwarzanie MIDI, ale dźwięku na telefonie jeszcze nie sprawdzono.
- Brak pełnych save states JVM. Zgodność 3D i wszystkich formularzy MIDP wymaga dalszych testów.

## Licencje i pochodzenie

Zobacz [THIRD_PARTY.md](THIRD_PARTY.md), [LICENSE](LICENSE) i katalog `Licenses`. Zachowane są informacje o autorach w źródłach. Do publicznych wydań dołączaj również paczkę źródeł odpowiadającą wydaniu, w tym zmodyfikowane źródła M3G.

Grafika aplikacji została wygenerowana z motywem filiżanki kojarzonym z Javą i napisem i2ME. Nie jest oficjalnym zasobem Java ani oznaczeniem współpracy z Oracle lub Apple.
