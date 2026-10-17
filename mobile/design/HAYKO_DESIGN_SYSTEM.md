# HAYKO — Design System

**Versione:** 1.0  
**Data:** 14 ottobre 2026  
**Destinazione:** app Flutter iOS/Android per partite e statistiche di calcetto  
**Stato:** specifiche consolidate + proposte esplicitamente da validare

> **Regola fondamentale:** questo documento guida esclusivamente l'interfaccia visiva e l'esperienza d'uso. Non autorizza modifiche a logica di gioco, persistenza, autenticazione, permessi, calcolo delle statistiche o navigazione funzionale senza richiesta esplicita.

## 0. Legenda e gerarchia delle fonti

- **[APPROVATO]**: scelta confermata dall'utente in conversazione.
- **[FONTE CAMPO]**: specifica presente nella sola pagina 3, intitolata *Campo*, del documento `App Calcetto - Design_V.1.pdf`. È il riferimento visivo richiesto; non significa che ogni dettaglio sia stato approvato individualmente.
- **[DA VALIDARE]**: proposta operativa aggiunta per rendere implementabile il design. Non trattarla come decisione definitiva.
- **[DINAMICO]**: valore dipendente dai dati, dall'accessibilità o dalla configurazione utente, non fissabile dal brand.

**Ordine di precedenza:** (1) richieste esplicite più recenti dell'utente, (2) specifiche Figma approvate per la schermata interessata, (3) decisioni [APPROVATO] qui presenti, (4) valori [FONTE CAMPO], (5) proposte [DA VALIDARE]. In caso di conflitto chiedere conferma; non inventare nuove regole.

## 1. Identità e direzione creativa

- **Nome:** HAYKO. **[APPROVATO]** Sostituisce definitivamente HYOQO.
- **Simbolo principale:** falco stilizzato della direzione mostrata dall'utente. **[APPROVATO]**
- **Monogramma H:** proposta esplorativa secondaria; **non** usarlo come logo principale o icona app senza nuova approvazione. **[DA VALIDARE]**
- **Direzione:** sportiva, moderna, minimalista; dinamismo e precisione, senza affollare l'interfaccia. **[APPROVATO: direzione generale]**
- **Metafora visiva:** campo da calcetto, erba scura, linee di gesso e colori delle casacche. Atmosfera comunitaria, calda e informale. **[FONTE CAMPO]**
- **Riferimenti dichiarati:** essenzialità e riconoscibilità di Strava, Revolut e Zepp; non riprodurne loghi, layout o asset proprietari. **[APPROVATO: riferimenti]**
- **Claim:** nessun payoff ufficiale approvato. Non inserire automaticamente «Sport Tracking App» o altri slogan nel prodotto. **[DA VALIDARE]**

### 1.1 Asset e logo

Il logo del falco è stato mostrato come immagine di concept; **non esiste ancora in questo documento un master vettoriale definitivo approvato**. L'immagine generata per il confronto è un riferimento di stile, non un file sorgente vettoriale verificato. Prima di pubblicare, predisporre SVG master, versioni monocromatiche, positivo/negativo, icona app e verificare licenze/originalità del marchio. **[DA VALIDARE]**

Regole operative proposte **[DA VALIDARE]**:
- Non deformare, ruotare, aggiungere ombre, glow o contorni al simbolo.
- Preferire una versione a tinta unita nei contesti piccoli (toolbar, badge, notifiche).
- Mantenere area di rispetto almeno pari a 1/4 dell'altezza del simbolo; verificare sul vettoriale finale.
- Testare riconoscibilità a 24, 32, 48 e 1024 px.
- Usare `Image.asset` per raster e `flutter_svg` per SVG **solo se già presente nel progetto o dopo approvazione della dipendenza**.
- Non ricostruire il logo con caratteri Unicode, emoji o icone generiche.

## 2. Colori

### 2.1 Palette originale *Campo* **[FONTE CAMPO]**

