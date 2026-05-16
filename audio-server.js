const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { spawn } = require("child_process");

const host = "127.0.0.1";
const port = 3001;
const baseDir = __dirname;
const introPath = path.join(baseDir, "intro.mp3");
const npcAudioDir = path.join(baseDir, "npc-audio");
const npcAudioTtlMs = Number(process.env.NPC_AUDIO_TTL_MS || 120000);

function loadDotEnv(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separator = trimmed.indexOf("=");
    if (separator === -1) {
      continue;
    }

    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim().replace(/^["']|["']$/g, "");
    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

loadDotEnv(path.join(baseDir, ".env"));

const openRouterApiKey = process.env.OPENROUTER_API_KEY || "";
const openRouterModel = process.env.OPENROUTER_MODEL || "meta-llama/llama-3.1-8b-instruct:free";
const openRouterReferer = process.env.OPENROUTER_SITE_URL || "http://127.0.0.1:3001";
const openRouterTitle = process.env.OPENROUTER_APP_NAME || "GTA SA NPC Server";
const llmProvider = (process.env.NPC_LLM_PROVIDER || "openrouter").toLowerCase();
const ollamaBaseUrl = (process.env.OLLAMA_BASE_URL || "http://127.0.0.1:11434").replace(/\/+$/, "");
const ollamaModel = process.env.OLLAMA_MODEL || "qwen2.5:0.5b";
const elevenLabsApiKey = process.env.ELEVENLABS_API_KEY || "";
const elevenLabsVoiceId = process.env.ELEVENLABS_VOICE_ID || "";
const elevenLabsModel = process.env.ELEVENLABS_MODEL_ID || "eleven_flash_v2_5";
const ttsProvider = (process.env.TTS_PROVIDER || "elevenlabs").toLowerCase();
const piperMode = (process.env.PIPER_MODE || "cli").toLowerCase();
const piperHttpUrl = process.env.PIPER_HTTP_URL || "http://127.0.0.1:5000/";
const piperExecutable = process.env.PIPER_EXECUTABLE || "piper";
const piperModel = process.env.PIPER_MODEL || "pt_BR-edresson-low";
const piperOutputFormat = (process.env.PIPER_OUTPUT_FORMAT || "wav").toLowerCase();
const ffmpegExecutable = process.env.FFMPEG_EXECUTABLE || "ffmpeg";
const piperLengthScale = Number(process.env.PIPER_LENGTH_SCALE || 0.9);
const piperNoiseScale = Number(process.env.PIPER_NOISE_SCALE || 0.55);
const piperNoiseWScale = Number(process.env.PIPER_NOISE_W_SCALE || 0.7);

fs.mkdirSync(npcAudioDir, { recursive: true });

function scheduleDelete(filePath, delayMs = npcAudioTtlMs) {
  setTimeout(() => {
    fs.promises.unlink(filePath).catch(() => {});
  }, delayMs).unref();
}

function cleanupOldNpcAudio() {
  fs.readdir(npcAudioDir, { withFileTypes: true }, (error, entries) => {
    if (error) {
      return;
    }

    const now = Date.now();
    for (const entry of entries) {
      if (!entry.isFile()) {
        continue;
      }

      const filePath = path.join(npcAudioDir, entry.name);
      fs.stat(filePath, (statError, stat) => {
        if (!statError && now - stat.mtimeMs > npcAudioTtlMs) {
          fs.promises.unlink(filePath).catch(() => {});
        }
      });
    }
  });
}

cleanupOldNpcAudio();
setInterval(cleanupOldNpcAudio, 60000).unref();

function sendText(res, status, text) {
  res.writeHead(status, { "content-type": "text/plain; charset=utf-8" });
  res.end(text);
}

function getAudioContentType(fileName) {
  if (fileName.endsWith(".wav")) {
    return "audio/wav";
  }

  return "audio/mpeg";
}

function sanitizeForPawn(text) {
  return String(text)
    .replace(/<think>[\s\S]*?<\/think>/gi, " ")
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/[|\r\n\t]/g, " ")
    .replace(/["“”]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 130);
}

function extractFinalAnswer(data) {
  const message = data?.choices?.[0]?.message;
  let content = "";

  if (typeof message?.content === "string") {
    content = message.content;
  } else if (Array.isArray(message?.content)) {
    content = message.content
      .map(part => typeof part === "string" ? part : part?.text || "")
      .join(" ");
  }

  content = content
    .replace(/<think>[\s\S]*?<\/think>/gi, " ")
    .replace(/(?:^|\s)(?:reasoning|pensamento|racioc[ií]nio)\s*:\s*[\s\S]*?(?:resposta\s*final\s*:|final\s*:)/i, " ")
    .replace(/^(?:resposta\s*final|final answer|resposta)\s*:\s*/i, "")
    .trim();

  if (!content && typeof message?.reasoning === "string") {
    return "";
  }

  return content;
}

function looksLikeReasoningLeak(text) {
  return /\b(we need to|need to respond|possible answer|system prompt|no extra commentary|just the speech|as an npc|responda em portugues|racioc[ií]nio|pensamento)\b/i.test(text);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", chunk => {
      body += chunk;
      if (body.length > 1000) {
        req.destroy();
        reject(new Error("Mensagem muito grande"));
      }
    });
    req.on("end", () => resolve(body.trim()));
    req.on("error", reject);
  });
}

