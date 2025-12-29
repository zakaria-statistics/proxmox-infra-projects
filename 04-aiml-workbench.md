# AI/ML Workbench

## Overview

Comprehensive development and deployment environment for machine learning, large language models (LLMs), retrieval-augmented generation (RAG), AI agents, and experimental AI workflows.

## Infrastructure Type

**Virtual Machine** - Required for GPU passthrough and full hardware control

## Key Components

- **Ollama** - Local LLM runtime and model management
- **ChromaDB** - Vector database for embeddings and semantic search
- **Jupyter** - Interactive notebooks for experimentation
- **LangChain** - LLM application framework and orchestration
- **Model Context Protocol (MCP)** - Standardized AI tool integration
- **Python ML Stack** - PyTorch, TensorFlow, scikit-learn, pandas, numpy

## Resource Allocation

- **RAM:** 8-12GB (minimum 8GB for 7B models, 12GB+ for 13B+)
- **vCPU:** 8 cores (CPU inference for smaller models)
- **GPU:** NVIDIA Ada (RTX 4000 series) passthrough for accelerated inference
- **Storage:** 200GB+ (models can be 5-50GB each)

## Use Cases

### 1. LLM Inference & Chat
- Run local models (Llama 3, Mistral, CodeLlama)
- Private ChatGPT-like interfaces
- Custom fine-tuned models

### 2. Retrieval-Augmented Generation (RAG)
- Document Q&A systems
- Knowledge base search
- Semantic search engines
- Context-aware chatbots

### 3. Embeddings & Vector Search
- Text similarity search
- Document clustering
- Recommendation systems
- Semantic code search

### 4. Fine-Tuning & Training
- Model customization with domain data
- LoRA/QLoRA efficient fine-tuning
- Transfer learning experiments

### 5. AI Agents
- Autonomous task execution
- Multi-step reasoning
- Tool-using agents (MCP integration)
- Workflow automation

## Implementation Steps

### 1. Create VM on Proxmox

```bash
# Create VM with GPU passthrough
qm create 400 --name aiml-workbench \
  --memory 12288 \
  --cores 8 \
  --scsihw virtio-scsi-pci \
  --net0 virtio,bridge=vmbr0 \
  --cpu host \
  --machine q35

# Configure GPU passthrough (NVIDIA Ada)
# Edit /etc/pve/qemu-server/400.conf
hostpci0: 0000:01:00,pcie=1,x-vga=1

# Enable IOMMU in Proxmox
# Edit /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
# OR for AMD: amd_iommu=on

update-grub
reboot
```

### 2. Install Operating System

```bash
# Ubuntu 22.04 Server LTS recommended
# During installation:
# - Enable OpenSSH server
# - Install Docker (optional, for containerized services)
```

### 3. Install NVIDIA Drivers & CUDA

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install NVIDIA driver
sudo apt install -y nvidia-driver-535 nvidia-utils-535

# Install CUDA Toolkit
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
sudo apt install -y cuda-toolkit-12-3

# Verify installation
nvidia-smi
nvcc --version
```

### 4. Install Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
systemctl start ollama
systemctl enable ollama

# Pull models
ollama pull llama3.2:3b      # Small model for testing
ollama pull llama3:8b        # General purpose
ollama pull codellama:13b    # Code generation
ollama pull mistral:7b       # Fast inference
ollama pull nomic-embed-text # Embeddings

# Test
ollama run llama3:8b "Explain Kubernetes in simple terms"
```

### 5. Install ChromaDB

```bash
# Install via pip
pip3 install chromadb

# Or run as Docker container
docker run -d -p 8000:8000 chromadb/chroma

# Or install from source for development
git clone https://github.com/chroma-core/chroma.git
cd chroma
pip3 install -e .
```

### 6. Install Jupyter

```bash
# Install JupyterLab
pip3 install jupyterlab ipywidgets

# Generate config
jupyter lab --generate-config

# Set password
jupyter lab password

# Configure to listen on all interfaces
cat >> ~/.jupyter/jupyter_lab_config.py <<EOF
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
EOF

# Create systemd service
sudo cat > /etc/systemd/system/jupyter.service <<EOF
[Unit]
Description=Jupyter Lab
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER
ExecStart=/usr/local/bin/jupyter lab
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start jupyter
sudo systemctl enable jupyter
```

### 7. Install LangChain & Dependencies

```bash
# Install core LangChain packages
pip3 install langchain langchain-community langchain-ollama

# Install additional tools
pip3 install \
  sentence-transformers \  # Embeddings
  faiss-cpu \              # Vector search (or faiss-gpu)
  beautifulsoup4 \         # Web scraping
  pypdf \                  # PDF parsing
  python-dotenv \          # Environment management
  openai                   # OpenAI API (optional)

# Install ML frameworks
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip3 install transformers accelerate bitsandbytes
pip3 install scikit-learn pandas numpy matplotlib seaborn
```

