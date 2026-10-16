FROM osrf/ros:jazzy-desktop

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo \
    wget \
    curl \
    git \
    mesa-utils \
    libgl1 \
    libglx-mesa0 \
    libgl1-mesa-dri \
    ros-jazzy-ros-gz \
    ros-jazzy-gz-tools-vendor \
    ros-jazzy-joint-state-publisher-gui \
    ros-jazzy-xacro \
    # MoveIt. El metapaquete trae moveit_core, las utilidades de config y el
    # Setup Assistant, pero NO trae moveit_servo, que es justo lo que se usa aqui
    # (IK diferencial en tiempo real para los brazos): hay que pedirlo aparte.
    ros-jazzy-moveit \
    ros-jazzy-moveit-servo \
    # Solver de IK de los brazos. El KDL que trae MoveIt por defecto no tiene
    # minimal_displacement_weight, asi que en teleoperacion salta entre soluciones
    # de codo; pick_ik si lo tiene. Tampoco viene en el metapaquete.
    ros-jazzy-pick-ik \
    python3-colcon-common-extensions \
    python3-pip \
    python3-dev \
    python3-numpy \
    build-essential \
    pkg-config \
    ffmpeg \
    libavcodec-dev \
    libavdevice-dev \
    libavfilter-dev \
    libavformat-dev \
    libavutil-dev \
    libswresample-dev \
    libswscale-dev \
    libopus-dev \
    libvpx-dev \
    libsrtp2-dev \
    && rm -rf /var/lib/apt/lists/*

# aiortc 1.15 requiere cryptography >= 44.
# Ubuntu 24.04 ya trae una versión administrada por apt, por lo que
# se instala una versión de pip sin intentar desinstalar la de Debian.
RUN python3 -m pip install \
    --no-cache-dir \
    --break-system-packages \
    --ignore-installed \
    "cryptography>=44.0.0"

RUN python3 -m pip install \
    --no-cache-dir \
    --break-system-packages \
    aiortc \
    websockets

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute,display
ENV QT_X11_NO_MITSHM=1

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd \
        --uid $USER_UID \
        --gid $USER_GID \
        -m \
        -s /bin/bash \
        $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME

WORKDIR /home/$USERNAME/ros2_ws

RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc