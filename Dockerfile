# Base oficial de ROS 2 Jazzy Desktop (ya incluye RViz2)
FROM osrf/ros:jazzy-desktop

# Evitar prompts interactivos durante la construcción
ENV DEBIAN_FRONTEND=noninteractive

# 1. Instalar dependencias del sistema y drivers Mesa (para Intel/AMD)
RUN apt-get update && apt-get install -y \
    sudo \
    wget \
    curl \
    mesa-utils \
    libgl1 \
    libglx-mesa0 \
    libgl1-mesa-dri \
    && rm -rf /var/lib/apt/lists/*

# 2. Instalar Gazebo Harmonic y la integración con ROS 2
RUN apt-get update && apt-get install -y \
    ros-jazzy-ros-gz \
    ros-jazzy-gz-tools-vendor \
    && rm -rf /var/lib/apt/lists/*

# 3. Variables de entorno para habilitar aceleración NVIDIA (si está disponible)
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute,display
ENV QT_X11_NO_MITSHM=1

# 4. Configurar un usuario no root con Bash por defecto
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Eliminar el usuario 'ubuntu' por defecto en Ubuntu 24.04 para liberar UID/GID 1000
RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu || true

# SE AGREGA SEÑALIZACIÓN -s /bin/bash AQUÍ:
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME/ros2_ws

# 5. Cargar automáticamente el entorno de ROS 2 al abrir la terminal
RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc