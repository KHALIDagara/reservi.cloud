# Meta inbox setup

Reservi Account administrators connect WhatsApp and Instagram from **Manage → Inboxes**. Provider credentials belong to the server deployment; OAuth access tokens returned for an inbox are encrypted at rest on its `Channel`.

## Server configuration

Configure the relevant environment variables before connecting an inbox:

```text
WHATSAPP_APP_ID
WHATSAPP_APP_SECRET
WHATSAPP_CONFIGURATION_ID

INSTAGRAM_APP_ID
INSTAGRAM_APP_SECRET

META_WEBHOOK_VERIFY_TOKEN
META_GRAPH_VERSION             # optional; defaults to v22.0
```

`WHATSAPP_WEBHOOK_VERIFY_TOKEN` or `INSTAGRAM_WEBHOOK_VERIFY_TOKEN` may override the shared verification token for one provider.

## Meta application callbacks

Configure these public HTTPS callback URLs in the Meta application:

```text
Instagram OAuth redirect:  /oauth/channels/instagram/callback
WhatsApp webhook:          /webhooks/meta/whatsapp
Instagram webhook:         /webhooks/meta/instagram
```

Use the configured webhook verification token when registering either webhook. Event requests are accepted only when their `X-Hub-Signature-256` HMAC matches the provider app secret. Reservi resolves the destination Channel from the signed provider account/phone identity; a provider inbox can belong to only one Reservi Account.

WhatsApp uses Meta Embedded Signup. Instagram uses Instagram Business OAuth. Both connection paths subscribe the selected provider account to webhook events and keep provider access tokens out of `provider_config` and rendered HTML.
