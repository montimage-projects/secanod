# secAnoD

**AI-driven Network Anomaly and Attack Detection** — a SECASSURED security service.

> Part of the [SECASSURED](https://secureflow.assist.ro/secassured) project (Horizon Europe, GA No. 101225858).
> Reference architecture: [`secassured/architecture`](https://secureflow.assist.ro/secassured/architecture) — see chapter `111_secAnoD`.

- **Owner / developed by:** MONTIMAGE (MTI), NTNU, TECNALIA (TEC)
- **Work package / tasks:** WP3 (SecDevTwin & SecDev services); contributes detection to WP4 (SecOpsTwin)
- **Start TRL:** 4

## 1. Overview

secAnoD is an AI-driven network anomaly and attack detection component that combines deep
packet inspection, rule-based detection, and LLM/SLM-based detection to identify cybersecurity
incidents in monitored networks and to provide explainable alerts to downstream response and
orchestration tools.

- Detects anomalies, multi-stage (APT) attacks, and protocol misuse on monitored networks
- Combines DPI + an LTL rule engine with LLM/SLM-based detection, classification, and prediction
- Produces STIX-formatted alerts with priority levels (Critical / High / Medium / Low)
- Provides explainable-AI (XAI) outputs including root-cause analysis
- Feeds events and detections into the SecOpsTwin knowledge graph and triggers secAISOAR playbooks

**Background:** secAnoD builds on Montimage's existing MMT toolchain — `mmt-probe`, `mmt-dpi`,
`mmt-security`, `mmt-plugin-generator`, and `mmt-operator` — extended with an **LLM Detection
Engine**, an **API Gateway**, and an **XAI Module** developed within SECASSURED.

## 2. High-Level Description

secAnoD ingests raw traffic and pre-processed data, extracts protocol-level attributes, and
applies hybrid (rule-based + AI/LLM) detection to surface security-relevant events.

- Ingests raw network data (PCAP, NetFlow, syslog, JSON) from the monitored network
- Performs deep packet inspection and attribute extraction via `mmt-dpi`
- Runs LTL rule-based attack and protocol anomaly detection via `mmt-security`
- Hosts an LLM Detection Engine for anomaly classification, APT detection, and incident prediction
- Generates new LTL rules from learned patterns as a feedback loop into the rule engine
- Stores baselines, alerts, and training data in a time-series Event Store
- Exposes alerts, statistics, and configuration via a FastAPI-based API Gateway
- Provides explainability through a dedicated XAI Module (root-cause analysis)
- Publishes alerts to secAISOAR (STIX) and events / knowledge-graph data to SecOpsTwin (JSON/Kafka)

## 3. Position in the Architecture

secAnoD operates as a detection layer between the monitored network and the higher-level
twin/response components of the SECASSURED ecosystem.

**Upstream dependencies**
- Monitored Network — raw PCAP, NetFlow, syslog, JSON traffic
- Field-collected training data and curated benchmarks (offline ML lifecycle)

**Downstream dependencies**
- **secAISOAR** (T4.4) — consumes alerts in STIX format to trigger incident-response playbooks
- **SecOpsTwin** (T4.1) — consumes events and knowledge-graph updates (JSON/Kafka)

**Interaction with other components**
- The Security Operator views alerts and XAI reports through the API Gateway / dashboards
- Communicates with downstream SECASSURED components via REST APIs and the Kafka event bus
- Receives feedback (training data, scenario data) used to refine models and LTL rules

## 4. C4 Architecture

- **Context (Level 1):** secAnoD within the SECASSURED ecosystem, interacting with the Security
  Operator, the monitored network, and downstream systems (secAISOAR, SecOpsTwin).
- **Container (Level 2):** the MMT-based capture and detection stack (`mmt-probe` embedding
  `mmt-dpi` and `mmt-security`, with `mmt-plugin-generator` providing protocol parser plugins at
  build time and `mmt-operator` the visualization layer), the LLM Detection Engine, the Event
  Store, the API Gateway, and the XAI Module.
- **Component (Level 3):** the internal structure of the LLM Detection Engine, separating the
  **Offline ML Lifecycle** (model selection, golden dataset, evaluation/benchmarking, fine-tuning,
  model registry) from the **Runtime Detection** path (M-Agent Orchestrator, Anomaly Classifier,
  APT Detector, Incident Predictor, Rule Plugin Generator), with feedback to the rule engine via
  newly generated LTL rules.

C4 diagrams are maintained in the reference architecture book (`secassured/architecture`, chapter
`111_secAnoD`).

## 5. Subcomponents

| # | Subcomponent | Role |
|---|--------------|------|
| 5.1 | **mmt-probe** (Capture & Detection Host) | Captures raw traffic / ingests pre-processed data; drives DPI and rule-based detection; forwards parsed events to the LLM Detection Engine and stats/alerts to mmt-operator |
| 5.2 | **mmt-dpi** (Deep Packet Inspection) | Embedded C library; parses protocols, extracts attributes, loads parser plugins (`.so`) |
| 5.3 | **mmt-security** (LTL Rule Engine) | Embedded C library; evaluates LTL rules over attribute streams; accepts generated rules (feedback loop) |
| 5.4 | **mmt-plugin-generator** (Offline Tool) | Java tool generating protocol parser plugins (`.so`) consumed by mmt-dpi |
| 5.5 | **mmt-operator** (Visualization) | JS web app; persists stats/alerts, provides dashboards and probe management |
| 5.6 | **LLM Detection Engine** | Python/PyTorch; Offline ML Lifecycle (model selection, golden dataset, evaluation, fine-tuning via LoRA/QLoRA/PEFT, model registry) + Runtime Detection (M-Agent Orchestrator, Anomaly Classifier, APT Detector, Incident Predictor, Rule Plugin Generator) |
| 5.7 | **Event Store** | Time-series DB for baselines, alerts, and training data |
| 5.8 | **API Gateway** | FastAPI; REST endpoints for alerts/stats/config; egress of STIX alerts to secAISOAR |
| 5.9 | **XAI Module** | Python; root-cause analysis and human-readable explanations; events/KG data to SecOpsTwin |

## 6. Interfaces & APIs

Inter-component communication within SECASSURED uses a common distributed event-streaming
platform (Apache Kafka) as the primary middleware, with REST APIs for direct interactions.

**Inbound**
- Raw network data (PCAP, NetFlow, syslog, JSON) from the monitored network
- Cleaned / pre-processed events (masked, normalized)
- REST APIs for configuration and requests
- Kafka topics for events and analysis outputs from SECASSURED components
- Field-collected training data for the offline ML lifecycle

**Outbound**
- Alerts in STIX format to secAISOAR (priority: Critical / High / Medium / Low)
- Events and knowledge-graph updates to SecOpsTwin (JSON / Kafka)
- REST APIs exposing alerts, statistics, and configuration to operators
- XAI reports (root-cause analysis, explanations)
- Newly generated LTL rules published back into mmt-security (internal feedback loop)

## 7. Repository Layout

```
.
└── README.md        # this file
```

Source code, deployment manifests, and detection models will be added under this repository as
development progresses.

## Authors & Acknowledgment

Developed by **MONTIMAGE (MTI)**, **NTNU**, and **TECNALIA (TEC)** within the SECASSURED project.

The SECASSURED project has received funding from the European Union's Horizon Europe research and
innovation programme under grant agreement No. **101225858**.

## License

See the project consortium agreement. License to be confirmed with the coordinator (SINTEF).
