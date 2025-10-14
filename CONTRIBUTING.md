# 🤝 Contributing to HUB Ecosystem Project

Dziękujemy za zainteresowanie rozwojem **HUB Ecosystem Project**!  
Każdy wkład — niezależnie od skali — pomaga ulepszać projekt i budować otwarte środowisko web3.  
Poniżej znajdziesz krótkie wytyczne, jak skutecznie kontrybuować.

---

## 🧩 Zasady ogólne

- Repozytorium jest publiczne — wszystkie PR-y są widoczne i weryfikowane ręcznie.  
- Zachowaj przejrzystość i opisuj każdą zmianę w commitach.  
- Nie commituj plików build (`out/`, `artifacts/`, `cache/`, `node_modules/`).  
- Nie przesyłaj plików z danymi prywatnymi (`.env`, klucze, konfiguracje lokalne).  
- Pliki źródłowe kontraktów powinny znajdować się w katalogu `src/` lub `contracts/`.

---

## 🌿 Struktura repozytorium




---

## 🔀 Zasady commitów i pull requestów

### Commity
- Używaj krótkich, opisowych komunikatów:
  - ✅ `add HUBRewardVault.sol`
  - ✅ `update docs for RewardVault`
  - ❌ `fix` lub `update stuff`

### Pull Requesty
- Każdy PR powinien:
  1. Dotyczyć **jednego konkretnego celu** (np. aktualizacja dokumentacji lub nowy kontrakt).
  2. Mieć **opis zmian** (co, dlaczego, jak).
  3. Być zrebasowany na aktualnym `main`.

---

## 🧠 Styl i konwencje

- Nazwy kontraktów: `PascalCase` (np. `HUBRewardVault`).
- Nazwy zmiennych: `camelCase`.
- Funkcje publiczne i external powinny mieć jasny, opisowy komentarz w formacie `///`.
- Zmienne prywatne oznaczaj `_` na początku (`_owner`, `_totalSupply`).
- Dokumentacja: pliki `.md` w `docs/` — w wersji EN i PL, jeśli to możliwe.

---

## 🛡️ Zasady bezpieczeństwa

- Nie publikuj żadnych kluczy, seedów ani prywatnych danych.
- Testuj zmiany lokalnie zanim wyślesz PR.
- Jeśli zauważysz potencjalny błąd bezpieczeństwa — **nie publikuj go publicznie**.  
  Skontaktuj się bezpośrednio z maintainerem projektu.

---

## 🧾 Licencja

Projekt jest open-source i dostępny na licencji **MIT**.  
Wysyłając kontrybucję, zgadzasz się na jej publikację w ramach tej samej licencji.

---

### 💬 Dzięki!

Jeśli masz pomysł, jak ulepszyć dokumentację, kod lub proces — śmiało otwórz issue lub PR.  
Każdy feedback jest cenny 💙
