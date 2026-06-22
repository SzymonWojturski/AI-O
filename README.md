## 1. Introduction

In this project, we design an AI system with full observability for monitoring both the behavior of a Large Language Model (LLM) and its interactions with external tools.

The system is hosted on AWS and uses OpenLIT as the core observability platform. Through OpenLIT, we monitor conversations handled by the Gemini LLM. The model is extended with tool-calling capabilities via an MCP (Model Context Protocol) server, which enables it to retrieve additional information from external sources—in this case, Wikipedia.

To ensure complete visibility into the system, we integrate Grafana Cloud for monitoring and visualization. This allows us to track not only the LLM's internal performance (such as latency and token usage), but also its interactions with the MCP server and the external Wikipedia API.

The goal of this setup is to provide end-to-end observability of an AI application, making it easier to debug, optimize, and understand how the model behaves in real-world scenarios.

---

## 2. Theoretical Background / Technology Stack

The proposed solution combines modern LLM orchestration with observability practices typically used in distributed systems.

**Large Language Model (LLM):**  
The system uses Gemini as the primary LLM responsible for generating responses. The model processes user input and, when needed, retrieves external data via tools.

**Model Context Protocol (MCP) Server:**  
The MCP server acts as an intermediary layer between the LLM and external data sources. It exposes two tools to the LLM—`search_wikipedia` (finds matching article titles) and `get_summary` (returns a plain-text article summary). This introduces additional complexity and requires visibility into tool calls, latency, and response quality.

**OpenLIT (SDK-based):**  
OpenLIT is used for LLM observability. It is integrated directly into the application as a Python SDK (`openlit.init()`) and captures:
- Prompts and responses
- Token usage and estimated cost
- Latency metrics
- Tool invocation traces (via MCP)

The OpenLIT SDK exports telemetry directly to Grafana Cloud over OTLP, so no self-hosted collector or observability server is required.

**Observability Standard:**
- OpenTelemetry: OpenLIT is built on OpenTelemetry. Traces, metrics, and logs are produced in OTLP format and sent straight to Grafana Cloud's managed OTLP endpoint.

**Visualization Layer:**
- Grafana Cloud: Provides dashboards, exploration, and alerting. It visualizes:
  - LLM performance metrics
  - MCP tool usage and latency
  - End-to-end request traces
  - System health indicators

This stack enables full observability across the AI pipeline—from user query to external data retrieval and final response generation.

---

## 3. Case Study Concept Description (Application / Observability / Visualization)

**Application Layer:**  
The application consists of a conversational (CLI) interface powered by Gemini. When a user submits a query:
1. The LLM processes the request.
2. If external knowledge is needed, it invokes the MCP server.
3. The MCP server queries the Wikipedia API and returns relevant data.
4. The LLM incorporates this data into the final response.

**Observability Layer:**  
Observability is implemented using the OpenLIT SDK (built on OpenTelemetry):
- Every interaction (prompt -> response) is captured.
- LLM calls are traced, including token usage and cost.
- MCP tool calls are wrapped in custom spans, so each `search_wikipedia` and `get_summary` invocation appears as its own timed child span within the parent trace.
- Metrics such as latency and token usage are collected.

Key observability goals:
- Understand LLM behavior and performance
- Monitor tool usage (Wikipedia queries via MCP)
- Detect anomalies (e.g., slow responses, failed tool calls)
- Analyze cost drivers (token consumption)

**Visualization Layer:**  
Grafana Cloud aggregates and visualizes all collected data:
- Trace exploration shows the full lifecycle of a request (LLM -> MCP -> Wikipedia -> LLM)
- Metrics views show token usage, cost, and latency over time

This enables both operational monitoring and deeper analysis of LLM behavior.

---

## 4. Case Study High-Level Architecture

The architecture follows a simple pipeline: User -> LLM -> (MCP -> Wikipedia) -> Grafana Cloud.

**1. Interaction Layer (LLM):**
- User sends a query
- Gemini processes the input
- Optional: invokes MCP server for Wikipedia data

**2. Integration Layer (MCP Server):**
- Receives tool requests from the LLM
- Queries the Wikipedia API
- Returns structured data to the LLM

**3. Observability Layer (in-app):**
- The OpenLIT SDK, embedded in the application, captures:
  - Prompts/responses
  - LLM token usage, cost, and latency
  - MCP tool calls as separate timed spans
- Telemetry is exported directly to Grafana Cloud over OTLP

**4. Visualization Layer:**
- Grafana Cloud receives telemetry directly from the application
- Provides trace exploration and metrics views

**Data Flow Summary:**
1. User -> LLM (Gemini)  
2. LLM -> MCP Server (if external data needed)  
3. MCP -> Wikipedia -> MCP -> LLM  
4. OpenLIT SDK captures all steps  
5. Telemetry (traces, metrics) -> Grafana Cloud (OTLP)  
6. Grafana Cloud visualizes and monitors the system  

This architecture keeps all components on a single host and ships telemetry straight to a managed backend, removing the need for any self-hosted observability infrastructure.

## 5. Case study detailed architecture

This section describes the detailed technical architecture of the AI observability system.

## 5.1 Overview

The system runs on a single AWS EC2 instance. The application, the MCP server, and the OpenLIT instrumentation all run on this one host; telemetry is shipped directly to Grafana Cloud.

| Layer | Component | Role |
|---|---|---|
| Application | Gemini API (Google) | Primary LLM – generates responses |
| Integration | MCP Server (local process) | Tool broker – queries Wikipedia |
| Observability | OpenLIT SDK (in-app) | Captures LLM + MCP telemetry, exports to Grafana Cloud over OTLP |
| Visualisation | Grafana Cloud | Trace exploration, metrics, dashboards |

## 5.2 Application Layer – Gemini + MCP

The application layer is the entry point for user requests. The client application (a Python CLI script, `app.py`) sends a prompt to Gemini via the Google Gen AI SDK (`google-genai`). Gemini is configured with access to a custom tool set exposed by the MCP server.

When Gemini determines that additional context is required – for example, an encyclopedic fact or definition – it issues a structured tool call. The application forwards this call to the MCP server, which handles the external API interaction, and the result is returned to Gemini for incorporation into the final response.

Key design decisions:

- Gemini is accessed exclusively via API – no local model hosting is required.
- The MCP server (`wikipedia_server.py`) is built with the official MCP Python SDK (FastMCP) and runs over the Streamable HTTP transport as a local process on port 8000.
- Wikipedia queries use the public Wikimedia REST and `w/api.php` endpoints over plain HTTP, with a compliant `User-Agent` header (no API key or authentication required).

## 5.3 Observability Layer – OpenLIT (SDK) & OpenTelemetry

OpenLIT is integrated as a Python SDK inside the application. A single call to `openlit.init()` auto-instruments the Gemini SDK and configures the OTLP export to Grafana Cloud. It captures:

- Every prompt sent to Gemini and every response received.
- Token counts (input, output, reasoning tokens) and an automatically estimated cost per call.
- Latency of each LLM call, including time-to-first-token.
- The full multi-step reasoning chain (search -> get_summary -> answer), including which tool the model chose and with what arguments.

In addition to OpenLIT's automatic instrumentation, the application adds **manual OpenTelemetry spans** around each MCP tool call. Using a tracer obtained after `openlit.init()`, every `session.call_tool(...)` is wrapped in a span named `mcp.tool.<tool_name>`, with attributes for the tool name, arguments, and output length. This makes each Wikipedia tool invocation visible as its own timed child span inside the parent trace — so the latency of `search_wikipedia` and `get_summary` can be measured independently.

All telemetry is exported via OTLP directly to Grafana Cloud's managed OTLP gateway. There is no self-hosted collector, no ClickHouse, and no Prometheus instance.