function runProcess(command, args, input) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      windowsHide: true,
      stdio: ["pipe", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", chunk => { stdout += chunk; });
    child.stderr.on("data", chunk => { stderr += chunk; });
    child.on("error", reject);
    child.on("close", code => {
      if (code !== 0) {
        reject(new Error(`${command} saiu com codigo ${code}: ${stderr || stdout}`.trim()));
        return;
      }
      resolve({ stdout, stderr });
    });

    if (input) {
      child.stdin.write(input);
    }
    child.stdin.end();
  });
}

function resolvePiperModelPath() {
  if (fs.existsSync(piperModel)) {
    return piperModel;
  }

  const candidates = [
    path.join(baseDir, "piper-models", `${piperModel}.onnx`),
    path.join(baseDir, "piper-models", piperModel, `${piperModel}.onnx`),
    path.join(baseDir, "Server", `${piperModel}.onnx`),
    path.join(baseDir, `${piperModel}.onnx`)
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  throw new Error(`Modelo Piper nao encontrado: ${piperModel}. Coloque ${piperModel}.onnx e ${piperModel}.onnx.json em piper-models/ ou use PIPER_MODEL com caminho completo.`);
}

async function callOpenRouter(body) {
  if (!openRouterApiKey) {
    throw new Error("OPENROUTER_API_KEY nao configurada");
  }

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${openRouterApiKey}`,
      "content-type": "application/json",
      "http-referer": openRouterReferer,
      "x-title": openRouterTitle
    },
    body: JSON.stringify(body)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenRouter ${response.status}: ${errorText.slice(0, 300)}`);
  }

  return response;
}

async function generateNpcText(message) {
  if (llmProvider === "ollama") {
    return generateNpcTextWithOllama(message);
  }

  if (llmProvider !== "openrouter") {
    throw new Error(`NPC_LLM_PROVIDER invalido: ${llmProvider}`);
  }

  return generateNpcTextWithOpenRouter(message);
}

async function generateNpcTextWithOpenRouter(message) {
  const response = await callOpenRouter({
    model: openRouterModel,
    temperature: 0.8,
    max_tokens: 90,
    messages: [
      {
        role: "system",
        content: [
          "Voce e um NPC da Grove Street em um servidor GTA San Andreas.",
          "Responda em portugues do Brasil.",
          "Seja curto, natural e no personagem.",
          "Fale como um morador de rua amigavel da Grove, sem exagerar em girias.",
          "Retorne somente a fala final do NPC.",
          "Nao escreva pensamentos, raciocinio, analise, explicacoes ou tags <think>.",
          "Nao diga que voce e uma IA, a menos que o jogador pergunte diretamente.",
          "Use uma frase curta com no maximo 12 palavras."
        ].join(" ")
      },
      {
        role: "user",
        content: message
      }
    ]
  });

  const data = await response.json();
  const answer = sanitizeForPawn(extractFinalAnswer(data));
  if (!answer || looksLikeReasoningLeak(answer)) {
    return "E ai, parceiro. Fala comigo de novo, direto ao ponto.";
  }
  return answer;
}

async function generateNpcTextWithOllama(message) {
  const response = await fetch(`${ollamaBaseUrl}/api/chat`, {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: ollamaModel,
      stream: false,
      options: {
        temperature: 0.45,
        top_p: 0.8,
        repeat_penalty: 1.12,
        num_predict: 35
      },
      messages: [
        {
          role: "system",
          content: [
            "Voce e um NPC da Grove Street em um servidor GTA San Andreas.",
            "Responda em portugues do Brasil.",
            "Seja curto, natural e no personagem.",
            "Fale como um morador amigavel da Grove, sem exagerar em girias.",
            "Retorne somente a fala final do NPC.",
            "Nao escreva pensamentos, raciocinio, analise, explicacoes ou tags <think>.",
            "Nao diga que voce e uma IA, a menos que o jogador pergunte diretamente.",
            "Use uma frase curta com no maximo 12 palavras."
          ].join(" ")
        },
        {
          role: "user",
          content: message
        }
      ]
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Ollama ${response.status}: ${errorText.slice(0, 300)}`);
  }

  const data = await response.json();
  const answer = sanitizeForPawn(data?.message?.content || data?.response || "");
  if (!answer || looksLikeReasoningLeak(answer)) {
    return "E ai, parceiro. Fala comigo de novo, direto ao ponto.";
  }
  return answer;
}

async function generateNpcAudio(text) {
  if (ttsProvider === "piper") {
    return generateNpcAudioWithPiper(text);
  }

  if (ttsProvider !== "elevenlabs") {
    throw new Error(`TTS_PROVIDER invalido: ${ttsProvider}`);
  }

  return generateNpcAudioWithElevenLabs(text);
}

async function generateNpcAudioWithElevenLabs(text) {
  if (!elevenLabsApiKey) {
    throw new Error("ELEVENLABS_API_KEY nao configurada");
  }

  if (!elevenLabsVoiceId) {
    throw new Error("ELEVENLABS_VOICE_ID nao configurada");
  }

  const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(elevenLabsVoiceId)}`, {
    method: "POST",
    headers: {
      "xi-api-key": elevenLabsApiKey,
      "content-type": "application/json",
      "accept": "audio/mpeg"
    },
    body: JSON.stringify({
      text,
      model_id: elevenLabsModel,
      voice_settings: {
        stability: 0.45,
        similarity_boost: 0.75,
        style: 0.25,
        use_speaker_boost: true
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`ElevenLabs ${response.status}: ${errorText.slice(0, 300)}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const fileName = `${Date.now()}-${crypto.randomUUID()}.mp3`;
  const filePath = path.join(npcAudioDir, fileName);
  await fs.promises.writeFile(filePath, Buffer.from(arrayBuffer));
  scheduleDelete(filePath);
  return `http://${host}:${port}/npc-audio/${fileName}`;
}

async function generateNpcAudioWithPiper(text) {
  if (piperMode === "http") {
    return generateNpcAudioWithPiperHttp(text);
  }

  if (piperMode !== "cli") {
    throw new Error(`PIPER_MODE invalido: ${piperMode}`);
  }

  const modelPath = resolvePiperModelPath();
  const wavName = `${Date.now()}-${crypto.randomUUID()}.wav`;
  const wavPath = path.join(npcAudioDir, wavName);

  await runProcess(piperExecutable, ["--model", modelPath, "--output_file", wavPath], text);
  scheduleDelete(wavPath);

  if (piperOutputFormat === "wav") {
    return `http://${host}:${port}/npc-audio/${wavName}`;
  }

  if (piperOutputFormat !== "mp3") {
    throw new Error(`PIPER_OUTPUT_FORMAT invalido: ${piperOutputFormat}`);
  }

  const mp3Name = wavName.replace(/\.wav$/, ".mp3");
  const mp3Path = path.join(npcAudioDir, mp3Name);
  await runProcess(ffmpegExecutable, ["-y", "-loglevel", "error", "-i", wavPath, "-codec:a", "libmp3lame", "-q:a", "4", mp3Path]);
  fs.promises.unlink(wavPath).catch(() => {});
  scheduleDelete(mp3Path);
  return `http://${host}:${port}/npc-audio/${mp3Name}`;
}

async function generateNpcAudioWithPiperHttp(text) {
  const response = await fetch(piperHttpUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify({
      text,
      length_scale: piperLengthScale,
      noise_scale: piperNoiseScale,
      noise_w_scale: piperNoiseWScale
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Piper HTTP ${response.status}: ${errorText.slice(0, 300)}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const wavName = `${Date.now()}-${crypto.randomUUID()}.wav`;
  const wavPath = path.join(npcAudioDir, wavName);
  await fs.promises.writeFile(wavPath, Buffer.from(arrayBuffer));
  scheduleDelete(wavPath);

  if (piperOutputFormat === "wav") {
    return `http://${host}:${port}/npc-audio/${wavName}`;
  }

  if (piperOutputFormat !== "mp3") {
    throw new Error(`PIPER_OUTPUT_FORMAT invalido: ${piperOutputFormat}`);
  }

  const mp3Name = wavName.replace(/\.wav$/, ".mp3");
  const mp3Path = path.join(npcAudioDir, mp3Name);
  await runProcess(ffmpegExecutable, ["-y", "-loglevel", "error", "-i", wavPath, "-codec:a", "libmp3lame", "-q:a", "4", mp3Path]);
  fs.promises.unlink(wavPath).catch(() => {});
  scheduleDelete(mp3Path);
  return `http://${host}:${port}/npc-audio/${mp3Name}`;
}

function serveFile(req, res, filePath, contentType) {
  fs.stat(filePath, (statError, stat) => {
    if (statError) {
      sendText(res, 404, "Not found");
      return;
    }

    res.writeHead(200, {
      "content-type": contentType,
      "content-length": stat.size,
      "cache-control": "no-store",
      "access-control-allow-origin": "*"
    });
    if (req.method === "HEAD") {
      res.end();
      return;
    }

    fs.createReadStream(filePath).pipe(res);
  });
}

async function handleNpc(req, res) {
  try {
    const message = await readBody(req);
    if (!message) {
      sendText(res, 400, "Mensagem vazia|");
      return;
    }

    const answer = await generateNpcText(message);
    const audioUrl = await generateNpcAudio(answer);
    sendText(res, 200, `${answer}|${audioUrl}`);
  } catch (error) {
    console.error(error);
    sendText(res, 500, `NPC indisponivel: ${sanitizeForPawn(error.message)}|`);
  }
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${host}:${port}`);

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/intro.mp3") {
    serveFile(req, res, introPath, "audio/mpeg");
    return;
  }

  if (req.method === "POST" && url.pathname === "/npc") {
    handleNpc(req, res);
    return;
  }

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname.startsWith("/npc-audio/")) {
    const fileName = path.basename(url.pathname);
    serveFile(req, res, path.join(npcAudioDir, fileName), getAudioContentType(fileName));
    return;
  }

  sendText(res, 404, "Not found");
});

server.listen(port, host, () => {
  console.log(`Audio/NPC server listening on http://${host}:${port}`);
  console.log(`Intro music: http://${host}:${port}/intro.mp3`);
  console.log(`NPC endpoint: http://${host}:${port}/npc`);
  console.log(`LLM provider: ${llmProvider}`);
  if (llmProvider === "ollama") {
    console.log(`Ollama: ${ollamaBaseUrl} (${ollamaModel})`);
  }
  console.log(`TTS provider: ${ttsProvider}`);
  if (ttsProvider === "piper") {
    console.log(`Piper mode: ${piperMode}`);
    console.log(`Piper model: ${piperModel} (${piperOutputFormat})`);
    if (piperMode === "http") {
      console.log(`Piper HTTP: ${piperHttpUrl}`);
    }
  }
});