### 8. Install MCP (Model Context Protocol)

```bash
# Install MCP SDK
pip3 install mcp

# Example MCP server for file operations
git clone https://github.com/modelcontextprotocol/servers.git
cd servers/src/filesystem
pip3 install -e .

# Start MCP server
python -m mcp_server_filesystem /path/to/workspace
```

## Sample Projects

### 1. RAG System with Ollama + ChromaDB

```python
# rag_system.py
from langchain_ollama import OllamaLLM, OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
from langchain_community.document_loaders import DirectoryLoader, TextLoader

# Load documents
loader = DirectoryLoader('./docs', glob="**/*.txt", loader_cls=TextLoader)
documents = loader.load()

# Split text
text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
texts = text_splitter.split_documents(documents)

# Create embeddings
embeddings = OllamaEmbeddings(model="nomic-embed-text")

# Create vector store
vectorstore = Chroma.from_documents(
    documents=texts,
    embedding=embeddings,
    persist_directory="./chroma_db"
)

# Create retrieval QA chain
llm = OllamaLLM(model="llama3:8b", temperature=0.7)
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=vectorstore.as_retriever(search_kwargs={"k": 3})
)

# Query
query = "What are the main features of Kubernetes?"
result = qa_chain.invoke(query)
print(result['result'])
```

### 2. AI Agent with Tool Use

```python
# ai_agent.py
from langchain.agents import create_react_agent, AgentExecutor
from langchain.tools import Tool
from langchain_ollama import OllamaLLM
import requests

# Define tools
def search_web(query: str) -> str:
    """Search the web for information"""
    # Implement web search API call
    return f"Search results for: {query}"

def calculate(expression: str) -> str:
    """Calculate mathematical expressions"""
    try:
        return str(eval(expression))
    except:
        return "Invalid expression"

tools = [
    Tool(name="Search", func=search_web, description="Search the web"),
    Tool(name="Calculator", func=calculate, description="Calculate math expressions")
]

# Create agent
llm = OllamaLLM(model="llama3:8b")
agent = create_react_agent(llm, tools)
agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)

# Run agent
result = agent_executor.invoke({
    "input": "What is the square root of 144? Then search for information about that number."
})
```

### 3. Document Embedding & Similarity Search

```python
# semantic_search.py
import chromadb
from sentence_transformers import SentenceTransformer

# Initialize ChromaDB
client = chromadb.Client()
collection = client.create_collection("documents")

# Load embedding model
model = SentenceTransformer('all-MiniLM-L6-v2')

# Add documents
documents = [
    "Kubernetes is a container orchestration platform",
    "Docker is used for containerization",
    "Python is a programming language",
    "Machine learning models require training data"
]

embeddings = model.encode(documents)

collection.add(
    embeddings=embeddings.tolist(),
    documents=documents,
    ids=[f"doc_{i}" for i in range(len(documents))]
)

# Search
query = "What is container management?"
query_embedding = model.encode([query])

results = collection.query(
    query_embeddings=query_embedding.tolist(),
    n_results=2
)

print("Most similar documents:")
for doc in results['documents'][0]:
    print(f"- {doc}")
```

### 4. Fine-Tuning with LoRA

```python
# fine_tune.py
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig, get_peft_model
from datasets import load_dataset

# Load base model
model_name = "meta-llama/Llama-2-7b-hf"
model = AutoModelForCausalLM.from_pretrained(model_name, load_in_8bit=True)
tokenizer = AutoTokenizer.from_pretrained(model_name)

# Configure LoRA
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)

model = get_peft_model(model, lora_config)

# Load dataset
dataset = load_dataset("json", data_files="training_data.jsonl")

# Training arguments
training_args = TrainingArguments(
    output_dir="./lora_model",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    learning_rate=2e-4,
    fp16=True
)

# Train (simplified - use Trainer class in practice)
# trainer = Trainer(model=model, args=training_args, train_dataset=dataset)
# trainer.train()
```

### 5. MCP-Enabled AI Assistant

```python
# mcp_assistant.py
from mcp import Client
from langchain_ollama import OllamaLLM

# Connect to MCP server
mcp_client = Client("http://localhost:3000")

# Get available tools from MCP
tools = mcp_client.list_tools()

# Create LLM with MCP tools
llm = OllamaLLM(model="llama3:8b")

def process_request(user_input):
    # Use LLM to determine which MCP tool to use
    response = llm.invoke(f"User request: {user_input}. Available tools: {tools}")

    # Execute MCP tool based on LLM response
    # result = mcp_client.call_tool(selected_tool, params)

    return response
```