| Token | HEX | Ruolo |
|---|---|---|
| `fieldBackground` | `#0E2B22` | Sfondo principale |
| `fieldSurface` | `#15392D` | Card, pannelli, barra inferiore |
| `fieldLine` | `#2A5646` | Linee, bordi e separatori |
| `chalk` | `#F2F5EE` | Testo principale e azione primaria |
| `mutedText` | `#A9C2B6` | Testo secondario |
| `action` | `#F2F5EE` | Pulsante principale |
| `teamOrange` | `#FF7A3D` | Identificazione squadra A nel mockup |
| `teamLime` | `#E3F24A` | Identificazione squadra B nel mockup |

La pagina Campo riporta anche contrasti indicativi rispetto allo sfondo: testo principale 13,7:1; secondario 8,0:1; azione 13,7:1; arancione 5,8:1; lime 12,3:1. Sono valori della fonte, **non** una certificazione automatica di ogni combinazione di colori nell'app.

**[DA VALIDARE]** `brandMint = #72CDA1` come accento eventuale del logo: proviene dalla proposta di branding successiva, **non** dalla palette originale Campo. Non sostituire automaticamente l'arancione o il lime con il mint.

### 2.2 Regole semantiche

- Sfondo app: `fieldBackground`; superfici elevate: `fieldSurface`; divisori: `fieldLine`. **[FONTE CAMPO]**
- Testo su verde scuro: `chalk` per principale, `mutedText` per secondario. **[FONTE CAMPO]**
- CTA primaria: fondo `chalk` e testo/iconografia scura `fieldBackground`; la pagina Campo mostra il pulsante «Gol» chiaro. **[FONTE CAMPO]**
- Colori arancione e lime: identificano due squadre **nell'esempio**; nelle partite reali il colore delle squadre deve provenire dalla configurazione/dati quando disponibili. **[DINAMICO]**
- Non affidarsi al solo colore per distinguere squadre, eventi o stati; accompagnare con testo/icone. **[DA VALIDARE]**
- Non riutilizzare automaticamente lime come «successo» o arancione come «errore»: servono token semantici dedicati. **[DA VALIDARE]**
- `success`, `warning`, `error`, `info`, `disabled`, overlay e relativi colori su superficie sono **ancora da definire**. **[DA VALIDARE]**
- Grafici: usare colori accessibili e distinguibili anche senza percezione cromatica; evitare di confondere il verde del fondo con un valore positivo. **[DA VALIDARE]**

### 2.3 Accessibilità cromatica **[DA VALIDARE]**

Verificare i contrasti effettivi per ogni coppia testo/sfondo, inclusi stati pressed/disabled, pill, chart e badge; obiettivo WCAG AA (almeno 4.5:1 per testo normale, 3:1 per testo grande e componenti UI quando applicabile). Non assumere che i valori indicati nel PDF garantiscano conformità per altre superfici.

## 3. Tipografia

- **Titoli e numeri:** Bricolage Grotesque ExtraBold. **[FONTE CAMPO]**
- **Interfaccia:** Bricolage Grotesque. **[FONTE CAMPO]**
- Il wordmark HAYKO è un asset grafico: non ricrearlo con il font UI. **[DA VALIDARE]**
- Distribuire i font nei formati supportati e con licenza verificata; se non ancora inclusi, segnalare il prerequisito. **[DA VALIDARE]**

### Scala proposta **[DA VALIDARE]**

| Stile | Size / line-height | Weight | Uso |
|---|---|---|---|
| `displayScore` | 48 / 56 | 800 | Risultato partita |
| `headlineLarge` | 30 / 36 | 800 | Titoli pagina |
| `headlineMedium` | 24 / 30 | 800 | Sezioni evidenti |
| `titleLarge` | 20 / 26 | 700 | Titolo card |
| `titleMedium` | 16 / 22 | 700 | Riga/elemento |
| `bodyLarge` | 16 / 24 | 400 | Testo principale |
| `bodyMedium` | 14 / 20 | 400 | Testo secondario |
| `labelMedium` | 12 / 16 | 600 | Badge, metadati |

Usare scaling del testo fornito dal sistema. Evitare altezze fisse che taglino il testo quando l'utente aumenta il font. **[DA VALIDARE]**

## 4. Spaziature, geometria e layout **[DA VALIDARE]**

Questi numeri **non sono presenti nella pagina Campo**: sono una base tecnica da verificare con Figma.

