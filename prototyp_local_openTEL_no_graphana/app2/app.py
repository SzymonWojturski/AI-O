import os
import asyncio
from dotenv import load_dotenv
from google import genai
from google.genai import types
from mcp.client.streamable_http import streamablehttp_client
from mcp import ClientSession
import openlit

load_dotenv()

openlit.init(
    otlp_endpoint="http://127.0.0.1:4318",
    application_name="llm-wikipedia-bot",
    environment="development",
)

client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
MODEL = "gemini-2.5-flash"

def mcp_tools_to_gemini(mcp_tools):
    """Konwertuje deklaracje narzędzi MCP na format Gemini."""
    decls = []
    for t in mcp_tools.tools:
        schema = t.inputSchema or {"type": "object", "properties": {}}
        decls.append(types.FunctionDeclaration(
            name=t.name,
            description=t.description or "",
            parameters_json_schema=schema,
        ))
    return types.Tool(function_declarations=decls)


async def ask(session, prompt: str):
    tools_list = await session.list_tools()
    gemini_tool = mcp_tools_to_gemini(tools_list)

    contents = [types.Content(role="user", parts=[types.Part(text=prompt)])]

    # pętla: model myśli -> chce narzędzie -> wykonujemy -> oddajemy wynik
    for _ in range(5):  # limit kroków, by nie zapętlić
        resp = await client.aio.models.generate_content(
            model=MODEL,
            contents=contents,
            config=types.GenerateContentConfig(
                temperature=0,
                tools=[gemini_tool],
            ),
        )

        candidate = resp.candidates[0]
        parts = candidate.content.parts or []
        fcalls = [p.function_call for p in parts if p.function_call]

        if not fcalls:
            return resp.text

        # dopisz odpowiedź modelu (z żądaniami narzędzi) do historii
        contents.append(candidate.content)

        # wykonaj każde żądane narzędzie przez sesję MCP
        for fc in fcalls:
            result = await session.call_tool(fc.name, dict(fc.args))
            output = result.content[0].text if result.content else ""
            contents.append(types.Content(
                role="user",
                parts=[types.Part.from_function_response(
                    name=fc.name,
                    response={"result": output},
                )],
            ))

    return "(przekroczono limit kroków narzędzi)"


async def main():
    async with streamablehttp_client("http://localhost:8000/mcp") as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("Pytaj o cokolwiek (Ctrl+C aby wyjść).\n")
            while True:
                try:
                    prompt = input("Ty: ")
                    if not prompt.strip():
                        continue
                    answer = await ask(session, prompt)
                    print(f"\nGemini: {answer}\n")
                except (KeyboardInterrupt, EOFError):
                    print("\nPa!")
                    break


if __name__ == "__main__":
    asyncio.run(main())
