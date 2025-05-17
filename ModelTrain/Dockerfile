FROM runpod/pytorch:2.2.0-py3.10-cuda12.1.1-devel-ubuntu22.04

# Set working directory
WORKDIR /workspace

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
    unzip \
    python3.10-tk \
    psmisc \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy all necessary files
COPY claude_analysis.py /workspace/
COPY finetune_analysis.sh /workspace/
COPY post_start.sh /
COPY MyRunpodFinetuneScripts/* /workspace/

# Make scripts executable
RUN chmod +x /workspace/finetune_analysis.sh \
    && chmod +x /post_start.sh

# Install Python dependencies
RUN pip install --no-cache-dir \
    huggingface_hub \
    ipywidgets \
    hf_transfer \
    anthropic \
    pydantic==2.10.6


# Set up kohya_ss environment with specific commit
RUN cd /workspace && \
    git clone https://github.com/bmaltais/kohya_ss.git && \
    cd kohya_ss && \
    git checkout b9028e87102218eb5b32370678bd3e353f480ed4 && \
    python3 -m venv venv && \
    . venv/bin/activate && \
    ./setup.sh -n -u && \
    pip uninstall -y xformers && \
    pip install --no-cache-dir torch==2.5.1+cu124 torchvision --index-url https://download.pytorch.org/whl/cu124 && \
    pip install --no-cache-dir xformers==0.0.28.post3 --index-url https://download.pytorch.org/whl/cu124

# Return to workspace directory
WORKDIR /

# Use the new entrypoint script
ENTRYPOINT ["/start.sh"] 