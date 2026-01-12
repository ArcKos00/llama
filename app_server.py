import json
from pathlib import Path
from fastapi import FastAPI, HTTPException, Form
from pydantic import BaseModel
import httpx

MAX_ATTEMPTS = 10

# ---------- load config ----------
config = json.loads(Path("config.json").read_text(encoding="utf-8"))

# URL llama-cpp-python server (запущеного окремо)
LLAMA_SERVER_URL = config.get("llama_server_url", "http://localhost:8000")

# ---------- helpers ----------
def build_prompt(cfg, input_text: str) -> str:
    return f"""
INSTRUCTION:
{cfg['instruction']}

TEMPLATE:
{cfg['template']}

OUTPUT SCHEMA:
{json.dumps(cfg['output_schema'], indent=2)}

INPUT TEXT:
{input_text}

OUTPUT (JSON only):
""".strip()


def build_retry_prompt(base_prompt: str, last_output: str, attempt: int) -> str:
    return f"""
{base_prompt}

PREVIOUS OUTPUT (invalid JSON):
{last_output}

ERROR:
The output above is NOT valid JSON.

STRICT RULES (ATTEMPT {attempt}/10):
- Return ONLY valid JSON
- No markdown, no comments, no explanations
- Must strictly follow OUTPUT SCHEMA
- Use null for missing fields
- Do NOT add extra fields

OUTPUT (JSON only):
""".strip()


def try_parse_json(text: str):
    try:
        return json.loads(text)
    except Exception:
        return None


def run_llm(prompt: str) -> str:
    """Надсилає запит на llama-cpp-python server через HTTP"""
    try:
        with httpx.Client(timeout=120.0) as client:
            response = client.post(
                f"{LLAMA_SERVER_URL}/v1/completions",
                json={
                    "prompt": prompt,
                    "max_tokens": config["model"]["max_tokens"],
                    "temperature": config["model"]["temperature"],
                    "top_p": config["model"]["top_p"],
                    "stop": ["```", "\n\n"]
                }
            )
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["text"].strip()
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=502,
            detail=f"Error communicating with LLM server: {str(e)}"
        )


# ---------- API ----------
app = FastAPI(title="LLM JSON Extractor")


class ExtractRequest(BaseModel):
    text: str


@app.post("/extract")
def extract(text: str = Form(...)):
    base_prompt = build_prompt(config["extraction"], text)

    last_output = ""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        prompt = (
            base_prompt
            if attempt == 1
            else build_retry_prompt(base_prompt, last_output, attempt)
        )

        output = run_llm(prompt)
        parsed = try_parse_json(output)

        if parsed is not None:
            return parsed

        last_output = output

    raise HTTPException(
        status_code=422,
        detail={
            "error": "Failed to obtain valid JSON",
            "last_output": last_output
        }
    )
