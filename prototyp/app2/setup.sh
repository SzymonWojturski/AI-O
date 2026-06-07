#!/usr/bin/env bash
#
# setup.sh - przygotowuje czystą maszyne Ubuntu (EC2) do uruchomienia
# aplikacji Gemini + serwer MCP Wikipedia.
#
# Zaloznia:
#   - w tym samym katalogu leza pliki: app.py oraz wikipedia_server.py
#   - mamy dostep do internetu (Gemini API + Wikipedia)
#
# Uzycie:
#   chmod +x setup.sh
#   ./setup.sh
#
# Klucz Gemini mozna podac na 2 sposoby:
#   1) wyeksportowac przed uruchomieniem:  export GEMINI_API_KEY=AIza...
#   2) skrypt zapyta o niego interaktywnie, jesli nie znajdzie w srodowisku
#      ani w istniejacym pliku .env

set -euo pipefail

# --- katalog, w ktorym lezy ten skrypt (i pliki aplikacji) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Katalog roboczy: $SCRIPT_DIR"

# --- sprawdzenie, ze pliki aplikacji sa na miejscu ---
for f in app.py wikipedia_server.py; do
    if [[ ! -f "$f" ]]; then
        echo "BLAD: brak pliku '$f' w katalogu $SCRIPT_DIR" >&2
        echo "Umiesc app.py i wikipedia_server.py obok setup.sh i uruchom ponownie." >&2
        exit 1
    fi
done
echo "==> Pliki app.py i wikipedia_server.py znalezione."

# --- instalacja zaleznosci systemowych ---
echo "==> Aktualizacja pakietow i instalacja Pythona + venv..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip

echo "==> Wersja Pythona:"
python3 --version

# --- utworzenie wirtualnego srodowiska ---
if [[ ! -d "venv" ]]; then
    echo "==> Tworze wirtualne srodowisko venv..."
    python3 -m venv venv
else
    echo "==> venv juz istnieje - pomijam tworzenie."
fi

# shellcheck disable=SC1091
source venv/bin/activate

# --- instalacja bibliotek Pythona ---
echo "==> Instaluje biblioteki Pythona..."
pip install --upgrade pip
pip install \
    google-genai \
    "mcp[cli]" \
    httpx \
    python-dotenv

# --- przygotowanie pliku .env z kluczem Gemini ---
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

echo ""
echo "============================================================"
echo " Gotowe. Srodowisko przygotowane."
echo "============================================================"
echo ""
echo "Aby uruchomic aplikacje, potrzebujesz DWOCH terminali:"
echo ""
echo "  Terminal 1 (serwer MCP Wikipedia):"
echo "    cd $SCRIPT_DIR && source venv/bin/activate"
echo "    python wikipedia_server.py"
echo ""
echo "  Terminal 2 (aplikacja - czat z Gemini):"
echo "    cd $SCRIPT_DIR && source venv/bin/activate"
echo "    python app.py"
echo ""
echo "Mozesz tez uzyc skryptu pomocniczego: ./run.sh"
echo "============================================================"