## 5.4 Telemetry Captured

Per LLM call, the system records: input/output/reasoning token counts, estimated cost, time-to-first-token, model name, temperature, and the full conversation history (including tool calls and their results).

Per MCP tool call (custom spans): tool name, arguments, output length, and span duration (tool latency).

Per HTTP request to the Gemini API: the exact URL, HTTP status code, and latency.

## 5.5 Visualisation Layer – Grafana Cloud

Telemetry is explored in Grafana Cloud. The most useful views for this project are:

- **Drilldown -> Traces** – end-to-end trace view of a request: User -> Gemini -> MCP (`search_wikipedia` / `get_summary`) -> Gemini -> answer, with per-span timing.
- **Drilldown -> Metrics** – token usage, cost, and latency metrics over time.

Note: in the current Grafana Cloud UI, the readable views for this data are found under **Drilldown -> Traces** and **Drilldown -> Metrics**.

---

# 6. Environment Configuration Description

## 6.1 AWS Infrastructure

The system runs on a single EC2 instance.

| Instance | Type | OS | Services hosted |
|---|---|---|---|
| app-server | t3.small | Ubuntu | Python app + MCP server + OpenLIT SDK |

## 6.2 Application Environment Variables

These are stored in a `.env` file (loaded by `python-dotenv`) or exported in the shell.

| Variable | Example value | Description |
|---|---|---|
| `GEMINI_API_KEY` | `AIza...` | Google AI Studio API key |
| `OTLP_ENDPOINT` | `https://otlp-gateway-prod-eu-west-2.grafana.net/otlp` | Grafana Cloud OTLP endpoint |
| `OTLP_HEADERS` | `Authorization=Basic <base64 instanceID:token>` | Grafana Cloud OTLP auth header |

## 6.3 OpenLIT Configuration

OpenLIT is initialised inside `app.py`:

```python
import openlit

openlit.init(
    otlp_endpoint=os.environ.get("OTLP_ENDPOINT", "http://127.0.0.1:4318"),
    otlp_headers=os.environ.get("OTLP_HEADERS"),
    application_name="llm-wikipedia-bot",
    environment="development",
)
```

A tracer for the manual MCP spans is created immediately afterwards:

```python
from opentelemetry import trace
tracer = trace.get_tracer("wikipedia-mcp-tools")
```

---

# 7. Installation Method

The entire application host is provisioned by a single script, `setup.sh`, on a clean Ubuntu EC2 instance. All commands target Ubuntu.

## 7.1 Prerequisites

- One AWS EC2 instance (Ubuntu).
- A Google AI Studio account (for a Gemini API key).
- A Grafana Cloud account (free tier is sufficient).
- The project files in one directory: `app.py`, `wikipedia_server.py`, `setup.sh`, `run.sh`.

## 7.2 Obtain Credentials

**Gemini API key:** Sign in to Google AI Studio (`aistudio.google.com`), open the API keys section, and create a key. This is your `GEMINI_API_KEY`.

**Grafana Cloud OTLP token:** Sign in to Grafana Cloud, open your stack's OpenTelemetry / OTLP configuration, generate an API token, and copy the `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_EXPORTER_OTLP_HEADERS` values. These become `OTLP_ENDPOINT` and `OTLP_HEADERS`.

## 7.3 Run the Setup Script

```bash
chmod +x setup.sh run.sh
./setup.sh
```

`setup.sh` installs Python and a virtual environment, installs the dependencies (`google-genai`, `mcp[cli]`, `httpx`, `python-dotenv`, `openlit`, and the OpenTelemetry packages), and creates the `.env` file. It prompts for the Gemini API key and the Grafana `OTLP_HEADERS` if they are not already present in the environment or `.env`.

## 7.4 (Optional) Verify

Confirm the `.env` file contains `GEMINI_API_KEY`, `OTLP_ENDPOINT`, and `OTLP_HEADERS`.

