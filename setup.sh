#!/bin/bash

# Configuration - Personnalisez ces listes selon vos besoins
BASIC_PACKAGES=(
    "build-essential"
    "git"
    "curl"
    "wget"
    "vim"
    "htop"
    "net-tools"
    "software-properties-common"
    "flatpak"           # Support Flatpak
    "kde-config-flatpak" # Interface KDE pour Flatpak
    "snapd"             # Support Snap
)

DEV_PACKAGES=(
    "pkg-config"
    "automake"
    "make"
    "autoconf"
    "libtool"
    "cmake"
    "python3-pip"
    "nodejs"
    "npm"
    "clang-format"      # Outil de formatage de code C/C++
)

# Paquets pour GL4D et autres bibliothèques graphiques/système
GRAPHICS_PACKAGES=(
    "libsdl2-dev"
    "libsdl2-image-dev"
    "libsdl2-mixer-dev"
    "libsdl2-ttf-dev"
    "libassimp-dev"
    "libfftw3-dev"
    "fluid-soundfont-gm"
    "libasound2-dev"
    "libx11-dev"
    "libxrandr-dev"
    "libxi-dev"
    "libgl1-mesa-dev"
    "libglu1-mesa-dev"
    "libxcursor-dev"
    "libxinerama-dev"
    "libwayland-dev"
    "libxkbcommon-dev"
)

# Applications via apt
APPS=(
    "emacs"
    "flameshot"   # Outil de capture d'écran
    "yakuake"     # Terminal déroulant pour KDE
    # Ajoutez vos applications préférées ici
)

# Applications via Flatpak
FLATPAK_APPS=(
    "com.github.johnfactotum.Foliate"  # Lecteur de livres électroniques Foliate
    "org.librepcb.LibrePCB"            # Conception de circuits imprimés
    "org.kde.kamoso"                   # Application de webcam pour KDE
    "org.mapeditor.Tiled"              # Éditeur de tuiles pour jeux
    "org.kde.kolourpaint"              # Application simple de dessin
    "com.snes9x.Snes9x"                # Émulateur SNES
    "org.gabmus.savedesktop"           # Sauvegarde des configurations de bureau
    "org.kde.filelight"                # Visualiseur d'utilisation du disque
    "com.obsproject.Studio"            # OBS Studio - Streaming et enregistrement
    # Ajoutez d'autres applications Flatpak ici
)

# Applications à télécharger et installer depuis GitHub (.deb)
declare -A DEB_PACKAGES=(
    ["fastfetch"]="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb"
    # Ajoutez d'autres paquets .deb ici au format ["nom"]="url"
)


# Vérification des droits d'administration
if [ "$EUID" -ne 0 ]; then 
    echo "Ce script doit être exécuté en tant qu'administrateur"
    echo "Veuillez utiliser sudo ./setup.sh"
    exit 1
fi

# Fonction pour vérifier les erreurs
check_error() {
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'exécution de la dernière commande"
        echo "Commande échouée : $BASH_COMMAND"
        exit 1
    fi
}

# Fonction pour afficher les sections
print_section() {
    echo ""
    echo "====================================="
    echo "$1"
    echo "====================================="
}

# Mise à jour initiale du système
print_section "Mise à jour du système"
apt update -qq && apt upgrade -y
check_error

# Installation des paquets de base
print_section "Installation des paquets de base"
apt install -y "${BASIC_PACKAGES[@]}"
check_error

# Installation des paquets de développement
print_section "Installation des paquets de développement"
apt install -y "${DEV_PACKAGES[@]}"
check_error

# Installation des paquets graphiques
print_section "Installation des paquets graphiques"
apt install -y "${GRAPHICS_PACKAGES[@]}"
check_error

# Installation des applications apt
print_section "Installation des applications (apt)"
apt install -y "${APPS[@]}"
check_error

# Installation de Rust
print_section "Installation de Rust"
RUST_TEMP_SCRIPT=$(mktemp)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > "$RUST_TEMP_SCRIPT"
if [ $? -ne 0 ]; then
    echo "Erreur: Impossible de télécharger le script d'installation de Rust"
