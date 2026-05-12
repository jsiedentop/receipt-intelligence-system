## Receipt Intelligence System

**Wichtiger Hinweis vorab:**
Das Ziel dieser Aufgabe ist ein funktionsfähiger Prototyp – kein produktionsreifes System. OCR-basiertes Parsing ohne ML-Unterstützung ist von Natur aus fehleranfällig; Robustheit wird daher ausdrücklich nicht erwartet. Fehlertoleranz und eine saubere Architektur sind wichtiger als perfekte Erkennungsquoten.

Fragen zur Aufgabe sind ausdrücklich willkommen und werden positiv bewertet.

### Systemziel
Entwickle ein System zur Verarbeitung von Kassenbons – das Receipt Intelligence
System (RIS).
Input: Ein Kassenbon als Bilddatei (JPEG oder PNG) Output: Strukturierte, gespeicherte
und per UI abrufbare Belegdaten
Wie das System intern funktioniert – Architektur, Bibliotheken, Datenbank, OCR-Tool –
liegt vollständig im Ermessen des Bewerbers. Begründungen für getroffene
Entscheidungen sind willkommen und fließen positiv in die Bewertung ein.

### Stack
Pflicht: Node.js + TypeScript + wenn Flutter als Skill verfügbar ist kann auch Flutter für das Frontend gewählt werden.
Alle weiteren Entscheidungen (Framework, Datenbank, OCR-Bibliothek, Kategorisierungslogik, Containerisierung etc.) sind frei wählbar und sollen eigenständig begründet werden.

### Kernfunktionalität

Das System soll folgendes leisten:
1. Upload – Entgegennahme eines Kassenbon-Bildes (JPEG, PNG)
2. OCR – Extraktion von Rohtext aus dem Bild
3. Parsing – Strukturierte Extraktion aus dem Rohtext:
    - Händlername
    - Belegdatum
    - Gesamtbetrag & Währung
    - Einzelpositionen (mind. Name und Gesamtpreis je Position), Felder, die nicht erkannt werden, dürfen leer bleiben.
4. Kategorisierung – Einordnung der Positionen in Kategorien (z. B. LEBENSMITTEL, HAUSHALT, GASTRONOMIE, GESUNDHEIT, ELEKTRONIK, SONSTIGES) – Methode frei wählbar
5. Speicherung – Persistente Ablage der Daten
6. API – Abruf und Verwaltung der gespeicherten Belege
7. UI – Mindestens drei Ansichten:
    - Übersicht aller Belege
    - Upload-Maske
    - Detailansicht eines Belegs mit Positionen (inkl. manueller Kategorie-Korrektur). 
    
Das Repository soll zwei Beispiel-Kassenbons als Testbilder enthalten.

### Bewertungskriterien
| Bereich | Gewichtung |
|---------|-----------|
| Technische Umsetzung | 50 % |
| Architektur & Codequalität | 30 % |
| Dokumentation | 20 % |


**Technische Umsetzung**
- Pipeline läuft durch – auch bei schwachem OCR-Ergebnis
- Sinnvolle Fehlerbehandlung
- Eingabevalidierung
**Architektur & Code**
- Klare Schichttrennung
- Konfiguration über .env, keine hardcodierten Werte
- Nachvollziehbare Entscheidungen bei der Toolauswahl

**Dokumentation**
- README mit Setup in maximal 5 Befehlen
- Kurze Begründung der gewählten Technologien (3–5 Sätze)
- Was würde der Kandidat mit mehr Zeit verbessern? (3–5 Sätze)

### Optionale Extras (kein Bestandteil der Bewertung)
Nur sinnvoll, wenn alle Pflichtfeatures vollständig und sauber umgesetzt sind:
- Analytics / Diagramme
- Authentifizierung / JWT
- Export (CSV / Excel)
- KI-gestützte Kategorisierung
- Duplikaterkennung
- Geo-Verifikation des Händlers