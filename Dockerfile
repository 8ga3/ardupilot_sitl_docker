FROM debian:trixie-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
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

# Use Debian's system Python so the venv also works on the runtime image.
# Bytecode is not precompiled (and not written at build time) to keep the image small.
ENV UV_PYTHON=/usr/bin/python3 \
    UV_CACHE_DIR=/app/.cache/uv \
    UV_LINK_MODE=copy \
	UV_PYTHON_DOWNLOADS=never \
	PYTHONDONTWRITEBYTECODE=1

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

ENV PATH="/app/.venv/bin:$PATH"

# Clone Ardupilot repository
# Branch or tag name of https://github.com/ArduPilot/ardupilot
# Override with: docker compose build --build-arg ARDUPILOT_VERSION=<branch>
ARG ARDUPILOT_VERSION=ArduPilot-4.7
RUN git clone --branch ${ARDUPILOT_VERSION} --depth 1 --recurse-submodules https://github.com/ArduPilot/ardupilot.git /app/ardupilot
WORKDIR /app/ardupilot

# Build Ardupilot
RUN ./waf distclean
RUN ./waf configure --board sitl
RUN ./waf copter
RUN ./waf rover
RUN ./waf plane
RUN ./waf sub
RUN ./waf heli

# Clean up unnecessary packages from virtual environment
WORKDIR /app
RUN uv remove empy packaging

# Slim down the virtual environment and binaries
#  - mavproxy_cesium/app: web assets (114MB); unusable anyway because tornado is not installed
#  - numpy tests: not needed at runtime
#  - MAVLink dialects: keep only all (MAVProxy default) / ardupilotmega / common / minimal / standard
#  - __pycache__, activate scripts, lxml headers: not needed at runtime
#  - strip symbol tables from SITL binaries
RUN SP=/app/.venv/lib/python3.13/site-packages \
 && rm -rf $SP/MAVProxy/modules/mavproxy_cesium/app \
 && find $SP/numpy -type d -name tests -prune -exec rm -rf {} + \
 && find $SP/pymavlink/dialects -type f \( -name '*.py' -o -name '*.xml' \) \
	! -name '__init__.py' \
	! -name 'all.*' \
	! -name 'ardupilotmega.*' \
	! -name 'common.*' \
	! -name 'minimal.*' \
	! -name 'standard.*' \
	-delete \
 && find /app/.venv -type d -name __pycache__ -prune -exec rm -rf {} + \
 && rm -rf $SP/lxml/includes \
 && rm -f /app/.venv/bin/activate* /app/.venv/bin/deactivate* \
 && strip /app/ardupilot/build/sitl/bin/*

FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
	python3 \
	procps \
	ca-certificates \
	netbase \
	tzdata \
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
# sim_vehicle.py exits with "vehicle directory does not exist" unless the directory
# named by --vehicle exists, so create an empty one for each supported vehicle.
RUN mkdir -p /app/build/sitl \
	/app/Tools/autotest \
	/app/ArduCopter \
	/app/ArduPlane \
	/app/ArduSub \
	/app/Helicopter \
	/app/Rover

COPY --from=builder /app/ardupilot/build/sitl/bin /app/build/sitl/bin
COPY --from=builder /app/ardupilot/Tools/autotest/sim_vehicle.py /app/Tools/autotest/sim_vehicle.py
COPY --from=builder /app/ardupilot/Tools/autotest/run_in_terminal_window.sh /app/Tools/autotest/run_in_terminal_window.sh
COPY --from=builder /app/ardupilot/Tools/autotest/default_params /app/Tools/autotest/default_params
COPY --from=builder /app/ardupilot/Tools/autotest/pysim /app/Tools/autotest/pysim
# models: default parameters for ArduPlane frames etc. / locations.txt: for -L / swarminit.txt: for --swarm
COPY --from=builder /app/ardupilot/Tools/autotest/models /app/Tools/autotest/models
COPY --from=builder /app/ardupilot/Tools/autotest/locations.txt /app/ardupilot/Tools/autotest/swarminit.txt /app/Tools/autotest/

RUN chown nonroot:nonroot /app

# Switch to non-root user
USER nonroot

ENTRYPOINT [ "tail", "-F", "/dev/null" ]
