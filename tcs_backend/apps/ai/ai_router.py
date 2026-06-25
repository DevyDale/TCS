# apps/ai/ai_router.py
#
# Phase 1 — the shared AI router. Model-agnostic spine that every AI feature
# routes through. Each task type has an ORDERED lane of providers; the router
# tries them in order and fails over to the next on error. Providers without a
# configured API key are skipped automatically, so adding a key to the prod
# env is all it takes to light up a lane — no code change.
#
# Design principle: the right model per job behind one router with failover —
# NOT every provider wired into every feature.
#
# No new dependencies — uses urllib, matching the existing ai/views.py.

import json
import logging
import os
import urllib.error
import urllib.request

logger = logging.getLogger(__name__)

# ── Provider registry ────────────────────────────────────────
# kind: "openai" → OpenAI-compatible /chat/completions (Groq, Cerebras,
#                  SambaNova, DeepSeek/OpenRouter, Mistral, …)
#       "gemini" → Google Generative Language API (different request shape)
# env  → the environment variable holding that provider's API key. When it's
#        empty the provider is treated as not-configured and skipped.
PROVIDERS = {
    "groq": {
        "env": "GROQ_API_KEY",
        "base": "https://api.groq.com/openai/v1",
        "model": "llama-3.3-70b-versatile",
        "kind": "openai",
    },
    "cerebras": {
        "env": "CEREBRAS_API_KEY",
        "base": "https://api.cerebras.ai/v1",
        "model": "llama-3.3-70b",
        "kind": "openai",
    },
    "sambanova": {
        "env": "SAMBANOVA_API_KEY",
        "base": "https://api.sambanova.ai/v1",
        "model": "Meta-Llama-3.3-70B-Instruct",
        "kind": "openai",
    },
    "deepseek": {
        "env": "OPENROUTER_API_KEY",
        "base": "https://openrouter.ai/api/v1",
        "model": "deepseek/deepseek-chat",
        "kind": "openai",
    },
    "mistral": {
        "env": "MISTRAL_API_KEY",
        "base": "https://api.mistral.ai/v1",
        "model": "mistral-large-latest",
        "kind": "openai",
    },
    # Already configured on prod today — keeps every lane working before any
    # of the speed providers above have keys.
    "gemini": {
        "env": "GEMINI_API_KEY",
        "base": "https://generativelanguage.googleapis.com/v1beta/models",
        "model": "gemini-2.5-flash",
        "kind": "gemini",
    },
}

# ── Task → ordered provider lanes ────────────────────────────
# Each feature asks for a task type; the router walks the lane in order.
# gemini sits at the tail of every lane as the always-available backstop
# (its key is already set), so a lane never goes fully dark.
TASK_LANES = {
    "chat":      ["groq", "cerebras", "sambanova", "gemini"],
    "quiz":      ["cerebras", "groq", "deepseek", "gemini"],
    "rag":       ["groq", "cerebras", "gemini"],
    "code":      ["mistral", "groq", "gemini"],
    "reasoning": ["deepseek", "groq", "gemini"],
}

DEFAULT_TASK = "chat"


# ── Configuration helpers ────────────────────────────────────
def key_for(name):
    p = PROVIDERS.get(name)
    return os.environ.get(p["env"], "").strip() if p else ""


def is_configured(name):
    return bool(key_for(name))


def lane(task):
    return TASK_LANES.get(task, TASK_LANES[DEFAULT_TASK])


def available(task=None):
    """Configured providers for a task (or all), in lane order."""
    names = lane(task) if task else list(PROVIDERS)
    seen, out = set(), []
    for n in names:
        if n not in seen and is_configured(n):
            out.append(n); seen.add(n)
    return out


def status():
    """Diagnostic snapshot — which providers/lanes are live. Never leaks keys."""
    return {
        "providers": {
            n: {"configured": is_configured(n), "env": p["env"],
                "model": p["model"], "kind": p["kind"]}
            for n, p in PROVIDERS.items()
        },
        "lanes": {
            task: {"order": names, "active": available(task)}
            for task, names in TASK_LANES.items()
        },
    }


# ── Low-level callers ────────────────────────────────────────
def _req(url, body, headers):
    return urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json", **headers}, method="POST")


def _openai_body(p, messages, max_tokens, temperature, stream):
    return {
        "model": p["model"], "messages": messages,
        "max_tokens": max_tokens, "temperature": temperature, "stream": stream,
    }


