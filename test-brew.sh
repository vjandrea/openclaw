#!/bin/bash
set -e
apt-get update && apt-get install -y build-essential curl file git
su node -c "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
