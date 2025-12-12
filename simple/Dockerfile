FROM debian:12-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install dependencies
RUN apt-get update && apt-get install -y \
	build-essential \
	ccache \
	g++ \
	gawk \
	git \
	make \
	wget \
	valgrind \
	screen \
	procps \
	libtool \
	libxml2-dev \
	libxslt1-dev \
	python3-dev \
	python3-pip \
	python3-setuptools \
	python3-numpy \
	python3-pyparsing \
	python3-psutil \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Set up Python virtual environment with UV
RUN uv venv --python 3.13 --no-project
ENV PATH="/app/.venv/bin:$PATH"

COPY uv.lock pyproject.toml /app/

ENV UV_SYSTEM_PYTHON=true \
    UV_COMPILE_BYTCODE=1 \
    UV_CAHE_DIR=/app/.cache/uv \
    UV_LINK_MODE=copy

RUN uv sync --frozen --no-cache

# Clone Ardupilot repository
ENV ARDUPILOT_VERSION=ArduPilot-4.6
RUN git clone --branch ${ARDUPILOT_VERSION} --depth 1 --recurse-submodules https://github.com/ArduPilot/ardupilot.git /app/ardupilot
WORKDIR /app/ardupilot

# Build Ardupilot
RUN ./waf distclean
RUN ./waf configure --board sitl
RUN ./waf copter
RUN ./waf rover
RUN ./waf plane
RUN ./waf sub