- Griglia spaziature: `4, 8, 12, 16, 20, 24, 32, 40, 48` dp.
- Padding pagina: 16 dp su telefoni; 24 dp su schermi ampi.
- Distanza tra card: 12 dp; tra sezioni: 24 dp.
- Raggi: `sm=8`, `md=12`, `lg=16`, `xl=20`, `pill=999` dp.
- Bordo: 1 dp `fieldLine` dove utile; non bordare ogni elemento per abitudine.
- Target interattivi: almeno 48 × 48 dp dove possibile.
- Layout mobile-first, SafeArea, rispetto di notch, tastiera e gesture bar.
- Evitare posizionamenti assoluti basati su un singolo modello iPhone.
- Considerare orientamento e tablet solo quando richiesti; non inventare schermate alternative.

## 5. Componenti UI

Le tipologie di componenti derivano dall'esempio Campo; dimensioni e comportamenti sotto sono proposte da validare con i mockup finali.

### 5.1 Pulsanti

**Primario:** pill/rounded, sfondo `chalk`, contenuto `fieldBackground`; esempio «Gol» nel PDF. **[FONTE CAMPO]** Altezza 52 dp, radius 12 dp, padding orizzontale 20 dp. **[DA VALIDARE]**

**Secondario:** trasparente o `fieldSurface`, bordo `fieldLine`, testo `chalk`. **[DA VALIDARE]**

**Distruttivo:** non usare il colore squadra come errore; stile da definire e confermare. **[DA VALIDARE]**

Gestire `default`, `pressed`, `focused`, `disabled`, `loading`, feedback semantico e label accessibile. **[DA VALIDARE]**

### 5.2 Card e righe

- Card: `fieldSurface` su `fieldBackground`. **[FONTE CAMPO]**
- Righe giocatori e registro gol: nome in evidenza, metadati in `mutedText`, indicatore squadra distinto. **[FONTE CAMPO]**
- Padding 12–16 dp e radius 12–16 dp. **[DA VALIDARE]**
- Evitare ombre forti; usare differenza di superficie e bordi leggeri. **[DA VALIDARE]**

### 5.3 Tabellone e campo

- La pagina Campo usa una rappresentazione geometrica del campo con linea centrale e cerchio centrale, punteggio in primo piano e squadra per lato. **[FONTE CAMPO]**
- Disegno campo: linee sottili a contrasto moderato; non competere con il punteggio. **[DA VALIDARE]**
- Punteggio grande e leggibile con Bricolage ExtraBold. **[FONTE CAMPO]**
- Stato «In corso» con testo e indicatore, non solo puntino colorato. **[DA VALIDARE]**
- Le informazioni e i controlli della partita devono riflettere permessi e dati reali; il design non introduce nuove capacità. **[APPROVATO: vincolo funzionale]**

### 5.4 Chips squadra, selettori e ranking

- Chip squadra con punto colorato e nome; esempio Chiari/Negri. **[FONTE CAMPO]**
- Selettore di appartenenza squadra A / Fuori / B; esempio nella pagina Campo. **[FONTE CAMPO]**
- Ranking con posizione, nome, presenze/vittorie e numero gol in evidenza. **[FONTE CAMPO]**
- Stato selezionato, focus, dimensioni e animazioni sono **[DA VALIDARE]**.

### 5.5 Navigazione

- L'esempio Campo mostra una barra inferiore con «Partite», «Giocatori», «Statistiche». **[FONTE CAMPO]**
- **Non** dedurre che queste siano tutte le sezioni definitive: mantenere l'architettura reale dell'app finché non viene richiesta una modifica. **[APPROVATO: vincolo funzionale]**
- Icone lineari coerenti, label visibili e stato attivo leggibile. **[DA VALIDARE]**

### 5.6 Moduli, dialog, feedback, empty states **[DA VALIDARE]**

Usare componenti del tema per campi, menu, bottom sheet, snackbars, loading, empty/error states. Definire per ciascuno contrasto, spaziature, focus, messaggi e azioni. Nessun componente deve cambiare dati o permessi per una semplice modifica grafica.

## 6. Linee guida per schermata

Questa sezione definisce **priorità visive**, non nuove feature. L'effettiva presenza delle sezioni dipende dal codice e dalle specifiche funzionali.