---

## 8. Demo deployment steps

1. On the EC2 instance, ensure setup has been run (`./setup.sh`) and `.env` contains the Gemini key and Grafana OTLP credentials.
2. Start the system:
   ```bash
   ./run.sh
   ```
   This launches the MCP server and the application. Ask a question that requires Wikipedia (e.g. "Tell me about beavers").
3. Open Grafana Cloud in a browser and view the telemetry:
   - **Drilldown -> Traces** for the end-to-end request trace (including the `mcp.tool.*` spans).
   - **Drilldown -> Metrics** for token, cost, and latency metrics.

## 9. Demo description

After running the application with `./run.sh`, we interact with the `gemini-3.1-flash-lite` model through a terminal-based chat. Every stage of the interaction is captured as traces and metrics in Grafana Cloud. Below we walk through what the telemetry looks like at each step.

### 9.1 Startup (no prompt yet)

Simply starting the application — before asking the model anything — already produces traces, because the client establishes a connection to the MCP server:

<img width="1243" height="73" alt="Startup traces" src="https://github.com/user-attachments/assets/3dbc79cb-c53f-4309-ab8e-85696bca0625" />

The `POST` trace is the signal sent to the Wikipedia MCP server that establishes the connection, and the `mcp-initialize` trace contains information about the initialization of the MCP server:

<img width="1213" height="546" alt="MCP initialize trace detail" src="https://github.com/user-attachments/assets/a99b2bb0-2c76-4072-83b0-20f60996279d" />

### 9.2 Asking a question that does not require the MCP server

When the model answers from its own knowledge, without calling a tool, the following traces are produced:

<img width="1136" height="145" alt="Traces for a non-tool question" src="https://github.com/user-attachments/assets/688b01f0-fe7d-41c5-8823-ee023adf71b1" />

The most important of these is `mcp tools/list`, which contains information about the tools exposed by our MCP server:

<img width="1208" height="476" alt="mcp tools/list trace detail" src="https://github.com/user-attachments/assets/92fd4a18-2034-4dd0-b15f-cfd4f91d580a" />

And `chat gemini-3.1-flash-lite`, which contains the prompt and the answer as well as token usage and cost:

<img width="1204" height="477" alt="chat span with prompt and answer" src="https://github.com/user-attachments/assets/2a0bf661-ff73-47ac-aa61-a13fcacc1e6b" />

<img width="572" height="356" alt="token usage and cost" src="https://github.com/user-attachments/assets/2bf4a125-306a-48f3-8465-4d9369035bb7" />

### 9.3 Asking a question that triggers the MCP server

When the model decides it should use the MCP server, these traces are produced:

<img width="1136" height="267" alt="Traces for a tool-using question" src="https://github.com/user-attachments/assets/862e3165-c73a-433d-bd4d-5cbabca90799" />

The same kinds of traces appear as in the previous case, with the addition of the MCP tool calls made by the model.

First, the model asks the MCP server to search for Wikipedia articles related to "Beaver":

<img width="1204" height="497" alt="search_wikipedia tool call" src="https://github.com/user-attachments/assets/b6bf2275-127b-45ee-a4cd-d9a9a6f7bf0b" />

The MCP server returns the matching articles:

<img width="1196" height="495" alt="search_wikipedia tool result" src="https://github.com/user-attachments/assets/06eb814a-68c1-4750-9876-f25fa9de38c8" />

The model then asks for the summary of a chosen article:

<img width="1202" height="491" alt="get_summary tool call" src="https://github.com/user-attachments/assets/a512de0b-07fe-4a05-a74b-89a05a0c9fdc" />

And the MCP server returns the article summary:

<img width="1192" height="494" alt="get_summary tool result" src="https://github.com/user-attachments/assets/e536a5c1-7f8f-46a4-84d6-5222e3e1679c" />

### 9.4 Metrics

In addition to traces, we can inspect model and MCP usage through metrics:

