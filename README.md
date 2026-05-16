# GTA SA open.mp NPC TTS Server

Servidor open.mp para GTA San Andreas com:

- Gamemode `normal`
- NPC na Grove Street
- Inventario de armas com `/inv`
- Magia de bola de fogo usando soco ingles
- NPC com resposta por voz usando Ollama local + ElevenLabs TTS

## Configuracao

Copie `.env.example` para `.env` e preencha:

```env
NPC_LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=qwen2.5:0.5b

ELEVENLABS_API_KEY=sua_chave
ELEVENLABS_VOICE_ID=seu_voice_id
ELEVENLABS_MODEL_ID=eleven_flash_v2_5
```

Instale/rode o modelo no Ollama:

```powershell
ollama pull qwen2.5:0.5b
```

## Rodar

Em um terminal:

```powershell
.\start-audio-server.ps1
```

Em outro:

```powershell
.\start-server.ps1
```

Entre no servidor em:

```text
127.0.0.1:7777
```

## Comandos no jogo

```text
/npc sua mensagem
/inv
/grove
/intro
/stopmusic
```