| Schermata | Priorità UI | Stato |
|---|---|---|
| Home/dashboard | accesso immediato a partita e attività pertinenti | **[DA VALIDARE]** |
| Partita | punteggio, squadre, stato, CTA gol, registro eventi | **[FONTE CAMPO]** per l'esempio |
| Giocatori | identità, prestazioni, statistiche sintetiche | **[DA VALIDARE]** |
| Statistiche | gerarchia dei numeri, grafici leggibili, filtri espliciti | **[DA VALIDARE]** |
| Leghe/eventi | distinguere competizioni, incontri e ruoli | **[DA VALIDARE]** |
| Profilo | dati personali e risultati senza sovraccarico | **[DA VALIDARE]** |

**Partita:** durante l'uso sul campo, favorire una CTA chiara, leggibilità a distanza di braccio e flussi rapidi. Non introdurre o cambiare azioni di registrazione gol, undo, timer o gestione ruoli senza una richiesta funzionale specifica. **[DA VALIDARE: principio UX]**

## 7. Iconografia, illustrazioni e motion **[DA VALIDARE]**

- Icone semplici, coerenti per spessore, dimensione e allineamento.
- Non usare il falco come decorazione ripetuta in ogni card: riservarlo a branding, onboarding e momenti selezionati.
- Motivi di campo (linee, cerchio, metà campo) solo se non riducono leggibilità.
- Animazioni brevi e funzionali (circa 150–250 ms), rispettando le preferenze di riduzione movimento; valori da confermare.
- Evitare gradienti, glow, glassmorphism e ombre elaborate salvo approvazione per una schermata specifica.

## 8. Implementazione Flutter

### 8.1 Organizzazione suggerita **[DA VALIDARE]**

```text
lib/
  design_system/
    hayko_colors.dart
    hayko_spacing.dart
    hayko_radii.dart
    hayko_typography.dart
    hayko_theme.dart
    components/
      hayko_button.dart
      hayko_card.dart
      hayko_team_chip.dart
      hayko_scoreboard.dart
assets/
  branding/
    hayko_falcon.svg  # placeholder: asset definitivo da approvare
  fonts/
    ...                # solo font con licenza e file verificati
```

Adattare alla struttura **esistente**: non duplicare ThemeData, non rinominare cartelle o sostituire widget funzionanti solo per uniformarsi a questo esempio.

### 8.2 Token Flutter — palette *Campo* **[FONTE CAMPO]**

```dart
import 'package:flutter/material.dart';

abstract final class HaykoColors {
  static const fieldBackground = Color(0xFF0E2B22);
  static const fieldSurface = Color(0xFF15392D);
  static const fieldLine = Color(0xFF2A5646);
  static const chalk = Color(0xFFF2F5EE);
  static const mutedText = Color(0xFFA9C2B6);
  static const action = Color(0xFFF2F5EE);
  static const teamOrange = Color(0xFFFF7A3D);
  static const teamLime = Color(0xFFE3F24A);
}
```

**[DA VALIDARE]** Esempio di tema iniziale, da integrare nel tema esistente (non sostituirlo alla cieca):

```dart
ThemeData buildHaykoTheme() {
  const bg = HaykoColors.fieldBackground;
  const fg = HaykoColors.chalk;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      surface: HaykoColors.fieldSurface,
      primary: HaykoColors.action,
      onPrimary: bg,
      onSurface: fg,
      outline: HaykoColors.fieldLine,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontFamily: 'BricolageGrotesque', fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'BricolageGrotesque', fontSize: 14),
    ).apply(bodyColor: fg, displayColor: fg),
  );
}
```

Nota: la registrazione del font in `pubspec.yaml`, i pesi disponibili e la compatibilità con la versione Flutter del progetto vanno verificati. Non assumere che il font sia già installato.

### 8.3 Dati dinamici e stati

- I colori di squadra in una partita reale **non** devono essere sempre arancione/lime: quei colori sono quelli del mockup. Mappare i colori configurati, prevedendo fallback accessibili. **[DINAMICO]**
- Punteggio, eventi, classifiche, nomi e permessi provengono dallo stato applicativo: mai hardcodarli in widget di produzione.
- Non aggiungere servizi esterni o dipendenze per ottenere un effetto grafico senza autorizzazione.
- Localizzazione italiana, lunghezza dei nomi, overflow, text scaling e schermi piccoli devono essere verificati. **[DA VALIDARE]**

## 9. Flusso Figma → Flutter

1. In Figma preparare frame approvati, componenti, varianti e token; associare ogni schermata a un nome/versione.
2. Fornire a ChatGPT screenshot e, quando disponibili, misure/esportazioni o collegamenti consultabili. Uno screenshot **non** garantisce misure esatte.
3. Confrontare Figma con i widget esistenti; identificare cosa è solo stile e cosa cambierebbe il comportamento.
4. Riutilizzare token e componenti condivisi; evitare colori e padding numerici duplicati.
5. Verificare la schermata su simulatore e dispositivo reale; controllare differenze, safe area, font, overflow e accessibilità.
6. Registrare nuove decisioni approvate in questo documento con data e versione.

## 10. Istruzioni operative per ChatGPT / agente di sviluppo

> **Incarico:** implementa la modifica UI richiesta secondo `HAYKO_DESIGN_SYSTEM.md` e il frame Figma approvato. Prima di scrivere codice, ispeziona i file effettivi e individua tema, componenti, route e stato interessati. Mantieni invariati logica, database, API, autorizzazioni, navigazione e comportamento delle azioni salvo richiesta esplicita. Non considerare definitive le specifiche marcate [DA VALIDARE]. Se un dettaglio è essenziale e mancante, chiedi conferma; per dettagli minori, dichiara l'assunzione proposta. Non usare il logo H come simbolo principale: il falco è la scelta approvata. Non inventare asset o dipendenze. Alla fine indica file modificati, differenze rispetto a Figma, verifiche eseguite e punti ancora da validare.

### Checklist prima di consegnare

- [ ] Stili presi dai token centralizzati, senza nuovi HEX arbitrari.
- [ ] Falco usato come brand principale; asset autentico e approvato, se disponibile.
- [ ] Font Bricolage verificato o mancanza segnalata.
- [ ] Nessuna modifica funzionale non richiesta.
- [ ] Colori squadra trattati come dati dinamici quando necessario.
- [ ] Testo leggibile, contrasto verificato e scaling rispettato.
- [ ] SafeArea, overflow, tastiera e schermi piccoli controllati.
- [ ] Test di build/lint e smoke test effettuati oppure esplicitamente non eseguiti.
- [ ] Differenze dal frame Figma e decisioni [DA VALIDARE] documentate.

## 11. Registro decisioni e questioni aperte

### Confermato

1. **14/10/2026 — [APPROVATO]** Nome app HAYKO.
2. **14/10/2026 — [APPROVATO]** Falco come logo principale.
3. **14/10/2026 — [APPROVATO]** Palette e direzione della pagina 3 *Campo* come base del Design System.
4. **14/10/2026 — [FONTE CAMPO]** Bricolage Grotesque per titoli, numeri e UI.

### Da validare prima di consolidare v1.1

- Asset vettoriale master del falco, geometria, dimensioni minime e iconografia app.
- Palette mint opzionale e versione monocromatica del marchio.
- Scala tipografica, pesi realmente disponibili e licenza font.
- Spaziature, raggi, misure di pulsanti e card.
- Colori semantici success/error/warning e regole grafici.
- Stati dei componenti, icone, motion e light mode eventuale.
- Frame Figma finali per ciascuna schermata e architettura di navigazione reale.

## 12. Materiali di riferimento

1. `App Calcetto - Design_V.1.pdf`, **solo pagina 3: Campo** — palette, tipografia, mockup partita e componenti.
2. Immagine fornita dall'utente con due proposte HAYKO (falco e monogramma H) — riferimento concept, **falco selezionato**.
3. Tavola di confronto dei due loghi generata nella conversazione — esplorazione grafica, non master approvato.

**Nota:** questo file non contiene né sostituisce asset vettoriali, file Figma o specifiche funzionali. Ogni proposta nuova diventa [APPROVATO] solo dopo conferma esplicita.
