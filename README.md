## 1. Introduction

In this project, we design an AI system with full observability for monitoring both the behavior of a Large Language Model (LLM) and its interactions with external tools.

The system is hosted on AWS and uses OpenLIT as the core observability platform. Through OpenLIT, we monitor conversations handled by the Gemini LLM. The model is extended with tool-calling capabilities via an MCP (Model Context Protocol) server, which enables it to retrieve additional information from external sources—in this case, Reddit.

To ensure complete visibility into the system, we integrate Grafana Cloud for monitoring and visualization. This allows us to track not only the LLM’s internal performance (such as latency and token usage), but also its interactions with the MCP server and external APIs.

The goal of this setup is to provide end-to-end observability of an AI application, making it easier to debug, optimize, and understand how the model behaves in real-world scenarios.

---

## 2. Theoretical Background / Technology Stack

The proposed solution combines modern LLM orchestration with observability practices typically used in distributed systems.

**Large Language Model (LLM):**  
The system uses Gemini as the primary LLM responsible for generating responses. The model processes user input and, when needed, retrieves external data via tools.

**Model Context Protocol (MCP) Server:**  
The MCP server acts as an intermediary layer between the LLM and external data sources. It enables tool usage by the LLM—in this case, querying Reddit. This introduces additional complexity and requires visibility into tool calls, latency, and response quality.

**OpenLIT (hosted on AWS):**  
OpenLIT is used for LLM observability. It captures:
- Prompts and responses
- Token usage
- Latency metrics
- Tool invocation traces (via MCP)

Running OpenLIT on AWS ensures scalability, reliability, and integration with cloud-native monitoring practices.

**Observability Stack:**
- OpenTelemetry: Standard for collecting traces, metrics, and logs across distributed systems.
- Prometheus: Used for scraping and storing time-series metrics such as request latency, token counts, and error rates.

**Visualization Layer:**
- Grafana Cloud: Provides dashboards and alerting capabilities. It visualizes:
  - LLM performance metrics
  - MCP tool usage
  - End-to-end request traces
  - System health indicators

This stack enables full observability across the AI pipeline—from user query to external data retrieval and final response generation.

---

## 3. Case Study Concept Description (Application / Observability / Visualization)

**Application Layer:**  
The application consists of a conversational interface powered by Gemini. When a user submits a query:
1. The LLM processes the request.
2. If external knowledge is needed, it invokes the MCP server.
3. The MCP server queries Reddit and returns relevant data.
4. The LLM incorporates this data into the final response.

**Observability Layer:**  
Observability is implemented using OpenLIT and OpenTelemetry instrumentation:
- Every interaction (prompt -> response) is logged.
- MCP calls are traced as separate spans in a distributed trace.
- Metrics such as latency, token usage, and error rates are collected.
- Logs provide detailed debugging information for failures or unexpected outputs.

Key observability goals:
- Understand LLM behavior and performance
- Monitor tool usage (Reddit queries via MCP)
- Detect anomalies (e.g., slow responses, failed tool calls)
- Analyze cost drivers (token consumption)

**Visualization Layer:**  
Grafana Cloud aggregates and visualizes all collected data:
- Dashboards display real-time system performance
- Traces show the full lifecycle of a request (LLM -> MCP -> Reddit -> LLM)
- Alerts notify when thresholds are exceeded (e.g., high latency or error rates)

This enables both operational monitoring and deeper analysis of LLM behavior.

---

## 4. Case Study High-Level Architecture

The architecture follows a pipeline model with three main stages: LLM -> Observability -> Visualization.

**1. Interaction Layer (LLM):**
- User sends a query
- Gemini processes the input
- Optional: invokes MCP server for Reddit data

**2. Integration Layer (MCP Server):**
- Receives tool requests from the LLM
- Queries Reddit
- Returns structured data to the LLM

**3. Observability Layer:**
- OpenLIT captures:
  - Prompts/responses
  - Tool calls
  - Latency and token metrics
- OpenTelemetry instruments all components
- Prometheus stores metrics

**4. Visualization Layer:**
- Grafana Cloud connects to Prometheus and telemetry sources
- Displays dashboards for:
  - LLM performance
  - MCP usage
  - End-to-end traces

**Data Flow Summary:**
1. User -> LLM (Gemini)  
2. LLM -> MCP Server (if external data needed)  
3. MCP -> Reddit -> MCP -> LLM  
4. OpenLIT captures all steps  
5. Metrics/logs/traces -> Prometheus / OpenTelemetry  
6. Grafana Cloud visualizes and monitors the system  

This architecture ensures full transparency of the AI system, enabling debugging, optimization, and reliable production deployment.

## 5. Case study detailed architecture

## 6. Environment configuration description

## 7. Installation method

## 8. Demo deployment steps

## 9. Demo description

## 10. Summary – conclusions

## 11. References
