-- ============================================================
-- TOMBOLA AS A SERVICE (TaaS) - DDL per SQLite
-- ============================================================
-- Struttura della cartella tombola:
--   3 righe x 9 colonne, con 5 numeri per riga (15 numeri totali)
--   Colonna 1: numeri 1-9
--   Colonna 2: numeri 10-19, ..., Colonna 9: numeri 80-90
-- Vincite in ordine: Ambo (2 sulla stessa riga), Terno (3),
--   Quaterna (4), Cinquina (5 = riga completa), Tombola (15)
-- Un utente che ha vinto un premio non può concorrere al successivo
-- ============================================================

PRAGMA foreign_keys = ON;

-- ------------------------------------------------------------
-- UTENTI
-- ------------------------------------------------------------
CREATE TABLE utenti (
    utenteId    INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT    NOT NULL,
    cognome     TEXT    NOT NULL,
    email       TEXT    NOT NULL UNIQUE,
    authMethod  TEXT    NOT NULL DEFAULT 'password',
        -- valori: 'password' | 'otp' | 'oauth' | 'magic_link'
    authData    TEXT,
        -- hash della password, token oauth, ecc. (dipende da authMethod)
    tipo        INTEGER NOT NULL DEFAULT 1 CHECK (tipo BETWEEN 0 AND 2),
        -- 0 = Admin | 1 = User | 2 = Guest
    attivo      INTEGER NOT NULL DEFAULT 1,  -- 0 = disabilitato
    createdAt   TEXT    NOT NULL DEFAULT (datetime('now')),
    updatedAt   TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_utenti_email ON utenti(email);

-- ------------------------------------------------------------
-- TOMBOLATE (sessioni di gioco)
-- ------------------------------------------------------------
CREATE TABLE tombolate (
    tombolataId                     INTEGER PRIMARY KEY AUTOINCREMENT,
    nome                            TEXT    NOT NULL,
    gestoreId                       INTEGER NOT NULL REFERENCES utenti(utenteId),
        -- FK all'utente che crea e gestisce la tombolata (deve avere tipo = 0, Admin)
    authMethodUtenti                TEXT    NOT NULL DEFAULT 'password',
        -- valori: 'password' | 'otp' | 'oauth' | 'magic_link' | 'none'
    dataAttivazione                 TEXT,
        -- data/ora di inizio del gioco (estrazione numeri)
    dataFineAssegnazioneCartelle    TEXT,
        -- deadline entro cui assegnare le cartelle
    stato                           TEXT    NOT NULL DEFAULT 'creata',
        -- 'creata' | 'aperta' | 'attiva' | 'terminata'
        -- creata   = configurazione in corso
        -- aperta   = assegnazione cartelle aperta
        -- attiva   = estrazione numeri in corso
        -- terminata = gioco concluso
    createdAt                       TEXT    NOT NULL DEFAULT (datetime('now')),
    updatedAt                       TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_tombolate_gestore ON tombolate(gestoreId);

-- ------------------------------------------------------------
-- TOMBOLATE_UTENTI  (partecipanti registrati a una tombolata)
-- ------------------------------------------------------------
CREATE TABLE tombolate_utenti (
    tombolataUtenteId INTEGER PRIMARY KEY AUTOINCREMENT,
    tombolataId       INTEGER NOT NULL REFERENCES tombolate(tombolataId) ON DELETE CASCADE,
    utenteId          INTEGER NOT NULL REFERENCES utenti(utenteId)       ON DELETE CASCADE,
    joinedAt          TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE (tombolataId, utenteId)
);

CREATE INDEX idx_tombolate_utenti ON tombolate_utenti(tombolataId, utenteId);

-- ------------------------------------------------------------
-- CARTELLE
-- ------------------------------------------------------------
CREATE TABLE cartelle (
    cartellaId  INTEGER PRIMARY KEY AUTOINCREMENT,
    tombolataId INTEGER NOT NULL REFERENCES tombolate(tombolataId) ON DELETE CASCADE,
    utenteId    INTEGER          REFERENCES utenti(utenteId)       ON DELETE SET NULL,
        -- NULL se non ancora assegnata
    createdAt   TEXT    NOT NULL DEFAULT (datetime('now')),
    updatedAt   TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_cartelle_tombolata ON cartelle(tombolataId);
CREATE INDEX idx_cartelle_utente    ON cartelle(utenteId);

-- ------------------------------------------------------------
-- NUMERI DELLE CARTELLE
-- Ogni cartella ha esattamente 15 numeri, distribuiti in 3 righe.
-- Ogni riga ha esattamente 5 numeri in 9 slot di colonna.
-- ------------------------------------------------------------
CREATE TABLE numeri_cartella (
    numeroCartellaId INTEGER PRIMARY KEY AUTOINCREMENT,
    cartellaId       INTEGER NOT NULL REFERENCES cartelle(cartellaId) ON DELETE CASCADE,
    numero           INTEGER NOT NULL CHECK (numero BETWEEN 1 AND 90),
    riga             INTEGER NOT NULL CHECK (riga BETWEEN 1 AND 3),
    colonna          INTEGER NOT NULL CHECK (colonna BETWEEN 1 AND 9),
        -- colonna determina il decile: col 1 → 1-9, col 2 → 10-19, ecc.
    UNIQUE (cartellaId, numero),
    UNIQUE (cartellaId, riga, colonna),
        -- una sola cella per posizione nella cartella
    -- Vincolo di coerenza decile: la colonna deve corrispondere al decile del numero
    CHECK (
        (colonna = 1 AND numero BETWEEN  1 AND  9) OR
        (colonna = 2 AND numero BETWEEN 10 AND 19) OR
        (colonna = 3 AND numero BETWEEN 20 AND 29) OR
        (colonna = 4 AND numero BETWEEN 30 AND 39) OR
        (colonna = 5 AND numero BETWEEN 40 AND 49) OR
        (colonna = 6 AND numero BETWEEN 50 AND 59) OR
        (colonna = 7 AND numero BETWEEN 60 AND 69) OR
        (colonna = 8 AND numero BETWEEN 70 AND 79) OR
        (colonna = 9 AND numero BETWEEN 80 AND 90)
    )
);

CREATE INDEX idx_numeri_cartella ON numeri_cartella(cartellaId);

-- Vincolo: i numeri di uno stesso utente nella stessa tombolata non si ripetono.
-- Implementato a livello applicativo (query di controllo prima dell'inserimento).

-- ------------------------------------------------------------
-- ESTRAZIONI
-- ------------------------------------------------------------
CREATE TABLE estrazioni (
    estrazioneId INTEGER PRIMARY KEY AUTOINCREMENT,
    tombolataId  INTEGER NOT NULL REFERENCES tombolate(tombolataId) ON DELETE CASCADE,
    numero       INTEGER NOT NULL CHECK (numero BETWEEN 1 AND 90),
    ordine       INTEGER NOT NULL,
        -- progressivo di estrazione (1 = primo estratto, ecc.)
    estrattoAt   TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE (tombolataId, numero),
    UNIQUE (tombolataId, ordine)
);

CREATE INDEX idx_estrazioni_tombolata ON estrazioni(tombolataId);

-- ------------------------------------------------------------
-- VINCITE
-- ------------------------------------------------------------
CREATE TABLE vincite (
    vincitaId       INTEGER PRIMARY KEY AUTOINCREMENT,
    tombolataId     INTEGER NOT NULL REFERENCES tombolate(tombolataId) ON DELETE CASCADE,
    cartellaId      INTEGER NOT NULL REFERENCES cartelle(cartellaId)   ON DELETE CASCADE,
    utenteId        INTEGER NOT NULL REFERENCES utenti(utenteId)       ON DELETE CASCADE,
    tipoVincita     TEXT    NOT NULL CHECK (tipoVincita IN ('ambo','terno','quaterna','cinquina','tombola')),
    riga            INTEGER CHECK (riga BETWEEN 1 AND 3),
        -- riga della cartella dove è avvenuta la vincita (NULL per tombola)
    numeroEstratto  INTEGER,
        -- numero che ha completato la vincita
    confermata      INTEGER NOT NULL DEFAULT 0,
        -- 0 = rilevata automaticamente, 1 = confermata dal gestore
    vintaAt         TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE (tombolataId, cartellaId, tipoVincita)
        -- una cartella può vincere ogni tipo una sola volta
);

CREATE INDEX idx_vincite_tombolata ON vincite(tombolataId);
CREATE INDEX idx_vincite_utente    ON vincite(utenteId);

-- Nota: la gestione di updatedAt, le transizioni di stato delle tombolate
-- e le query di supporto sono demandate al livello applicativo.
