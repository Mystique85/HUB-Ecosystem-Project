<!-- HEADER -->
<p align="center">

<img src="https://raw.githubusercontent.com/Mystique85/HUB-Ecosystem-Project/main/assets/token.icon.png" alt="HUB Logo" width="30" style="vertical-align: middle;"/>
<strong>HUB Ecosystem Project</strong> — autonomiczna gospodarka Web3 działająca na Base Mainnet ⚙️


<p align="center">
  <img src="https://readme-typing-svg.herokuapp.com?font=Courier+Prime&weight=700&size=24&pause=800&color=35D07F&center=true&vCenter=true&width=800&lines=HUB+Token+%7C+Autonomiczny+ekosystem+Web3+na+Base;Zdecentralizowana+sieć+zarządzana+przez+społeczność" alt="Typing SVG" />
</p>

---

<div align="center">
  <img src="https://raw.githubusercontent.com/Mystique85/HUB-Ecosystem-Project/main/assets/token.icon.png" alt="HUB Logo" width="100"/>
  <br/>
  <strong>Base Layer 2 Ethereum | Governance • Rewards • Autonomia</strong>
</div>

---

## 🧠 O projekcie

**HUB Ecosystem** to zdecentralizowana, autonomiczna gospodarka Web3 działająca na **Base Mainnet (Layer 2 Ethereum)**, zbudowana wokół jednego centralnego aktywa — **HUB Ecosystem (HUB)**.

Token HUB jest zaprojektowany tak, aby **sam zarządzał własną płynnością, generował przychody i wspierał rozwój ekosystemu** bez scentralizowanej kontroli.

---

## 🪙 HUB Ecosystem — fundament ekosystemu

**Symbol:** `HUB`  
**Sieć:** Base Mainnet  
**Standard:** ERC-20 (z rozszerzeniami: Pausable, AccessControl, ReentrancyGuard)  
**Całkowita podaż:** `10 000 000 000 HUB`  
**Decymale:** 18  
**Licencja:** MIT  
**Autor:** Mysticpol  
**Adres kontraktu:**  
[`0x58EFDe38eF2B12392BFB3dc4E503493C46636B3E`](https://basescan.org/address/0x58efde38ef2b12392bfb3dc4e503493c46636b3e)

---

## ⚙️ Architektura kontraktu

Kontrakt **HUBToken.sol** łączy cztery główne moduły OpenZeppelin:
- **ERC20** – standard tokena,
- **ERC20Pausable** – możliwość zatrzymania transferów,
- **AccessControl** – zarządzanie rolami (admin/operator),
- **ReentrancyGuard** – ochrona przed exploitami.

Dodatkowe funkcje:
- `MAX_SUPPLY` – twardy limit emisji, nigdy nie przekroczony,  
- `transferAndCall()` – integracja z innymi kontraktami ekosystemu (DAO, Vault, Staking).

---

## 🧩 Tokenomia (v1)

| Alokacja | Adres | Ilość | Cel |
|-----------|--------|-------|------|
| 🏦 **Reward Vault** | `REWARD_VAULT` | 8 000 000 000 HUB | Nagrody, staking, lojalność |
| 💧 **Liquidity Pool** | `LIQUIDITY_POOL` | 500 000 000 HUB | Płynność na DEX-ach |
| 🧠 **Team 1** | `DEPLOYER` | 750 000 000 HUB | Rezerwa techniczna |
| ⚙️ **Team 2** | `DEV2` | 750 000 000 HUB | Rozwój i utrzymanie projektu |

👉 Cała emisja wykonana w momencie wdrożenia.  
Brak dodatkowego mintowania poza `MAX_SUPPLY`.

---

## 🔁 Obieg HUB w ekosystemie

HUB to **nie tylko token** – to **rdzeń komunikacji i wartości** w całym systemie.

### Główne filary:
1. **Reward Mechanism (Vault.sol)** – staking i nagrody dla użytkowników.  
2. **Liquidity Manager (LiquidityManager.sol)** – automatyczne zasilanie DEX.  
3. **Treasury.sol** – zbieranie opłat, buyback i spalanie.  
4. **Governance.sol (DAO)** – głosowanie nad parametrami ekosystemu.  
5. **EcosystemRouter.sol** – warstwa integracyjna między kontraktami.

---

## 🧠 Użyteczność tokena HUB

| Funkcja | Opis | Znaczenie |
|----------|------|-----------|
| 💎 **Utility Token** | Służy do opłat, stakingu i dostępu do funkcji. | Ekonomia i popyt |
| 🗳️ **Governance Token** | Daje prawo głosu w DAO. | Decentralizacja |
| 🎁 **Reward Token** | Nagrody dla uczestników. | Motywacja |
| 💧 **Liquidity Asset** | Tworzy pary HUB/ETH, HUB/USDC. | Stabilność rynku |
| 🔄 **Ecosystem Bridge** | Łączy kontrakty i projekty HUB. | Skalowalność |

---

## 🔒 Bezpieczeństwo

- **Pausable:** operator może wstrzymać transfery.  
- **AccessControl:** ograniczenie uprawnień.  
- **ReentrancyGuard:** ochrona funkcji `transferAndCall()`.  
- **MAX_SUPPLY:** brak możliwości inflacji.

---

## 🌱 Jak HUB się rozwija

1. Projekty ekosystemu korzystają z HUB.  
2. Treasury skupuje HUB z rynku → deflacja.  
3. Stakerzy otrzymują nagrody → adopcja.  
4. DAO decyduje o zmianach → decentralizacja.

W efekcie HUB staje się **samowystarczalnym organizmem**, który wzmacnia się wraz z rozwojem ekosystemu.

---

## 🧭 Przyszła ekspansja (Tokenomics v2)

| Moduł | Opis | Status |
|--------|------|--------|
| **Vault.sol** | Zarządza stakingiem i nagrodami. | 🔄 W trakcie projektowania |
| **LiquidityManager.sol** | Automatyczne dodawanie płynności. | 🧩 W planach |
| **Treasury.sol** | Skup, spalanie, rezerwy. | 🧩 W planach |
| **Governance.sol** | DAO i głosowanie posiadaczy HUB. | 🧩 W planach |
| **EcosystemRouter.sol** | Integracja modułów ekosystemu. | 🧩 W planach |

---

## 🧾 Licencja

Projekt objęty licencją **MIT License**  
© 2025 Mysticpol — All rights reserved.

---

<p align="center">
  <img src="https://readme-typing-svg.herokuapp.com?font=Courier+Prime&weight=700&size=22&pause=800&color=35D07F&center=true&vCenter=true&width=700&lines=Built+with+💚+by+Mysticpol+for+the+Base+community" alt="Typing SVG" />
</p>
