# AI Companion

A talking, lip-syncing AI character for the web. A Flask backend serves an animated
frontend; the "brain" is a Google **Agent Development Kit (ADK)** agent backed by
Gemini, with Google Search grounding and retry handling.

Built from the Google Codelab
[A Beginner's Workshop for Antigravity CLI & ADK](https://codelabs.developers.google.com/companion-adk-beginner/instructions).

## How it works

```
browser  --POST /chat-->  Flask (app.py)  -->  ADK InMemoryRunner  -->  Gemini
   ^                                                                     |
   |  text + speechSynthesis + mouth open/closed frames                  |
   +---------------------------------------------------------------------+
```

- `app.py` — Flask routes: `/` (UI), `/chat` (agent call), `/healthz`.
- `character.py` — the agent: persona, model, `google_search` tool, retry policy.
- `static/` — `app.js` drives the typewriter effect and mouth animation, `style.css`
  the look, `images/` the two lip-sync frames.
- `templates/index.html` — page shell.

Delete or rename `character.py` and the app runs as a puppet that echoes your
message. That is the codelab's starting point and a handy way to test the frontend.

## Run it locally

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env          # then paste your key from https://aistudio.google.com/
set -a && source .env && set +a

python app.py                 # http://localhost:5000
```

Check `curl localhost:5000/healthz` — `"brain": "agent"` means the model is wired up.

## Deploy it to Cloud Run

The deploy script builds the container from source with Cloud Build, stores the API
key in Secret Manager, and deploys the service. It needs `gcloud` authenticated
against a project with billing enabled.

```bash
export GEMINI_API_KEY=your-key      # or put it in .env
PROJECT_ID=your-project-id ./deploy-cloud-run.sh
```

When it finishes you get a public URL. `curl <url>/healthz` should return `"ok"`.

Two things worth knowing about this deployment:

- The script passes the key with `--set-secrets`, so it never lands in your shell
  history, the image, or the Cloud Run environment as plaintext.
- ADK sessions live in memory. The service runs one worker so sessions stay
  consistent, which also means a session is lost when an instance recycles. See
  "Make sessions durable" below to fix that.

## Where to take it next

Roughly in order of effort. The first three are small and give the biggest payoff.

**Change the character.** Everything about the personality lives in the `INSTRUCTION`
string in `character.py`. Edit it and restart; no other code needs to change. Give it
a different name, tone, area of expertise, and a few example exchanges. The model
copies the style of your examples more reliably than it follows abstract adjectives.

**Regenerate the avatar.** Replace the two files in `static/images/`. They must stay
600x600 and share identical framing so the mouth swap does not jitter. Ask Antigravity
CLI to generate a matching open/closed pair, or draw them yourself.

**Add more tools.** `google_search` is one entry in the `tools=[...]` list. A Python
function with a docstring and type hints becomes a tool the agent can call. Useful
ones: current time, weather, a to-do list, a database lookup.

```python
def get_local_time(timezone: str) -> str:
    """Return the current time for an IANA timezone like 'Asia/Kolkata'."""
    ...

root_agent = LlmAgent(..., tools=[google_search, get_local_time])
```

**Make sessions durable.** Swap `InMemoryRunner` in `app.py` for a runner with a
database-backed session service (SQLite locally, Cloud SQL or Firestore in
production). Then conversations survive restarts and you can run more than one
worker.

**Remember things between sessions.** ADK has a memory service for long-term recall
so the companion recognizes returning users. This is the natural next step after
durable sessions.

**Give it a voice and a face that moves properly.** Today the mouth toggles on a
150 ms timer while the browser speaks. Real lip sync means driving the frames from
audio amplitude, or generating a talking-head video. Swap `speechSynthesis` for a
server-side TTS if you want a consistent voice across browsers.

**Add streaming responses.** `/chat` waits for the full reply before returning. ADK's
`run_async` already yields events as they arrive, so you can stream them to the
browser with server-sent events and start speaking sooner.

**Guard the endpoint.** Cloud Run is deployed with `--allow-unauthenticated`, so
anyone with the URL can spend your Gemini quota. Add auth (Identity Platform,
Firebase Auth, or IAP) and rate limiting before sharing the link widely.

**Put it on CI.** A GitHub Actions workflow that runs a lint and a smoke test on
push, then deploys on merge to `main`, removes the manual deploy step.

## Layout

```
app.py                 Flask server
character.py           ADK agent: persona, tools, retries
requirements.txt       runtime dependencies
Dockerfile             container image for Cloud Run
deploy-cloud-run.sh    one-command deploy
.env.example           environment template
templates/index.html   page shell
static/app.js          chat, typewriter, lip sync
static/style.css       styling
static/images/         mouth-open / mouth-closed frames
scripts/               ADK skill file for the Antigravity CLI
```

## Credits

Workshop by Christina Lin. The starter app is
[weimeilin79/companion-python](https://github.com/weimeilin79/companion-python).
