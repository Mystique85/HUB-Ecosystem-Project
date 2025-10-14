# 🧱 HUBRewardVault — Propozycja Robocza (PL)

**Autor:** Mysticpol  
**Projekt:** HUB Ecosystem  
**Status:** RFC (Request for Comments)  
**Cel:** Określenie logiki, przepływu i zabezpieczeń kontraktu `RewardVault`.

---

## 1️⃣ Cel kontraktu

`RewardVault` przechowuje pulę tokenów HUB i rozdziela je jako nagrody dla użytkowników ekosystemu HUB w sposób:
- **bezpieczny** (kontrolowany przez kontrakt multisig / admina),
- **ograniczony** (aby nie wyczerpać podaży HUB zbyt szybko),
- **dynamiczny** (ilość nagród zależna od ceny HUB lub aktywności sieci),
- **samowystarczalny** (zasilany automatycznie przez inny kontrakt z opłat ETH).

---

## 2️⃣ Parametry bazowe

| Parametr         | Wartość                | Opis |
|------------------|------------------------|------|
| `epochDuration`  | 365 dni                | Długość jednej epoki (cykl roczny) |
| `epochBudget`    | 1 000 000 000 HUB      | Ilość tokenów uwalnianych na epokę |
| `maxEpochs`      | 8                      | Łączna liczba epok (8 lat = 8 mld HUB) |
| `startTime`      | `block.timestamp`      | Początek pierwszej epoki (moment wdrożenia) |
| `receiver`       | `RewardDistributor`    | Kontrakt zarządzający dystrybucją nagród |
| `buybackTopUp`   | opcjonalny             | Dodatkowe doładowanie przy spadku ceny HUB |

---

## 3️⃣ Przebieg działania

1. **Sprawdzenie epoki** – kontrakt weryfikuje, czy minął pełny rok od poprzedniego uwolnienia.  
2. **Dystrybucja** – wysyła `epochBudget` tokenów HUB na adres `RewardDistributor`.  
3. **Kontrola administracyjna** – tylko `ADMIN_CONTRACT` (Gnosis Safe) może potwierdzić kluczowe operacje.  
4. **Doładowanie puli** – osobny kontrakt (`LiquidityEngine`) zamienia ETH z opłat na HUB i automatycznie uzupełnia pulę Vault.

---

## 4️⃣ Architektura systemu

- **RewardVault** — przechowuje i uwalnia tokeny HUB.  
- **RewardDistributor** — decyduje, komu i ile przyznać nagród.  
- **LiquidityEngine** — zarządza ETH z opłat, dokupuje HUB i utrzymuje płynność.  
- **ADMIN_CONTRACT** — multisig (Gnosis Safe), kontroluje i zatwierdza zmiany.

---

### 4.1 🔁 Przepływ nagród w ekosystemie HUB

```text
Użytkownik --> DApp --> ActivityRouter.rejestrujAkcję(...)
                                             |
                                             v
                          RewardDistributor.zgłośŻądanieNagrody(...)
                                             |
                                             v
                      ActivityRouter pobiera niewielką opłatę (ETH)
                                             |
                                             v
                            LiquidityEngine.przyjmijETH(...)
                                             |
                         (okresowo) LiquidityEngine.wykonajBuyback()
                                             |
                                             v
                      LiquidityEngine.przekazuje tokeny HUB do RewardVault
                                             |
                                             v
                         RewardVault.zarejestrujDoładowanie(kwota)
                                             |
                        (co epokę) RewardVault.uwolnijBudżetEpoki() -> RewardDistributor
                                             |
                                             v
                      RewardDistributor.rozdzielNagrodyDlaUżytkowników(...)
```

### Opis przepływu:

1. **Użytkownik** wykonuje akcję w aplikacji DApp (np. głosowanie, ankieta, kliknięcie „gm”).  
2. **ActivityRouter** rejestruje akcję i przekazuje żądanie nagrody do `RewardDistributor`.  
3. Jednocześnie pobierana jest **symboliczna opłata w ETH** od użytkownika.  
4. **LiquidityEngine** odbiera te środki, gromadzi je i okresowo wykonuje **buyback HUB** z DEX-a.  
5. Nabyte tokeny HUB przekazuje do **RewardVault**, który rejestruje ich przyrost.  
6. Po zakończeniu każdej epoki (np. po 365 dniach), **RewardVault** przekazuje ustalony budżet HUB do `RewardDistributor`.  
7. **RewardDistributor** rozdziela nagrody w HUB użytkownikom proporcjonalnie do ich aktywności w ekosystemie HUB.

---


## 5️⃣ Zasada samowystarczalności

Po wykorzystaniu początkowych 8 mld HUB:
- nie powstają nowe tokeny,
- `LiquidityEngine` kupuje HUB z DEX-ów za ETH z opłat,
- zakupione tokeny trafiają z powrotem do `RewardVault`,
- tworząc **autonomiczny i trwały system nagród**.

---

## 6️⃣ Zasady bezpieczeństwa

- Wszystkie operacje krytyczne wymagają zatwierdzenia przez multisig.  
- Nie ma możliwości emisji nowych tokenów — kontrakt zarządza tylko przekazanymi HUB.  
- Długoterminowe zmiany logiki będą realizowane przez nową wersję (`RewardVaultV2`), wdrażaną przez multisig.

---

## 7️⃣ Punkty do dyskusji (dla społeczności)

1. Czy stały roczny budżet (1 mld HUB) jest optymalny, czy powinien być dynamiczny?  
2. Czy warto zastosować automatyczne dostosowanie w oparciu o cenę HUB (oracle)?  
3. Czy doładowania (`buybackTopUp`) mają być ręczne czy wykonywane automatycznie przez keepera?  
4. Jak najlepiej zbalansować nagrody dla użytkowników w skali całego ekosystemu?

---

## 8️⃣ Licencja i wersjonowanie

- **Licencja:** MIT  
- **Autor:** Mysticpol  
- **Wersja:** Draft 0.1  
- **Repozytorium:** [HUB-Ecosystem-Project](https://github.com/Mystique85/HUB-Ecosystem-Project)

---

> 💡 **Uwaga:** To dokument koncepcyjny — wszystkie uwagi i propozycje zmian można zgłaszać jako `Pull Request` lub w sekcji "Issues" repozytorium.
