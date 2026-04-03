# 🤖 Complete Tutorial: Install Ollama on Termux (Android)  
*Run local LLMs on your phone — no root, no PC required*

> ✅ **Tested on**: Android 10–14, ARM64 devices  
> ✅ **Method**: Official Termux package (`pkg install ollama`) — simplest & most stable  
> ⚠️ **Note**: CPU-only inference. Best for models ≤ 3B parameters (quantized). 7B models work but are slower.

---

## 📋 Prerequisites

| Requirement | Details |
|-------------|---------|
| **Device** | ARM64 Android phone/tablet (most devices since ~2016) |
| **RAM** | **4 GB min** for ≤2B models • **6–8 GB recommended** for 7B models like `dolphin-mistral` |
| **Storage** | 4–12 GB free (7B models require ~4–5 GB each) |
| **Termux** | Install from [F-Droid](https://f-droid.org/packages/com.termux/) or [GitHub](https://github.com/termux/termux-app) — *Play Store version is outdated* |
| **Internet** | Required for initial install & model downloads |

---

## 🔧 Step-by-Step Installation

### 1️⃣ Install & Update Termux
```bash
# Open Termux and run:
pkg update && pkg upgrade -y
```

### 2️⃣ Install Ollama (Official Termux Package)
```bash
pkg install ollama -y
```
> 🎉 That's it! Ollama is now installed. No proot, no compilation, no manual downloads.

### 3️⃣ Verify Installation
```bash
ollama --version
# Expected output: ollama version is 0.x.x
```

### 4️⃣ Start the Ollama Server
```bash
# Run in background to keep terminal free:
ollama serve &
```
> 💡 The `&` runs it in background. Keep this session open or use `nohup` (see [Persistence](#-keep-ollama-running-background) below).

---

## 📦 Downloading Models: Including `dolphin-mistral` & `llama3-uncensored`

### 🔹 Recommended Starter Models (Lightweight)
```bash
# Fast & efficient for mobile:
ollama pull tinyllama:1.1b           # ~600MB • Fast Q&A
ollama pull qwen2.5:1.5b            # ~1GB • Great multilingual support
```

### 🔹 dolphin-mistral (Uncensored, Coding-Focused)
The Dolphin model by Eric Hartford, based on Mistral 0.2, is uncensored and excels at coding tasks [[1]].

```bash
# Download the official 7B version (quantized):
ollama pull dolphin-mistral:7b-v2.8-q4_K_M

# Or use the default tag (same model):
ollama pull dolphin-mistral
```

| Property | Value |
|----------|-------|
| **Size** | ~4.1 GB (Q4 quantized) |
| **Context** | 32K tokens |
| **Best for** | Code generation, technical tasks, unrestricted conversations |
| **RAM needed** | 6–8 GB recommended |
| **Speed on mobile** | ~0.5–2 tokens/sec (CPU-only) |

> ⚠️ **Warning**: This is a 7B parameter model. On CPU-only Android devices, expect slower responses. Use `--num-predict 100` to limit output length for faster replies.

### 🔹 llama3-uncensored Variants
There is no single official `llama3-uncensored` model, but several community versions exist. For mobile, we recommend the **3B variant** for better performance:

```bash
# ✅ Best for mobile: 3B uncensored (faster, lower RAM)
ollama pull artifish/llama3.2-uncensored:3b

# 🔥 Full 8B version (more capable but slower):
ollama pull mannix/llama3-uncensored:8b-q4_K_M

# 🌍 Multilingual uncensored alternative:
ollama pull CognitiveComputations/dolphin-llama3.1:8b-q4_K_M
```

| Model | Size | RAM | Speed | Best Use |
|-------|------|-----|-------|----------|
| `artifish/llama3.2-uncensored:3b` | ~2.2 GB | 4–5 GB | 2–4 tok/s | Balanced performance + uncensored |
| `mannix/llama3-uncensored:8b-q4_K_M` | ~4.8 GB | 7–8 GB | 0.5–1.5 tok/s | Maximum capability (slow) |
| `dolphin-llama3.1:8b-q4_K_M` | ~4.9 GB | 7–8 GB | 0.5–1.5 tok/s | Multilingual + coding + uncensored |

> 🔍 **What does "uncensored" mean?** These models have reduced refusal mechanisms and may generate content that official models would decline. Use responsibly and ethically.

---

## 💬 How to Interact with Your Model

### ✅ Method 1: Terminal Chat (Simplest)
```bash
# For dolphin-mistral:
ollama run dolphin-mistral

# For llama3-uncensored (3B version recommended):
ollama run artifish/llama3.2-uncensored:3b
```

#### 🎛️ Useful Chat Commands:
| Command | Action |
|---------|--------|
| `/bye` or `Ctrl+D` | Exit chat |
| `/reset` | Clear conversation history |
| `/set parameter temperature 0.7` | Adjust creativity (0.0–1.0) |
| `/set parameter num_predict 150` | Limit response tokens |
| `/show info` | Display model details |

> 💡 **Pro Tip for 7B models**: Add flags to improve mobile performance:
> ```bash
> ollama run dolphin-mistral --num-predict 100 --temperature 0.3
> ```

### ✅ Method 2: API Requests (For Developers)
```bash
# Generate with dolphin-mistral:
curl http://localhost:11434/api/generate -d '{
  "model": "dolphin-mistral",
  "prompt": "Write a Python function to reverse a string",
  "stream": false,
  "options": {"num_predict": 200}
}'

# Chat with llama3-uncensored (3B):
curl http://localhost:11434/api/chat -d '{
  "model": "artifish/llama3.2-uncensored:3b",
  "messages": [{"role": "user", "content": "Explain blockchain simply"}],
  "stream": false
}' | jq -r '.message.content'
```

### ✅ Method 3: Connect a Web UI
Use [ChatterUI](https://f-droid.org/packages/com.machiav3lli.fdroid.chatterui/) (Android, F-Droid) and set:
- **API URL**: `http://127.0.0.1:11434`
- **Model**: `dolphin-mistral` or `artifish/llama3.2-uncensored:3b`

---

## 🔋 Keep Ollama Running in Background

```bash
# Prevent Android from killing the process:
termux-wake-lock

# Start server persistently:
nohup ollama serve > ~/ollama.log 2>&1 &

# Verify it's running:
curl http://localhost:11434/api/version
```

> 🔋 **Battery note**: 7B models consume ~15–25% battery/hour during active inference. Use `termux-wake-unlock` when done.

---

## 🚀 Performance Optimization for Large Models

| Tip | Command/Action |
|-----|---------------|
| ✅ Use Q4 quantization | Always pull `:q4_K_M` tags when available |
| ✅ Limit output length | Add `--num-predict 100` to commands |
| ✅ Reduce temperature | `--temperature 0.3` for faster, more deterministic replies |
| ✅ Close background apps | Free RAM before loading 7B models |
| ✅ Prefer 3B uncensored | `artifish/llama3.2-uncensored:3b` offers best mobile balance |
| ✅ Monitor resources | `pkg install htop && htop` to watch RAM/CPU |

#### 📊 Expected Performance (ARM64 CPU, no GPU):
| Model | Params | Download Size | RAM Use | Speed | Use Case |
|-------|--------|--------------|---------|-------|----------|
| `tinyllama:1.1b` | 1.1B | ~600 MB | ~1.2 GB | 3–8 tok/s | Quick Q&A |
| `qwen2.5:1.5b` | 1.5B | ~1 GB | ~1.8 GB | 2–5 tok/s | Multilingual chat |
| `artifish/llama3.2-uncensored:3b` | 3B | ~2.2 GB | ~3.5 GB | 1.5–3 tok/s | Uncensored balance |
| `dolphin-mistral:7b` | 7B | ~4.1 GB | ~6–7 GB | 0.5–2 tok/s | Coding, advanced tasks |

---

## 🛠️ Troubleshooting Large Models

| Issue | Solution |
|-------|----------|
| "Killed" or crash on load | Out of memory. Use a smaller model or close apps. Try `artifish/llama3.2-uncensored:3b` instead of 8B. |
| Very slow responses (>20 sec/token) | CPU limitation. Add `--num-predict 50` or switch to a ≤3B model. |
| Model download fails | Check storage space. 7B models need ~5 GB free. Use `df -h ~` to verify. |
| "Context length exceeded" | 7B models support 32K context, but mobile RAM limits practical use. Keep conversations concise. |
| Uncensored model gives unexpected output | These models have fewer guardrails. Refine prompts or adjust `temperature`/`top_p` parameters. |

#### 🔍 Diagnostic Commands:
```bash
# List models and sizes:
ollama list

# Check active processes:
ollama ps

# Monitor system resources:
free -h && df -h ~
```

---

## 🔄 Updating Models

```bash
# Update Ollama package:
pkg update && pkg upgrade ollama -y

# Re-pull latest model version:
ollama pull dolphin-mistral
ollama pull artifish/llama3.2-uncensored:3b

# Remove unused models to free space:
ollama rm tinyllama  # Example
```

---

## ⚖️ Ethical Use of Uncensored Models

Models like `dolphin-mistral` and `llama3-uncensored` have reduced content filters [[11]]. Please:

✅ **Do**:
- Use for research, education, or creative projects
- Test prompt engineering and model behavior
- Run locally for privacy-sensitive tasks

❌ **Avoid**:
- Generating harmful, illegal, or non-consensual content
- Deploying without human oversight in production
- Assuming "uncensored" means "unaccountable"

> 🌐 **Remember**: You are responsible for how you use these tools. Local execution doesn't remove ethical obligations.

---

## ✅ Quick Start Checklist

- [ ] Termux installed from F-Droid/GitHub  
- [ ] `pkg install ollama -y` completed  
- [ ] `ollama serve &` is running  
- [ ] Model downloaded:  
  - Lightweight: `ollama pull qwen2.5:1.5b`  
  - Uncensored 3B: `ollama pull artifish/llama3.2-uncensored:3b`  
  - Uncensored 7B: `ollama pull dolphin-mistral`  
- [ ] Test chat: `ollama run artifish/llama3.2-uncensored:3b "Hello!"`  
- [ ] (Optional) `termux-wake-lock` enabled for background use  

---

> 🌟 **You're all set!** You now have powerful, private AI models — including uncensored options — running entirely on your Android device.  
> 🔁 **Next steps**: Experiment with prompts, benchmark performance, or build a simple app using the API.

*Last updated: April 2026 | Ollama v0.5+ | Termux v0.118+*

📥 **Need help?** Report issues on [Termux GitHub](https://github.com/termux/termux-packages) or [Ollama GitHub](https://github.com/ollama/ollama).
