#!/usr/bin/env bash
#
# run.sh - uruchamia serwer MCP Wikipedia w tle, czeka az wstanie,
# a nastepnie odpala aplikacje (czat z Gemini) na pierwszym planie.
# Po zamknieciu aplikacji (Ctrl+C) automatycznie ubija serwer MCP.
#
# Uzycie:
#   chmod +x run.sh
#   ./run.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -d "venv" ]]; then
    echo "BLAD: brak venv. Uruchom najpierw ./setup.sh" >&2
    exit 1
fi

# shellcheck disable=SC1091
source venv/bin/activate

# --- uruchom serwer MCP w tle ---
echo "==> Uruchamiam serwer MCP Wikipedia w tle..."
python wikipedia_server.py > mcp_server.log 2>&1 &
MCP_PID=$!

# funkcja sprzatajaca - ubija serwer MCP przy wyjsciu
cleanup() {
    echo ""
    echo "==> Zatrzymuje serwer MCP (PID $MCP_PID)..."
    kill "$MCP_PID" 2>/dev/null || true
    wait "$MCP_PID" 2>/dev/null || true
    echo "==> Posprzatane."
}
trap cleanup EXIT INT TERM

# --- czekaj, az serwer zacznie nasluchiwac na porcie 8000 ---
echo "==> Czekam, az serwer MCP wstanie (port 8000)..."
for i in {1..30}; do
    if curl -s -o /dev/null "http://localhost:8000/mcp" 2>/dev/null; then
        echo "==> Serwer MCP odpowiada."
        break
    fi
    # sprawdz, czy proces serwera w ogole jeszcze zyje
    if ! kill -0 "$MCP_PID" 2>/dev/null; then
        echo "BLAD: serwer MCP padl podczas startu. Logi:" >&2
        cat mcp_server.log >&2
        exit 1
    fi
    sleep 1
done

# --- uruchom aplikacje na pierwszym planie ---
echo "==> Uruchamiam aplikacje (Ctrl+C konczy)."
echo ""
python app.py
