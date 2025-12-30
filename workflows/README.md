# Workflow n8n

Questa cartella contiene workflow esportati da n8n per l'automazione dei processi nell'ecosistema (GLPI, Chatwoot, integrazione servizi).

## Workflow Disponibili

| File | Descrizione | Categoria |
|------|-------------|-----------|
| `log_associazioni.json` | Automazione per la gestione dei log delle associazioni in GLPI | GLPI |
| `mail_associazioni.json` | Automazione per l'invio email relative alle associazioni GLPI | GLPI |
| `chatwoot-message-handler.json` | Gestione automatica messaggi Chatwoot: salvataggio DB, risposte automatiche, notifiche | Chatwoot ↔ n8n |
| `n8n-to-chatwoot-messages.json` | Invio messaggi proattivi a Chatwoot: follow-up automatici, API per invio messaggi | n8n → Chatwoot |

## Integrazione n8n ↔ Chatwoot

### Panoramica

L'integrazione tra n8n e Chatwoot permette di:

- **Ricevere eventi da Chatwoot** tramite webhook (nuovi messaggi, cambio stato, etc.)
- **Inviare messaggi automatici** a conversazioni Chatwoot
- **Salvare conversazioni** in database per analisi
- **Creare automazioni** (risposte automatiche, escalation, follow-up)
- **Integrare con altri servizi** (GLPI, CRM, email, Slack)

### Prerequisiti

1. ✅ n8n installato e configurato con SSL ([guida](../core-ecosystem/04-n8n-installation.md))
2. ✅ Chatwoot installato e configurato con SSL ([guida](../applications/chatwoot/README.md))
3. ✅ Entrambi connessi alla rete `glpi-net`
4. ✅ Database PostgreSQL per n8n configurato
5. 🔧 Token API Chatwoot (vedi sotto)

### Configurazione API Chatwoot

#### 1. Ottieni il Token API

1. Accedi a Chatwoot (`https://chatwoot.tuodominio.com`)
2. Vai su **Profile Settings** → **Access Token**
3. Copia il token (esempio: `abcd1234efgh5678ijkl`)

#### 2. Configura Credenziali in n8n

1. Accedi a n8n (`https://n8n.tuodominio.com`)
2. Vai su **Credentials** → **New**
3. Cerca "HTTP Header Auth"
4. Configura:
   - **Name**: `Chatwoot API`
   - **Header Name**: `api_access_token`
   - **Header Value**: `<il_tuo_token_api>`
5. **Save**

#### 3. Trova Account ID e Inbox ID

```bash
# Ottieni Account ID
curl -H "api_access_token: TUO_TOKEN" \
  https://chatwoot.tuodominio.com/api/v1/accounts

# Output: [{"id": 1, "name": "My Account"}]

# Ottieni Inbox ID
curl -H "api_access_token: TUO_TOKEN" \
  https://chatwoot.tuodominio.com/api/v1/accounts/1/inboxes

# Output: [{"id": 1, "name": "Website", "channel_type": "Channel::WebWidget"}]
```

Salva questi ID, ti serviranno per configurare i workflow.

### Configurazione Webhook Chatwoot → n8n

#### 1. Importa Workflow in n8n

```bash
# Importa da n8n UI
Workflows → Import from File → Seleziona chatwoot-message-handler.json
```

#### 2. Ottieni URL Webhook

1. Apri il workflow importato
2. Clicca sul nodo "Chatwoot Webhook"
3. Copia l'URL di produzione (es: `https://n8n.tuodominio.com/webhook/chatwoot-webhook`)

#### 3. Configura Webhook in Chatwoot

1. In Chatwoot vai su **Settings** → **Integrations** → **Webhooks**
2. Click su **Add Webhook**
3. Configura:
   - **Endpoint URL**: `https://n8n.tuodominio.com/webhook/chatwoot-webhook`
   - **Events**: Seleziona gli eventi desiderati:
     - ☑️ `message_created` (nuovo messaggio)
     - ☑️ `conversation_created` (nuova conversazione)
     - ☑️ `conversation_status_changed` (cambio stato)
     - ☑️ `conversation_updated` (conversazione aggiornata)
4. **Save**

#### 4. Test Webhook

