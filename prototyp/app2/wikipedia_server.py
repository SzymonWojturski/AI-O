import httpx
from mcp.server.fastmcp import FastMCP

mcp = FastMCP(
    name="My Server",
    instructions="""
You have access to MCP tools.

When answering factual questions about people, places, events, concepts, or other topics that may require verification, use the available tools to gather information before responding.

If a Wikipedia tool is available, use it as a primary source for general knowledge and background information. Prefer tool-based information over assumptions, and cite sources when appropriate.
"""
)

WIKI_API = "https://en.wikipedia.org/w/api.php"
WIKI_REST = "https://en.wikipedia.org/api/rest_v1"
HEADERS = {"User-Agent": "llm-obs-bot/1.0 (kontakt: maciek.malinowski.poczta@gmail.com)"}


@mcp.tool()
def search_wikipedia(query: str) -> list[str]:
    """Search Wikipedia and return a list of matching article titles."""
    try:
        params = {
            "action": "query", "list": "search",
            "srsearch": query, "format": "json", "srlimit": 5,
        }
        r = httpx.get(WIKI_API, params=params, headers=HEADERS, timeout=10)
        r.raise_for_status()
        hits = r.json()["query"]["search"]
        return [h["title"] for h in hits]
    except Exception as e:
        return [f"error: {e}"]


@mcp.tool()
def get_summary(title: str) -> str:
    """Get the plain-text summary of a Wikipedia article by its exact title."""
    try:
        url = f"{WIKI_REST}/page/summary/{title.replace(' ', '_')}"
        r = httpx.get(url, headers=HEADERS, timeout=10)
        r.raise_for_status()
        return r.json().get("extract", "No summary found.")
    except Exception as e:
        return f"error: {e}"


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
