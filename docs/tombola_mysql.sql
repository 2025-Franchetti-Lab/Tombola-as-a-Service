-- ============================================================
-- TOMBOLA AS A SERVICE (TaaS) - DDL per MySQL 8+
-- ============================================================
-- Struttura della cartella tombola:
--   3 righe x 9 colonne, con 5 numeri per riga (15 numeri totali)
--   Colonna 1: numeri 1-9
--   Colonna 2: numeri 10-19, ..., Colonna 9: numeri 80-90
-- Vincite in ordine: Ambo (2 sulla stessa riga), Terno (3),
--   Quaterna (4), Cinquina (5 = riga completa), Tombola (15)
-- Un utente che ha vinto un premio non può concorrere al successivo
-- ============================================================

CREATE DATABASE IF NOT EXISTS tombola
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE tombola;

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ------------------------------------------------------------
-- UTENTI
-- ------------------------------------------------------------
CREATE TABLE utenti (
    utenteId    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome        VARCHAR(100) NOT NULL,
    cognome     VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    authMethod  ENUM('password','otp','oauth','magic_link')
                             NOT NULL DEFAULT 'password',
    authData    TEXT                  DEFAULT NULL,
        -- hash della password, token oauth, ecc. (dipende da authMethod)
    attivo      TINYINT(1)   NOT NULL DEFAULT 1,
    createdAt   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (utenteId),
    UNIQUE KEY uq_utenti_email (email),
    INDEX idx_utenti_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- TOMBOLATE (sessioni di gioco)
-- ------------------------------------------------------------
CREATE TABLE tombolate (
    tombolataId                     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome                            VARCHAR(200) NOT NULL,
    gestoreNome                     VARCHAR(200) NOT NULL,
    authMethodUtenti                ENUM('password','otp','oauth','magic_link','none')
                                                 NOT NULL DEFAULT 'password',
    dataAttivazione                 DATETIME              DEFAULT NULL,
    dataFineAssegnazioneCartelle    DATETIME              DEFAULT NULL,
    stato                           ENUM('creata','aperta','attiva','terminata')
                                                 NOT NULL DEFAULT 'creata',
        -- creata    = configurazione in corso
        -- aperta    = assegnazione cartelle aperta agli utenti
        -- attiva    = estrazione numeri in corso
        -- terminata = gioco concluso
    createdAt                       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt                       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                          ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tombolataId),
    INDEX idx_tombolate_stato (stato)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- TOMBOLATE_UTENTI  (partecipanti registrati a una tombolata)
-- ------------------------------------------------------------
CREATE TABLE tombolate_utenti (
    tombolataUtenteId INT UNSIGNED NOT NULL AUTO_INCREMENT,
    tombolataId       INT UNSIGNED NOT NULL,
    utenteId          INT UNSIGNED NOT NULL,
    joinedAt          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tombolataUtenteId),
    UNIQUE KEY uq_tombolata_utente (tombolataId, utenteId),
    INDEX idx_tu_utente (utenteId),
    CONSTRAINT fk_tu_tombolata
        FOREIGN KEY (tombolataId) REFERENCES tombolate(tombolataId)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tu_utente
        FOREIGN KEY (utenteId)    REFERENCES utenti(utenteId)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- CARTELLE
-- ------------------------------------------------------------
CREATE TABLE cartelle (
    cartellaId  INT UNSIGNED NOT NULL AUTO_INCREMENT,
    tombolataId INT UNSIGNED NOT NULL,
    utenteId    INT UNSIGNED          DEFAULT NULL,
        -- NULL se non ancora assegnata a un utente
    createdAt   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (cartellaId),
    INDEX idx_cartelle_tombolata (tombolataId),
    INDEX idx_cartelle_utente    (utenteId),
    CONSTRAINT fk_cartelle_tombolata
        FOREIGN KEY (tombolataId) REFERENCES tombolate(tombolataId)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cartelle_utente
        FOREIGN KEY (utenteId)    REFERENCES utenti(utenteId)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- NUMERI DELLE CARTELLE
-- Ogni cartella ha esattamente 15 numeri, distribuiti in 3 righe.
-- Ogni riga ha esattamente 5 numeri in 9 slot di colonna.
-- ------------------------------------------------------------
CREATE TABLE numeri_cartella (
    numeroCartellaId INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    cartellaId       INT UNSIGNED     NOT NULL,
    numero           TINYINT UNSIGNED NOT NULL,
    riga             TINYINT UNSIGNED NOT NULL COMMENT '1-3',
    colonna          TINYINT UNSIGNED NOT NULL COMMENT '1-9 (decile del numero)',
    PRIMARY KEY (numeroCartellaId),
    UNIQUE KEY uq_nc_cartella_numero    (cartellaId, numero),
    UNIQUE KEY uq_nc_cartella_posizione (cartellaId, riga, colonna),
    INDEX idx_nc_cartella (cartellaId),
    CONSTRAINT chk_numero  CHECK (numero  BETWEEN 1 AND 90),
    CONSTRAINT chk_riga    CHECK (riga    BETWEEN 1 AND 3),
    CONSTRAINT chk_colonna CHECK (colonna BETWEEN 1 AND 9),
    -- Vincolo di coerenza decile: la colonna deve corrispondere al decile del numero
    CONSTRAINT chk_colonna_decile CHECK (
        (colonna = 1 AND numero BETWEEN  1 AND  9) OR
        (colonna = 2 AND numero BETWEEN 10 AND 19) OR
        (colonna = 3 AND numero BETWEEN 20 AND 29) OR
        (colonna = 4 AND numero BETWEEN 30 AND 39) OR
        (colonna = 5 AND numero BETWEEN 40 AND 49) OR
        (colonna = 6 AND numero BETWEEN 50 AND 59) OR
        (colonna = 7 AND numero BETWEEN 60 AND 69) OR
        (colonna = 8 AND numero BETWEEN 70 AND 79) OR
        (colonna = 9 AND numero BETWEEN 80 AND 90)
    ),
    CONSTRAINT fk_nc_cartella
        FOREIGN KEY (cartellaId) REFERENCES cartelle(cartellaId)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vincolo: i numeri di uno stesso utente nella stessa tombolata non si ripetono.
-- Implementato a livello applicativo (query di controllo prima dell'inserimento).

-- ------------------------------------------------------------
-- ESTRAZIONI
-- ------------------------------------------------------------
CREATE TABLE estrazioni (
    estrazioneId INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    tombolataId  INT UNSIGNED     NOT NULL,
    numero       TINYINT UNSIGNED NOT NULL,
    ordine       SMALLINT UNSIGNED NOT NULL COMMENT 'progressivo di estrazione (1=primo)',
    estrattoAt   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (estrazioneId),
    UNIQUE KEY uq_estrazione_numero (tombolataId, numero),
    UNIQUE KEY uq_estrazione_ordine (tombolataId, ordine),
    INDEX idx_estrazioni_tombolata (tombolataId),
    CONSTRAINT chk_numero_estrazione CHECK (numero BETWEEN 1 AND 90),
    CONSTRAINT fk_estrazioni_tombolata
        FOREIGN KEY (tombolataId) REFERENCES tombolate(tombolataId)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- VINCITE
-- ------------------------------------------------------------
CREATE TABLE vincite (
    vincitaId      INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    tombolataId    INT UNSIGNED     NOT NULL,
    cartellaId     INT UNSIGNED     NOT NULL,
    utenteId       INT UNSIGNED     NOT NULL,
    tipoVincita    VARCHAR(20)      NOT NULL,
    riga           TINYINT UNSIGNED          DEFAULT NULL
                       COMMENT 'riga della cartella (NULL per tombola)',
    numeroEstratto TINYINT UNSIGNED          DEFAULT NULL
                       COMMENT 'numero che ha completato la vincita',
    confermata     TINYINT(1)       NOT NULL DEFAULT 0
                       COMMENT '0=automatica, 1=confermata dal gestore',
    vintaAt        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (vincitaId),
    UNIQUE KEY uq_vincita_cartella_tipo (tombolataId, cartellaId, tipoVincita),
    INDEX idx_vincite_tombolata (tombolataId),
    INDEX idx_vincite_utente    (utenteId),
    CONSTRAINT chk_tipo_vincita CHECK (tipoVincita IN ('ambo','terno','quaterna','cinquina','tombola')),
    CONSTRAINT fk_vincite_tombolata
        FOREIGN KEY (tombolataId) REFERENCES tombolate(tombolataId)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_vincite_cartella
        FOREIGN KEY (cartellaId)  REFERENCES cartelle(cartellaId)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_vincite_utente
        FOREIGN KEY (utenteId)    REFERENCES utenti(utenteId)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Nota: la gestione delle transizioni di stato delle tombolate e
-- le query di supporto sono demandate al livello applicativo.