<img width="1594" height="720" alt="Metrics dashboard" src="https://github.com/user-attachments/assets/75b74be9-b927-45de-8f64-8b11b11e5eab" />

Together, the traces and metrics give a complete picture of each request: the prompt and response, which tools the model chose, how the MCP server responded, and the token, cost, and latency figures for the interaction.

## 10. Summary – conclusions

This project demonstrates end-to-end observability of an LLM application that uses external tools through the Model Context Protocol. Starting from a Gemini-powered chat client, we extended the model with a Wikipedia MCP server exposing two tools (`search_wikipedia` and `get_summary`), instrumented the whole pipeline with the OpenLIT SDK, and shipped all telemetry directly to Grafana Cloud — without any self-hosted observability infrastructure.

Several conclusions emerge from the work:

**Full visibility was achieved across the pipeline.** Every layer of a request is observable: the prompt and response, the model's token usage and estimated cost, the latency of each LLM call, the tools the model decided to call, and the MCP server's responses. The full multi-step reasoning chain (search → get_summary → answer) is reconstructable from a single trace.

**MCP tool calls are visible as independent, timed spans.** By wrapping each tool invocation in a custom OpenTelemetry span, the latency of `search_wikipedia` and `get_summary` can be measured separately, rather than being hidden inside the LLM message history. This was the key gap closed during implementation and makes tool-level performance analysis possible.

**A lightweight architecture is sufficient.** The final design runs on a single EC2 instance and sends telemetry straight to Grafana Cloud's managed OTLP endpoint. This removed the need for a separate observability server, a self-hosted OpenTelemetry Collector, ClickHouse, and Prometheus — simplifying both deployment and maintenance while still meeting every observability goal.

**The approach generalises.** Although Wikipedia was used as the external data source, the observability layer is independent of the specific tool. Any MCP-exposed tool would be traced in the same way, so the same setup could monitor far more complex agentic applications.

**Limitations and future work.** The current setup uses a CLI client and a single host, which is well suited to a demonstration but not to production load or multiple concurrent users. Natural next steps include adding alerting rules on latency and error rates, building dedicated Grafana dashboards on top of the collected metrics, and load-testing the MCP server to characterise its behaviour under concurrency.
## 11. References

### LLM and SDK
- Google Gen AI SDK (`google-genai`) — Python documentation: https://googleapis.github.io/python-genai/
- Google AI Studio (Gemini API keys): https://aistudio.google.com/
- Gemini API documentation: https://ai.google.dev/gemini-api/docs
- Gemini API function calling / tool use: https://ai.google.dev/gemini-api/docs/function-calling
- Gemini API rate limits: https://ai.google.dev/gemini-api/docs/rate-limits

### Model Context Protocol (MCP)
- Model Context Protocol — official site: https://modelcontextprotocol.io/
- MCP Python SDK (FastMCP): https://github.com/modelcontextprotocol/python-sdk

### External data source (Wikipedia)
- Wikimedia REST API: https://en.wikipedia.org/api/rest_v1/
- Wikimedia User-Agent policy: https://meta.wikimedia.org/wiki/User-Agent_policy

### Observability
- OpenLIT — documentation: https://docs.openlit.io/
- OpenLIT — GitHub repository: https://github.com/openlit/openlit
- OpenTelemetry — Python documentation: https://opentelemetry.io/docs/languages/python/
- OpenTelemetry — tracing concepts (spans): https://opentelemetry.io/docs/concepts/signals/traces/

### Visualization / backend
- Grafana Cloud — OpenTelemetry (OTLP) setup: https://grafana.com/docs/grafana-cloud/send-data/otlp/
- Grafana Cloud — documentation: https://grafana.com/docs/grafana-cloud/

### Infrastructure
- AWS EC2 — documentation: https://docs.aws.amazon.com/ec2/
- AWS Academy Learner Lab: https://awsacademy.instructure.com/
