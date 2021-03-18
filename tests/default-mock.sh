# shellcheck shell=bash

if match flatpak list --app --columns=application ; then
    echo com.visualstudio.code
    exit 0
fi

if match flatpak remotes --columns=name ; then
    echo flathub
    exit 0
fi

if match flatpak install flathub com.visualstudio.code ; then
    exit 0
fi

if match podman inspect toolbox-vscode-test \
         --format='{{ range .Config.Env }}{{ . }}{{"\n"}}{{ end }}' ; then
    echo "NAME=fedora-toolbox"
    echo "HOME=/root"
fi

if match flatpak ps --columns=instance,application ; then
    exit 0
fi

if match flatpak run @ ; then
    exit 0
fi

if match flatpak enter @ ; then
    exit 0
fi