else
    # Installer Rust pour l'utilisateur réel (pas root)
    REAL_USER=$(logname)
    REAL_HOME=$(eval echo ~$REAL_USER)
    
    echo "Installation de Rust pour l'utilisateur $REAL_USER..."
    # Exécuter le script avec les options par défaut (-y)
    su - $REAL_USER -c "sh $RUST_TEMP_SCRIPT -y"
    
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'installation de Rust"
    else
        echo "Rust installé avec succès!"
        echo "Ajout des variables d'environnement Rust à .bashrc..."
        # Vérifier si le chemin Cargo est déjà dans .bashrc
        if ! grep -q "/.cargo/env" "$REAL_HOME/.bashrc"; then
            echo -e "\n# Rust\nsource \"$REAL_HOME/.cargo/env\"" >> "$REAL_HOME/.bashrc"
        fi
    fi
    rm "$RUST_TEMP_SCRIPT"
fi

# Configuration de Flatpak
print_section "Configuration de Flatpak"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
check_error

# Installation des applications Flatpak
if [ ${#FLATPAK_APPS[@]} -gt 0 ]; then
    print_section "Installation des applications Flatpak"
    for app in "${FLATPAK_APPS[@]}"; do
        echo "Installation de $app..."
        flatpak install -y flathub "$app"
        if [ $? -ne 0 ]; then
            echo "Avertissement: Impossible d'installer $app via Flatpak"
        fi
    done
fi

# Installation des applications Snap
if [ ${#SNAP_APPS[@]} -gt 0 ]; then
    print_section "Installation des applications Snap"
    # S'assurer que le service snapd est démarré
    systemctl enable --now snapd.socket
    check_error
    
    # Attendre que le socket snap soit disponible
    sleep 2
    
    for app in "${SNAP_APPS[@]}"; do
        echo "Installation de $app..."
        snap install $app
        if [ $? -ne 0 ]; then
            echo "Avertissement: Impossible d'installer $app via Snap"
        fi
    done
fi

# Configuration des variables d'environnement
print_section "Configuration des variables d'environnement"
REAL_USER=$(logname)
REAL_HOME=$(eval echo ~$REAL_USER)

if ! grep -q "# Configuration personnalisée" "$REAL_HOME/.bashrc"; then
    cat >> "$REAL_HOME/.bashrc" << 'EOL'

# Configuration personnalisée
export PATH=$PATH:/usr/local/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

# Alias utiles
alias ll='ls -la'
alias update='sudo apt update && sudo apt upgrade -y'
alias maj='sudo apt update && sudo apt dist-upgrade'
alias clean='sudo apt autoremove -y && sudo apt clean'
EOL
    check_error
fi

# Mise à jour du cache des bibliothèques
ldconfig
check_error

# Installation des paquets .deb depuis GitHub
if [ ${#DEB_PACKAGES[@]} -gt 0 ]; then
    print_section "Installation des paquets .deb depuis GitHub"
    # Créer un répertoire temporaire pour les téléchargements
    DEB_TEMP_DIR=$(mktemp -d)
    
    for pkg_name in "${!DEB_PACKAGES[@]}"; do
        pkg_url="${DEB_PACKAGES[$pkg_name]}"
        echo "Téléchargement et installation de $pkg_name..."
        
        # Télécharger le paquet
        wget -q --show-progress -O "$DEB_TEMP_DIR/$pkg_name.deb" "$pkg_url"
        if [ $? -ne 0 ]; then
            echo "Erreur: Impossible de télécharger $pkg_name depuis $pkg_url"
            continue
        fi
        
        # Installer le paquet
        dpkg -i "$DEB_TEMP_DIR/$pkg_name.deb"
        if [ $? -ne 0 ]; then
            echo "Installation des dépendances manquantes..."
            apt --fix-broken install -y
            dpkg -i "$DEB_TEMP_DIR/$pkg_name.deb"
            if [ $? -ne 0 ]; then
                echo "Erreur: Impossible d'installer $pkg_name"
                continue
            fi
        fi
        
        echo "$pkg_name installé avec succès!"
    done
    
    # Nettoyer les fichiers temporaires
    rm -rf "$DEB_TEMP_DIR"
fi

# Nettoyage final
print_section "Nettoyage final"
apt autoremove -y
apt clean

print_section "Installation terminée avec succès!"
echo "Pour appliquer les changements d'environnement, veuillez exécuter:"
echo "source ~/.bashrc"
