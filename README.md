Toolbox Visual Studio Code integration
======================================

This repository is intended for scripts and hooks to integrate [Toolbox](https://github.com/containers/toolbox) with [Visual Studio Code](https://code.visualstudio.com).

In particular, it provides a `code.sh` script that:
 * If necessary, prompts to install the Flatpak of Visual Studio Code
 * If necessary, configures the current toolbox container to work with the [Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) Visual Studio Code extension.
 * Opens a VSCode window using the remaining command line arguments

Installation
------------

```
git clone https://github.com/owtaylor/toolbox-vscode.git
cd toolbox-vscode
[ -d ~/.local/bin ] || mkdir ~/.local/bin
ln -s "$PWD/code.sh" ~/.local/bin/code
```

Usage
-----

```
toolbox enter
cd ~/Source/myproject
code .
```

To recreate the container configuration (perhaps after updating this repository)

```
code --toolbox-reset-configuration .
```

Credits
-------
The configuration that `code.sh` sets up was largely figured out by Laércio de Sousa ([lbssousa](https://github.com/lbssousa))

Related issues
-----
* Request for Visual Studio Code support in Toolbox [containers/toolbox#628](https://github.com/containers/toolbox/issues/628)
* podman/docker should work out of the box in the Flatpak: [flathub/com.visualstudio.code#203](https://github.com/flathub/com.visualstudio.code/issues/203)
* Multiple invocations of the Flatpak should share a process without hacks: [flathub/com.visualstudio.code#210](https://github.com/flathub/com.visualstudio.code/issues/210)
* Ability customize the container name in the Visual Studio Code UI: [microsoft/vscode-remote-release#4053](https://github.com/microsoft/vscode-remote-release/issues/4053)
