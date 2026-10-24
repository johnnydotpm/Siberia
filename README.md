# SiberiaGB

**Polski** | [English](README.en.md) | [Русский](README.ru.md)

SiberiaGB to w pełni funkcjonalny, wieloplatformowy klient Librus napisany w frameworku [Flutter](https://flutter.dev/).

## Funkcje

- Logowanie z niewygasającymi sesjami
- Kilka profili w jednej aplikacji: rodzic z dwójką dzieci albo uczeń w dwóch szkołach. Każdy profil ma własne dane, oceny, zadania i ustawienia średniej, a przełącza się jednym dotknięciem
- Plan lekcji jako oś czasu lub lista, z łączonymi lekcjami podwójnymi i sprawdzianami przy lekcjach, na które są zapowiedziane
- Oceny w kolorach według wartości i obliczanie średniej, także ważonej, z własną wartością plusów i minusów
- Kalkulator ocen: jak zmieni się średnia po nowych ocenach i ile ocen potrzeba do wybranej średniej
- Terminarz, kalendarz oraz nadchodzące wydarzenia
- Lista zadań domowych pogrupowana według terminu, z wyszukiwaniem
- Ekran „Dzisiaj” z bieżącą i następną lekcją oraz blokami, które można ukrywać i przestawiać
- Widżet „Następna lekcja” na ekranie głównym (Android i iOS), z osobnymi ustawieniami dla każdego widżetu na Androidzie, także z wyborem profilu
- Pełna obsługa wiadomości
- Ogłoszenia
- Frekwencja z wykresem obecności
- Uwagi
- Powiadomienia o nowościach w ośmiu kategoriach: oceny, wiadomości, ogłoszenia, uwagi, frekwencja, wydarzenia, zadania domowe i plan lekcji; przy kilku profilach z imieniem profilu i osobnym włącznikiem dla każdego
- Przypomnienia o sprawdzianach wieczorem dzień wcześniej lub rano tego dnia, o wybranej godzinie (Android i iOS)
- Synchronizacja danych w tle (Android)
- Wsparcie dla pięciu języków: polskiego, angielskiego, rosyjskiego, niemieckiego i ukraińskiego
- Działa na Androidzie, iOS, Windows i Linuksie
- Wygląd Liquid Glass: na iOS 26 i nowszych rysowany prawdziwymi paskami systemowymi, na Androidzie 10 i nowszych odtworzony przez samą aplikację w tych samych wymiarach; klasyczny wygląd pozostaje dostępny w ustawieniach

## Struktura projektu

Kod aplikacji znajduje się w katalogu [`syberia/`](syberia).

## Instalacja

Pobierz plik odpowiedni dla swojej platformy, a następnie uruchom go lub zainstaluj aplikację.

Na Androidzie plik `SiberiaGB-<wersja>-Android-arm64.apk` jest mniejszy i pasuje do niemal każdego telefonu z ostatnich lat. Jeśli się nie instaluje, pobierz `SiberiaGB-<wersja>-Android.apk`, który działa na każdym telefonie z Androidem, także na starszych 32-bitowych. Każdy z tych plików aktualizuje aplikację zainstalowaną z drugiego.

Na iOS aplikację należy zainstalować we własnym zakresie za pomocą [AltStore](https://altstore.io/), [SideStore](https://sidestore.io/), [LiveContainer](https://github.com/LiveContainer/LiveContainer) lub płatnego certyfikatu.

Widżet „Następna lekcja” na ekranie głównym działa przy instalacji przez AltStore, SideStore lub płatny certyfikat; LiveContainer nie obsługuje widżetów. Na darmowym Apple ID widżet zajmuje jeden dodatkowy App ID.

Aby testować interfejs bez konta szkolnego, przytrzymaj logo na ekranie logowania przez pięć sekund. Tryb demonstracyjny zawiera fikcyjne oceny, wiadomości, uwagi, frekwencję, lekcje i wpisy w kalendarzu. Wiadomości i odświeżanie działają lokalnie; wyloguj się, aby zakończyć demo. Dane demonstracyjne nie są zapisywane między uruchomieniami aplikacji.

## Instrukcje budowania

Każdy lokalny build wymaga [Flutter SDK](https://docs.flutter.dev/get-started/install). W katalogu głównym projektu wykonaj najpierw:

```sh
cd syberia
flutter pub get
```

<details>
<summary>Android</summary>

Wymaga Android SDK i skonfigurowanego środowiska Flutter.

```sh
flutter build apk --release
```

Gotowy plik APK znajdziesz w `build/app/outputs/flutter-apk/app-release.apk`.

Bez lokalnego Android SDK: w GitHub Actions uruchom workflow `SiberiaGB Flutter` z opcją `build_android`, a następnie pobierz artefakt `siberiagb-android`.

Build z własnego komputera jest podpisany kluczem debugowym, więc nie zainstaluje się jako aktualizacja opublikowanego wydania. W GitHub Actions APK jest podpisywany kluczem projektu z sekretów repozytorium `ANDROID_KEYSTORE_BASE64` i `ANDROID_KEYSTORE_PASSWORD`; bez nich również kluczem debugowym. Build z kluczem debugowym instaluje się jako osobna aplikacja SiberiaGB Preview obok opublikowanej, a wydania bez klucza nie da się zrobić.

</details>

<details>
<summary>iOS</summary>

Lokalna kompilacja wymaga macOS, Xcode oraz Apple Developer Team skonfigurowanego w projekcie Xcode.

```sh
flutter build ipa --release
```

GitHub Actions nie wymaga Maka: uruchom workflow `SiberiaGB Flutter` z opcją `build_ios`, a następnie pobierz artefakt `siberiagb-ios`. IPA należy podpisać i zainstalować samodzielnie, na przykład przez AltStore lub SideStore.

</details>

<details>
<summary>Windows</summary>

Wymaga systemu Windows oraz Visual Studio z komponentem **Desktop development with C++**.

```powershell
flutter build windows --release
```

Aplikacja znajdzie się w `build/windows/x64/runner/Release`.

</details>

<details>
<summary>Linux</summary>

Wymaga systemu Linux z wymaganymi zależnościami desktopowymi Fluttera.

```sh
flutter build linux --release
```

Gotowa aplikacja znajduje się w `build/linux/x64/release/bundle`.

</details>

## TODO

- Synchronizacja w tle na iOS (obecnie zadanie okresowe rejestruje się tylko na Androidzie)
- Przeniesienie komunikatów o błędach Librusa do warstwy tłumaczeń (teraz są zapisane po polsku na stałe w kodzie klienta)
- Rozszerzenie testów jednostkowych i integracyjnych na urządzeniach
- Dalsze usprawnienia dostępności interfejsu
- Podział `lib/src/ui/app_shell.dart` na osobne pliki ekranów
- Dodatkowe style aplikacji, w tym frutiger aero, minimal, skeuomorphism
- Więcej języków

## Licencja i podziękowania

Kod jest dostępny na warunkach opisanych w pliku [`LICENSE`](LICENSE). SiberiaGB jest **nieoficjalnym** klientem i **nie jest powiązana z Librus sp. z o.o.**

Niektóre elementy aplikacji inspirowane są projektem [Szkolny.eu](https://szkolny.eu/).