1. In n8n, attiva il workflow: **Active = ON**
2. In Chatwoot, invia un messaggio di test
3. In n8n, vai su **Executions** → dovresti vedere l'esecuzione del workflow

### Schema Database (opzionale, per persistenza)

Se vuoi salvare i messaggi/conversazioni in database, crea queste tabelle:

```sql
-- Tabella conversazioni
CREATE TABLE chatwoot_conversations (
  conversation_id BIGINT PRIMARY KEY,
  account_id INT,
  inbox_id INT,
  contact_id BIGINT,
  contact_name VARCHAR(255),
  contact_email VARCHAR(255),
  status VARCHAR(50),
  assigned_agent VARCHAR(255),
  last_message_at TIMESTAMP,
  last_followup_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Tabella messaggi
CREATE TABLE chatwoot_messages (
  id SERIAL PRIMARY KEY,
  conversation_id BIGINT REFERENCES chatwoot_conversations(conversation_id),
  contact_name VARCHAR(255),
  contact_email VARCHAR(255),
  message_content TEXT,
  message_type VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indici per performance
CREATE INDEX idx_conversations_status ON chatwoot_conversations(status);
CREATE INDEX idx_conversations_last_message ON chatwoot_conversations(last_message_at);
CREATE INDEX idx_messages_conversation ON chatwoot_messages(conversation_id);
```

Esegui nel database PostgreSQL di n8n:

```bash
docker exec -it n8n-postgres psql -U n8n -d n8ndb -f schema.sql
```

### Workflow Dettagliati

#### 1. chatwoot-message-handler.json

**Funzionalità:**
- Riceve webhook da Chatwoot
- Filtra messaggi in arrivo dai clienti
- Salva messaggi in database
- Rileva messaggi urgenti (contenenti "urgente")
- Invia risposta automatica per messaggi urgenti
- Notifica via email il team support
- Aggiorna status conversazioni

**Configurazione necessaria:**
1. Credenziale "Chatwoot API" (HTTP Header Auth)
2. Credenziale "n8n-postgres" (PostgreSQL)
3. Credenziale "SMTP Account" (per email)
4. Sostituisci `tuodominio.com` con il tuo dominio

**Eventi gestiti:**
- `message_created`: Nuovo messaggio ricevuto
- `conversation_status_changed`: Conversazione chiusa/riaperta

#### 2. n8n-to-chatwoot-messages.json

**Funzionalità:**

**A) Follow-up automatico (Scheduled)**
- Esegue ogni mattina alle 9:00
- Trova conversazioni aperte inattive da 24h+
- Invia messaggio di follow-up automatico
- Aggiorna timestamp ultimo follow-up

**B) API per invio messaggi (Webhook)**
- Endpoint: `POST https://n8n.tuodominio.com/webhook/send-chatwoot-message`
- Cerca o crea contatto
- Crea conversazione
- Invia messaggio

**Payload API:**
```json
{
  "account_id": 1,
  "inbox_id": 1,
  "contact_name": "Mario Rossi",
  "contact_email": "mario.rossi@example.com",
  "message": "Ciao Mario, hai richiesto assistenza?"
}
```

**Risposta:**
```json
{
  "success": true,
  "conversation_id": 123,
  "message_id": 456
}
```

**Test con curl:**
```bash
curl -X POST https://n8n.tuodominio.com/webhook/send-chatwoot-message \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": 1,
    "inbox_id": 1,
    "contact_name": "Test User",
    "contact_email": "test@example.com",
    "message": "Test messaggio da n8n"
  }'
```

### Esempi di Casi d'Uso

#### 1. Escalation Automatica a GLPI

Crea ticket GLPI quando messaggio Chatwoot contiene "supporto tecnico":

```javascript
// In nodo Code dopo ricezione messaggio
if ($json.messageContent.includes("supporto tecnico")) {
  return {
    json: {
      title: `Richiesta da ${$json.contactName}`,
      content: $json.messageContent,
      urgency: 4,
      impact: 3,
      user_email: $json.contactEmail
    }
  };
}
```

Poi collega nodo "MySQL" per insert in `glpi_tickets`.

#### 2. Notifica Slack per VIP

Notifica team su Slack quando cliente VIP scrive:

