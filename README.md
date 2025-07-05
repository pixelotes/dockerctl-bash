# dockerctl - Interactive Docker Container Management

`dockerctl` is a command-line script designed for interactive management of Docker containers. It simplifies common Docker operations by providing an easy-to-use, menu-driven interface.

## Why bash, you madman?

The primary goal for `dockerctl` was to create a simple and portable script. Using Bash shell scripting means:
* **No Compilation Needed:** The script can be run directly on any system with Bash, without requiring a compilation step.
* **Broad Compatibility:** Bash is available by default on most Linux and macOS systems, and can be easily installed on Windows (e.g., via WSL or Git Bash), making the script usable across different architectures and operating systems with minimal setup.
* **Lightweight:** Bash scripts are generally lightweight and have minimal dependencies beyond what's typically available on a system where Docker is running.

This approach prioritizes ease of use and broad accessibility.

## Features

* **Interactive Container Selection:** Uses `fzf` for fuzzy searching and selecting from a list of running containers.
* **Container Actions:** Perform common operations on the selected container:
    * Stop
    * Restart
    * View logs (with options for tailing, showing last N lines, or all logs)
    * Execute a shell (`bash` or `sh`)
    * Execute a custom command
    * Export containers
    * Create images
* **Dependency Checks:** Verifies that `docker` and `fzf` are installed and that the Docker daemon is running.
* **User-Friendly Output:** Uses colors to differentiate messages (errors, warnings, success).

## Requirements

* **Docker:** The Docker engine must be installed and the daemon running.
* **fzf:** The command-line fuzzy finder `fzf` must be installed and available in your PATH.
    * Installation instructions: [https://github.com/junegunn/fzf#installation](https://github.com/junegunn/fzf#installation)

## Installation

1.  Save the script to a file, for example, `dockerctl.sh`.
2.  Make it executable:
    ```bash
    chmod +x dockerctl.sh
    ```
3.  (Optional) Move it to a directory in your PATH to make it accessible from anywhere, e.g.:
    ```bash
    sudo mv dockerctl.sh /usr/local/bin/dockerctl
    ```

## Usage

Run the script from your terminal:

```bash
./dockerctl.sh
```

## Roadmap
I'm not going to add many features, as I want to keep this script manageable.
Anyways, here are some possible enhancement I'd like to add:

- [ ] Add a key to toggle between active and stopped containers
- [ ] Port this script to bashly
- [X] Show container port mappings
- [X] Show container volumes
- [X] Show container network info
- [X] Ability to export a container
- [X] Ability to create a new image from the container

## License
This project is published under the [MIT license](LICENSE).