## Jupyter Notebook Examples

### Example Notebook Structure

```
notebooks/
├── 01_ollama_quickstart.ipynb
├── 02_rag_implementation.ipynb
├── 03_embedding_search.ipynb
├── 04_agent_workflows.ipynb
├── 05_fine_tuning.ipynb
└── 06_model_evaluation.ipynb
```

## Integration with K8s Platform

### Deploy Model Inference API

```python
# app.py - FastAPI inference endpoint
from fastapi import FastAPI
from langchain_ollama import OllamaLLM

app = FastAPI()
llm = OllamaLLM(model="llama3:8b", base_url="http://aiml-workbench:11434")

@app.post("/generate")
async def generate(prompt: str):
    response = llm.invoke(prompt)
    return {"response": response}
```

**Kubernetes Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-api
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: api
        image: registry.local/llm-api:latest
        env:
        - name: OLLAMA_HOST
          value: "http://aiml-workbench:11434"
```

### Serverless AI Functions

```python
# OpenFaaS function for AI inference
def handle(req):
    from langchain_ollama import OllamaLLM

    llm = OllamaLLM(model="llama3:8b")
    result = llm.invoke(req)

    return result
```

## Performance Optimization

### GPU Acceleration

```bash
# Verify GPU is accessible
nvidia-smi

# Set CUDA visible devices
export CUDA_VISIBLE_DEVICES=0

# Use GPU in Ollama
ollama run llama3:8b --gpu
```

### Model Quantization

```bash
# Use quantized models for faster inference
ollama pull llama3:8b-q4_K_M  # 4-bit quantization
ollama pull llama3:8b-q8_0    # 8-bit quantization
```

### Batch Processing

```python
# Process multiple prompts efficiently
prompts = ["Question 1", "Question 2", "Question 3"]
responses = llm.batch(prompts)
```

## Monitoring & Observability

### Ollama Metrics

```bash
# Check running models
curl http://localhost:11434/api/tags

# Model info
curl http://localhost:11434/api/show -d '{"name": "llama3:8b"}'
```

### GPU Monitoring

```bash
# Install nvidia-smi dashboard
pip3 install gpustat
gpustat -i 1

# Or use Prometheus exporter
docker run -d --gpus all -p 9835:9835 nvcr.io/nvidia/k8s/dcgm-exporter:latest
```

### ChromaDB Monitoring

```python
# Check collection stats
collection.count()
collection.peek()
```

## Security Considerations

- **Network Isolation** - Keep on private network
- **API Authentication** - Secure Jupyter and API endpoints
- **Model Access Control** - Restrict who can load/use models
- **Data Privacy** - No external API calls, local inference only
- **GPU Access** - Limit to authorized users only

## Backup & Disaster Recovery

```bash
# Backup Ollama models
tar -czf ollama_models.tar.gz ~/.ollama/models/

# Backup ChromaDB
tar -czf chroma_db.tar.gz ./chroma_db/

# Backup notebooks
tar -czf notebooks.tar.gz ~/notebooks/

# Backup fine-tuned models
tar -czf custom_models.tar.gz ./lora_model/
```

## Resource Scaling

### Vertical Scaling
- Increase RAM for larger models (13B+ models need 16GB+)
- Add more VRAM (GPU memory) for batch processing
- More CPU cores for parallel embedding generation

### Horizontal Scaling
- Deploy multiple Ollama instances (load balanced)
- Distributed vector databases (Qdrant, Weaviate)
- Model serving on K8s with autoscaling

## Common Issues & Troubleshooting

### GPU Not Detected

```bash
# Check PCI passthrough
lspci | grep -i nvidia

# Verify IOMMU groups
find /sys/kernel/iommu_groups/ -type l

# Check driver
nvidia-smi
```

### Out of Memory (OOM)

```bash
# Use smaller models
ollama pull llama3.2:3b

# Enable quantization
ollama run llama3:8b-q4_K_M

# Reduce context window
ollama run llama3:8b --num_ctx 2048
```

### Slow Inference

- Use GPU acceleration
- Enable quantization
- Reduce model size
- Batch requests
- Optimize prompts (shorter context)

## Next Steps

1. Create VM with GPU passthrough
2. Install NVIDIA drivers and CUDA
3. Install Ollama and pull models
4. Set up ChromaDB for vector storage
5. Install Jupyter for experimentation
6. Deploy LangChain applications
7. Integrate MCP for tool use
8. Build RAG systems and AI agents
9. Deploy inference APIs to K8s

---

**Related Projects:**
- [K8s Platform](./02-k8s-platform.md) - Deploy AI inference APIs
- [DB Cluster](./03-db-cluster.md) - Store embeddings and metadata
- [CI/CD Platform](./01-cicd-platform.md) - Build and deploy AI applications
