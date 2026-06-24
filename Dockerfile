FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder
ENV DEBIAN_FRONTEND=noninteractive

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
COPY uv.lock pyproject.toml ./

ENV UV_SYSTEM_PYTHON=true \
    UV_COMPILE_BYTECODE=1 \
    UV_CACHE_DIR=/app/.cache/uv \
    UV_LINK_MODE=copy \
	UV_PYTHON_DOWNLOADS=never

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

ENV PATH="/app/.venv/bin:$PATH"

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

# Clean up unnecessary packages from virtual environment
WORKDIR /app
RUN uv remove empy packaging

FROM python:3.13-slim
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends procps \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --system --gid 999 nonroot \
 && useradd --system --gid 999 --uid 999 --create-home nonroot

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Prepare Ardupilot directories
RUN mkdir -p /app/build/sitl \
	/app/Tools/autotest \
	/app/AntennaTracker \
	/app/ArduCopter \
	/app/ArduPlane \
	/app/ArduSub \
	/app/Rover

COPY --from=builder /app/ardupilot/build/sitl/bin /app/build/sitl/bin
COPY --from=builder /app/ardupilot/Tools/autotest/sim_vehicle.py /app/Tools/autotest/sim_vehicle.py
COPY --from=builder /app/ardupilot/Tools/autotest/run_in_terminal_window.sh /app/Tools/autotest/run_in_terminal_window.sh
COPY --from=builder /app/ardupilot/Tools/autotest/default_params /app/Tools/autotest/default_params
COPY --from=builder /app/ardupilot/Tools/autotest/pysim /app/Tools/autotest/pysim

RUN chown nonroot:nonroot /app

# Switch to non-root user
USER nonroot

ENTRYPOINT [ "tail", "-F", "/dev/null" ]
