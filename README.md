# ROS 2 Jazzy Desktop + Gazebo Harmonic (DevContainer)

Este repositorio contiene la configuración de un **DevContainer** listo para usar con ROS 2 Jazzy y simulación en Gazebo Harmonic, optimizado para aceleración por hardware (GPU) y entornos visuales (RViz2, Gazebo, etc.).

Esta rama (`sentinel`) es la **infraestructura** del proyecto Sentinel (teleoperación VR de un robot humanoide): la imagen y la preparación del host ([`host/`](host/README.md)). En Sentinel este repo es un submódulo del monorrepo del proyecto, que tiene su propio `.devcontainer/` con esta imagen, monta los paquetes ROS (otro repo) como `src/` y guarda el workspace en un volumen de Docker. Usado solo, el `.devcontainer/` de aquí monta `ros2_ws/` de esta carpeta, que no se versiona. **Qué hace el robot se documenta en los paquetes; cómo se construye el entorno, aquí**.

---

## 📋 Especificaciones del Entorno

*   **Sistema Operativo Base:** Ubuntu 24.04 LTS (Noble Numbat)
*   **Versión de ROS 2:** [ROS 2 Jazzy Jalisco (Desktop)](https://docs.ros.org/en/jazzy/index.html) (incluye RViz2, herramientas de desarrollo y demos).
*   **Simulador:** [Gazebo Harmonic](https://gazebosim.org/docs/harmonic) integrado con ROS 2 (`ros-jazzy-ros-gz` y `ros-jazzy-gz-tools-vendor`).
*   **Usuario por Defecto:** `ros` (no-root, con privilegios de administrador `sudo` y UID/GID 1000 libre de conflictos).
*   **Shell:** `bash` por defecto, con el entorno de ROS 2 automáticamente cargado en cada nueva terminal (`source /opt/ros/jazzy/setup.bash`).
*   **Espacio de trabajo:** Montado en la ruta limpia `/home/ros/ros2_ws` dentro del contenedor.

---

## 🚀 Configuración de Gráficos (GPU) y Pantalla

El contenedor está configurado por defecto para utilizar aceleración gráfica por hardware. Dependiendo del hardware de tu máquina anfitriona (host), sigue una de estas configuraciones:

### Opción A: Tarjeta Gráfica NVIDIA (Configuración Activa)

Si tienes una GPU NVIDIA dedicada, el contenedor ya viene configurado para usarla. 

#### Requisitos en el Host:
1. Driver de NVIDIA ([guía de Ubuntu](https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/)) y **NVIDIA Container Toolkit** ([instalación](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)).
2. El contenedor pide la GPU por **CDI** (`"--device", "nvidia.com/gpu=all"` en `runArgs`), así que hay que generar la spec ([CDI](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html)) y configurar Docker:
   ```bash
   sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```
   Se usa CDI y no `--gpus all` porque con Docker 29 `--gpus all` pide todos los fabricantes y falla (`AMD CDI spec not found`) si el PC tiene además una GPU AMD integrada. Tras actualizar el driver, vuelve a generar la spec.

---

### Opción B: Gráficas AMD / Intel (Integradas o Dedicadas)

Si no tienes una GPU NVIDIA dedicada y deseas usar la gráfica integrada de tu procesador (AMD Radeon / Intel Iris/UHD) o una GPU AMD dedicada:

1. Abre el archivo [.devcontainer/devcontainer.json](file:///.devcontainer/devcontainer.json).
2. En la sección `"runArgs"`, busca y reemplaza las líneas de NVIDIA:
   ```json
   "--gpus",
   "all"
   ```
   por la asignación directa de aceleración Mesa/DRI de tu host:
   ```json
   "--device",
   "/dev/dri:/dev/dri"
   ```
3. Reconstruye el contenedor desde la paleta de comandos de VS Code (`Ctrl + Shift + P` -> `Dev Containers: Rebuild Container`).

---

## 🛠️ Qué se monta y qué se ve dentro del contenedor

Del repo **solo se monta `ros2_ws/`**, como `/home/ros/ros2_ws`. Los archivos de infraestructura (Dockerfile, `.devcontainer/`, este README) son cosa del host y **no existen dentro del contenedor**: se usan para construirlo, no para trabajar dentro.

Consecuencia práctica: el único repo Git visible desde la sesión del contenedor es `src/sentinel_ros_pkgs`, que es justo donde se trabaja. Para tocar la configuración del contenedor hay que abrir esta carpeta en el host, no dentro.

Además se ocultan del explorador de VS Code los artefactos de compilación, que no aportan nada y ensucian la búsqueda — sección `"settings"` de [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json):
```json
"files.exclude": {
    "build": true,
    "install": true,
    "log": true
}
```

## 🔌 Preparar el host: la red con el Quest

Lo que no puede vivir en el contenedor (red, USB, NetworkManager) está en [`host/`](host/README.md), versionado aquí para que un PC nuevo quede listo con un comando, una sola vez:

```bash
host/install.sh        # como tu usuario; pide sudo solo para lo del sistema
host/quest-status.sh   # diagnóstico
```

Deja que conectar el Quest por USB-C baste: el casco pasa solo a modo red (CDC-NCM) y el PC queda en `192.168.42.1`, con DHCP, DNS y NAT de NetworkManager. Como el contenedor usa `--network=host`, ROS ve esa red tal cual.

## 🚦 Comprobar que el entorno funciona

Dentro del contenedor, tras *Reopen in Container*:

```bash
cd ~/ros2_ws && colcon build --symlink-install && source install/setup.bash
ros2 launch sentinel_description display.launch.py
```

Si se abre RViz con el robot, el entorno está bien: hay ROS, hay GPU y hay X11. Si RViz no abre, lo primero que hay que mirar es la configuración de GPU de la sección anterior y que el `initializeCommand` (`xhost +local:`) se haya ejecutado en el host.
