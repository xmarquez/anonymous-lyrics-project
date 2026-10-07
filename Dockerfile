# Use the rocker/verse base image with R and tidyverse pre-installed
# R version 4.5.2 matches the project's renv lockfile R version (4.5.1 is compatible)
FROM rocker/verse:4.5.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libglpk-dev \
    wget \
    cmake \
    python3 \
    python3-venv \
    python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variable to force nanonext to compile bundled libraries
ENV NANONEXT_LIBS=1

# Set working directory
WORKDIR /project

# Copy renv infrastructure first (for better Docker layer caching)
# This means if dependencies don't change, we don't need to reinstall them
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
COPY requirements-empath.txt requirements-empath.txt

# Install renv and restore packages from lockfile
# This ensures exact package versions from the lockfile
RUN R -e "install.packages('renv', repos = c(CRAN = 'https://cloud.r-project.org'))"
RUN R -e "renv::restore()"

# Install Quarto CLI for tar_quarto targets
RUN wget -qO /tmp/quarto.deb https://quarto.org/download/latest/quarto-linux-amd64.deb \
    && dpkg -i /tmp/quarto.deb \
    && rm /tmp/quarto.deb

# Install Empath Python dependencies in a dedicated venv
RUN python3 -m venv /opt/empath_venv \
    && /opt/empath_venv/bin/pip install --upgrade pip \
    && /opt/empath_venv/bin/pip install -r requirements-empath.txt

# Point reticulate at the Empath venv by default
ENV RETICULATE_PYTHON=/opt/empath_venv/bin/python

# Multithreaded OpenBLAS thrashes on stm's many small matrix operations (the STM fit runs over 6x slower)
ENV OPENBLAS_NUM_THREADS=1

# Copy the rest of the project files
COPY . /project

# Create logs directory for crew workers
RUN mkdir -p /project/logs

# Set the default command to run the targets pipeline
CMD ["Rscript", "run.R"]