```javascript
// Controlla se contatto è VIP
const vipEmails = ["ceo@company.com", "director@company.com"];
if (vipEmails.includes($json.contactEmail)) {
  return { json: { isVIP: true, ...$ json } };
}
```

Poi collega nodo "Slack" per invio notifica.

#### 3. Risposta Automatica Orari Chiusura

Invia risposta automatica se messaggio ricevuto fuori orario:

```javascript
// In nodo Code
const hour = new Date().getHours();
const isOfficeHours = hour >= 9 && hour < 18;

if (!isOfficeHours) {
  return {
    json: {
      shouldAutoReply: true,
      message: "Grazie per il tuo messaggio. L'ufficio è chiuso, ti risponderemo domani mattina."
    }
  };
}
```

#### 4. Sentiment Analysis

Analizza sentiment del messaggio e prioritizza:

```javascript
// Integra con API sentiment analysis
const negativePhrases = ["deluso", "insoddisfatto", "problema", "errore"];
const isNegative = negativePhrases.some(phrase => 
  $json.messageContent.toLowerCase().includes(phrase)
);

if (isNegative) {
  return { json: { priority: "high", sentiment: "negative" } };
}
```

### Monitoraggio e Debug

#### Visualizza Log n8n

```bash
docker logs n8n -f
```

#### Visualizza Esecuzioni Workflow

1. In n8n vai su **Executions**
2. Filtra per workflow specifico
3. Clicca su esecuzione per vedere dettagli e dati

#### Test Webhook Manuale

```bash
# Simula evento Chatwoot
curl -X POST https://n8n.tuodominio.com/webhook/chatwoot-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "event": "message_created",
    "id": 123,
    "message_type": "incoming",
    "content": "Test messaggio urgente",
    "sender": {
      "id": 1,
      "name": "Test User",
      "email": "test@example.com"
    },
    "conversation": {
      "id": 456,
      "status": "open"
    },
    "account": {
      "id": 1
    },
    "inbox": {
      "id": 1
    },
    "created_at": "2025-12-30T10:00:00Z"
  }'
```

### Troubleshooting

#### Webhook non riceve eventi

1. **Verifica URL webhook**:
   ```bash
   curl -I https://n8n.tuodominio.com/webhook/chatwoot-webhook
   # Dovrebbe rispondere 200 o 405
   ```

2. **Controlla configurazione Chatwoot**:
   - Vai su Settings → Integrations → Webhooks
   - Verifica che URL sia corretto
   - Controlla log eventi (webhook delivery log)

3. **Verifica workflow attivo**:
   - In n8n, assicurati che workflow sia **Active = ON**

#### Errore 401 chiamate API Chatwoot

1. **Verifica token API**:
   ```bash
   curl -H "api_access_token: TUO_TOKEN" \
     https://chatwoot.tuodominio.com/api/v1/accounts
   ```

2. **Ricontrolla credenziali n8n**:
   - Header name: `api_access_token` (non `Authorization`)
   - Header value: solo il token (senza "Bearer")

#### Database errors

1. **Verifica connessione PostgreSQL**:
   ```bash
   docker exec -it n8n-postgres psql -U n8n -d n8ndb -c "\dt"
   ```

2. **Controlla che tabelle esistano**:
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public';
   ```

### Risorse

- [Chatwoot API Documentation](https://www.chatwoot.com/developers/api/)
- [Chatwoot Webhooks Guide](https://www.chatwoot.com/docs/product/others/webhooks)
- [n8n HTTP Request Node](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/)
- [n8n Webhook Node](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)

## Come Importare Workflow

1. Accedi a n8n
2. Vai su **Workflows** → **Import from File**
3. Seleziona il file `.json` desiderato
4. Configura le credenziali necessarie (database, email, API, etc.)
5. Sostituisci `tuodominio.com` con il tuo dominio
6. Aggiorna Account ID e Inbox ID
7. Attiva il workflow: **Active = ON**
8. Testa con dati reali o simulati

## Contribuire

Per aggiungere nuovi workflow:
1. Esporta da n8n in formato JSON
2. Aggiungi alla cartella `workflows/`
3. Aggiorna questa documentazione con descrizione e istruzioni
