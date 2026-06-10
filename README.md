# ROS 2 Jazzy Desktop + Gazebo Harmonic (DevContainer)

Este repositorio contiene la configuración de un **DevContainer** listo para usar con ROS 2 Jazzy y simulación en Gazebo Harmonic, optimizado para aceleración por hardware (GPU) y entornos visuales (RViz2, Gazebo, etc.).

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
1. Asegúrate de tener instalado el driver de NVIDIA y el **NVIDIA Container Toolkit**.
2. despues ejecute estos comandos en la terminal:
   ```bash
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```
3. En [.devcontainer/devcontainer.json](file:///.devcontainer/devcontainer.json), la sección `runArgs` debe mantener la directiva:
   ```json
   "--gpus", "all"
   ```

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

## 🛠️ Estructura y Visualización en VS Code

Para mantener el entorno limpio, los archivos de configuración del contenedor están ocultos en el explorador de archivos de VS Code dentro de la sesión del contenedor (aunque siguen estando en la carpeta raíz en tu host).

Esta visualización se controla mediante la sección `"settings"` en [.devcontainer/devcontainer.json](file:///.devcontainer/devcontainer.json):
```json
"files.exclude": {
    "**/.devcontainer": true,
    "**/Dockerfile": true,
    "**/devcontainer.json": true
}
```
Si alguna vez necesitas modificarlos dentro del contenedor, puedes agregarlos temporalmente comentando estas líneas en la configuración o abriéndolos usando el buscador de archivos de VS Code (`Ctrl + P`).