def _openai_complete(p, key, messages, max_tokens, temperature):
    req = _req(f"{p['base']}/chat/completions",
               _openai_body(p, messages, max_tokens, temperature, False),
               {"Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=40) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data["choices"][0]["message"]["content"]


def _openai_stream(p, key, messages, max_tokens, temperature):
    req = _req(f"{p['base']}/chat/completions",
               _openai_body(p, messages, max_tokens, temperature, True),
               {"Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=40) as resp:
        for raw in resp:
            line = raw.decode("utf-8").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                return
            try:
                tok = json.loads(data)["choices"][0]["delta"].get("content", "")
                if tok:
                    yield tok
            except (json.JSONDecodeError, KeyError, IndexError):
                continue


def _to_gemini(messages):
    system, contents = "", []
    for m in messages:
        role, text = m.get("role"), m.get("content", "")
        if role == "system":
            system += text + "\n"
            continue
        contents.append({"role": "user" if role == "user" else "model",
                         "parts": [{"text": text}]})
    return system.strip(), contents


def _gemini_body(p, messages, max_tokens, temperature):
    system, contents = _to_gemini(messages)
    body = {
        "contents": contents,
        "generationConfig": {"temperature": temperature,
                             "maxOutputTokens": max_tokens, "topP": 0.95},
    }
    if system:
        body["system_instruction"] = {"parts": [{"text": system}]}
    return body


def _gemini_complete(p, key, messages, max_tokens, temperature):
    req = _req(f"{p['base']}/{p['model']}:generateContent",
               _gemini_body(p, messages, max_tokens, temperature),
               {"x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=40) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data["candidates"][0]["content"]["parts"][0]["text"]


def _gemini_stream(p, key, messages, max_tokens, temperature):
    req = _req(f"{p['base']}/{p['model']}:streamGenerateContent?alt=sse",
               _gemini_body(p, messages, max_tokens, temperature),
               {"x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=40) as resp:
        for raw in resp:
            line = raw.decode("utf-8").strip()
            if not line.startswith("data:"):
                continue
            try:
                parts = json.loads(line[5:].strip())["candidates"][0]["content"]["parts"]
                tok = parts[0].get("text", "")
                if tok:
                    yield tok
            except (json.JSONDecodeError, KeyError, IndexError):
                continue


# ── Public API ───────────────────────────────────────────────
def complete(task, messages, max_tokens=1024, temperature=0.7):
    """Non-streaming completion with failover.

    Returns {"text", "provider", "error"}. Walks the task lane, returns the
    first provider that yields text; records the last error if all fail.
    """
    last_err = None
    for name in available(task):
        p, key = PROVIDERS[name], key_for(name)
        try:
            fn = _gemini_complete if p["kind"] == "gemini" else _openai_complete
            text = fn(p, key, messages, max_tokens, temperature)
            if text:
                return {"text": text, "provider": name, "error": None}
        except urllib.error.HTTPError as e:
            last_err = f"{name}: HTTP {e.code}"
            logger.warning("ai lane '%s' provider '%s' failed: %s", task, name, last_err)
        except Exception as e:  # noqa: BLE001 — fail over on anything
            last_err = f"{name}: {e}"
            logger.warning("ai lane '%s' provider '%s' failed: %s", task, name, e)
    return {"text": "", "provider": None,
            "error": last_err or "No AI providers configured for this task."}


def stream(task, messages, max_tokens=1024, temperature=0.7):
    """Streaming completion with open-time failover.

    Yields token strings. Failover happens while opening the connection / on
    the first token; once a provider starts emitting, we stay with it. If every
    provider fails, yields nothing — callers should treat empty as an error.
    """
    last_err = None
    for name in available(task):
        p, key = PROVIDERS[name], key_for(name)
        fn = _gemini_stream if p["kind"] == "gemini" else _openai_stream
        try:
            gen = fn(p, key, messages, max_tokens, temperature)
            first = next(gen)        # open + first token; raises → fail over
        except StopIteration:
            return                   # provider succeeded but produced nothing
        except Exception as e:       # noqa: BLE001
            last_err = f"{name}: {e}"
            logger.warning("ai stream lane '%s' provider '%s' failed: %s", task, name, e)
            continue
        yield first
        yield from gen
        return
    logger.error("ai stream lane '%s': all providers failed (%s)", task, last_err)
