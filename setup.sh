#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Katalog roboczy: $SCRIPT_DIR"

for f in app.py wikipedia_server.py; do
    if [[ ! -f "$f" ]]; then
        echo "BLAD: brak pliku '$f' w katalogu $SCRIPT_DIR" >&2
        echo "Umiesc app.py i wikipedia_server.py obok setup.sh i uruchom ponownie." >&2
        exit 1
    fi
done
echo "==> Pliki app.py i wikipedia_server.py znalezione."

echo "==> Aktualizacja pakietow i instalacja Pythona + venv..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip

echo "==> Wersja Pythona:"
python3 --version

if [[ ! -d "venv" ]]; then
    echo "==> Tworze wirtualne srodowisko venv..."
    python3 -m venv venv
else
    echo "==> venv juz istnieje - pomijam tworzenie."
fi

source venv/bin/activate

echo "==> Instaluje biblioteki Pythona..."
pip install --upgrade pip
pip install \
    google-genai \
    "mcp[cli]" \
    httpx \
    python-dotenv \
    openlit \
    opentelemetry-distro \
    opentelemetry-exporter-otlp

opentelemetry-bootstrap --action=install

if [[ -f ".env" ]] && grep -q "GEMINI_API_KEY=" .env; then
    echo "==> Plik .env z kluczem juz istnieje - pomijam."
else
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        echo "==> Zapisuje GEMINI_API_KEY ze zmiennej srodowiskowej do .env"
        echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > .env
    else
        echo ""
        echo "Nie znaleziono GEMINI_API_KEY w srodowisku."
        read -rp "Wklej swoj klucz Gemini API (GEMINI_API_KEY): " USER_KEY
        if [[ -z "$USER_KEY" ]]; then
            echo "BLAD: nie podano klucza. Przerywam." >&2
            exit 1
        fi
        echo "GEMINI_API_KEY=${USER_KEY}" > .env
        echo "==> Klucz zapisany do .env"
    fi
    chmod 600 .env
fi

if [[ -f ".env" ]] && grep -q "OTLP_HEADERS=" .env; then
    echo "==> OTLP_HEADERS juz istnieje w .env - pomijam."
else
    if [[ -n "${OTLP_HEADERS:-}" ]]; then
        echo "==> Zapisuje OTLP_HEADERS ze zmiennej srodowiskowej do .env"
        echo "OTLP_HEADERS=\"${OTLP_HEADERS}\"" >> .env
    else
        echo ""
        echo "Wklej wartosc OTLP_HEADERS z Grafany (cala linia 'Authorization=Basic ...')."
        echo "Mozesz zostawic puste, jesli na razie uzywasz lokalnego OpenLIT."
        read -rp "OTLP_HEADERS: " USER_HEADERS
        if [[ -n "$USER_HEADERS" ]]; then
            echo "OTLP_HEADERS=\"${USER_HEADERS}\"" >> .env
            echo "==> OTLP_HEADERS zapisany do .env"
        else
            echo "==> Pominieto OTLP_HEADERS (tryb lokalny)."
        fi
    fi
fi
