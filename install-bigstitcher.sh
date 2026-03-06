#!/bin/bash
# install-bigstitcher.sh
# Fresh installation of the BigStitcher environment on a new Ubuntu WSL.
# Run as your normal user (with sudo access) on a clean Ubuntu WSL instance.

set -e

echo "=== BigStitcher Environment Installation ==="
echo ""
echo "This script will install:"
echo "  1. System prerequisites (git, wget, unzip, cifs-utils)"
echo "  2. Java JDK 8 (Zulu 8.92 with JavaFX)"
echo "  3. Apache Maven 3.9.9"
echo "  4. BigStitcher-Spark (clone + build)"
echo "  5. FIJI"
echo "  6. Launch FIJI for BigStitcher plugin installation"
echo ""
echo "Note: Step 4 (Maven build) downloads many dependencies and may take 10-20 minutes."
echo ""
read -p "Press Enter to start or Ctrl+C to cancel..."


# --- Step 1: System prerequisites ---
echo ""
echo "[1/6] Installing system prerequisites..."
sudo apt update
sudo apt install -y git wget unzip cifs-utils
echo "Done."


# --- Step 2: Java JDK 8 (Zulu with JavaFX) ---
echo ""
echo "[2/6] Installing Java JDK 8 (Zulu)..."

JAVA_TAR="zulu8.92.0.21-ca-fx-jdk8.0.482-linux_x64.tar.gz"
JAVA_URL="https://cdn.azul.com/zulu/bin/$JAVA_TAR"
JAVA_EXTRACTED="zulu8.92.0.21-ca-fx-jdk8.0.482-linux_x64"

wget -q --show-progress -O "/tmp/$JAVA_TAR" "$JAVA_URL"
sudo mkdir -p /usr/lib/jvm
sudo tar -xzf "/tmp/$JAVA_TAR" -C /usr/lib/jvm
sudo ln -sfn "/usr/lib/jvm/$JAVA_EXTRACTED" /usr/lib/jvm/zulu-8
rm "/tmp/$JAVA_TAR"
echo "Done. Java installed at /usr/lib/jvm/zulu-8"


# --- Step 3: Apache Maven 3.9.9 ---
echo ""
echo "[3/6] Installing Apache Maven 3.9.9..."

MAVEN_VERSION="3.9.9"
MAVEN_TAR="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}"

wget -q --show-progress -O "/tmp/$MAVEN_TAR" "$MAVEN_URL"
sudo mkdir -p /opt/maven
sudo tar -xzf "/tmp/$MAVEN_TAR" -C /opt/maven --strip-components=1
rm "/tmp/$MAVEN_TAR"
echo "Done. Maven installed at /opt/maven"


# --- Step 4: Add Java and Maven to .bashrc ---
echo ""
echo "[4/6] Configuring .bashrc..."

cat >> ~/.bashrc << 'BASHRC'

# JAVA Paths
export JAVA_HOME="/usr/lib/jvm/zulu-8"
export PATH="$JAVA_HOME/bin:$PATH"

# Apache Maven Environment Variables
export MAVEN_HOME=/opt/maven
export M2_HOME=$MAVEN_HOME
export PATH=$MAVEN_HOME/bin:$PATH
BASHRC

# Also export for the current session so the build steps below work
export JAVA_HOME="/usr/lib/jvm/zulu-8"
export PATH="$JAVA_HOME/bin:$PATH"
export MAVEN_HOME=/opt/maven
export M2_HOME=$MAVEN_HOME
export PATH=$MAVEN_HOME/bin:$PATH

echo "Done."
echo "  java:  $(java -version 2>&1 | head -1)"
echo "  mvn:   $(mvn -version 2>&1 | head -1)"


# --- Step 5: Clone and build BigStitcher-Spark ---
echo ""
echo "[5/6] Cloning and building BigStitcher-Spark..."
echo "(This will take 10-20 minutes on first run — Maven downloads all dependencies)"
echo ""

mkdir -p ~/BigStitcher
git clone https://github.com/JaneliaSciComp/BigStitcher-Spark.git ~/BigStitcher/BigStitcher-Spark

cd ~/BigStitcher/BigStitcher-Spark
./install -t 40 -m 110

echo "Done. Executables installed in ~/BigStitcher/BigStitcher-Spark/"


# --- Step 6: Download and install FIJI ---
echo ""
echo "[6/6] Downloading FIJI..."

FIJI_ZIP="fiji-stable-linux64-jdk.zip"
FIJI_URL="https://downloads.imagej.net/fiji/stable/$FIJI_ZIP"

wget -q --show-progress -O "/tmp/$FIJI_ZIP" "$FIJI_URL"
mkdir -p ~/BigStitcher/FIJI
unzip -q "/tmp/$FIJI_ZIP" -d ~/BigStitcher/FIJI
rm "/tmp/$FIJI_ZIP"
echo "Done. FIJI installed at ~/BigStitcher/FIJI/Fiji.app/"


# --- Final: Launch FIJI for BigStitcher plugin installation ---
echo ""
echo "========================================================"
echo "  Installation complete!"
echo "========================================================"
echo ""
echo "Directory structure:"
echo "  ~/BigStitcher/BigStitcher-Spark/                ← BigStitcher-Spark executables"
echo "  ~/BigStitcher/BigStitcher-Spark_Keck_optimized/ ← Keck custom scripts"
echo "  ~/BigStitcher/FIJI/Fiji.app/                    ← FIJI"
echo ""
echo "=== FIJI: BigStitcher Plugin Installation ==="
echo ""
echo "FIJI will now open. Please install the BigStitcher plugin:"
echo "  1. Go to  Help > Update..."
echo "  2. Click  'Manage Update Sites'"
echo "  3. Find and check  'BigStitcher'"
echo "  4. Click  'Close', then 'Apply Changes'"
echo "  5. Restart FIJI when prompted"
echo ""
read -p "Press Enter to launch FIJI..."
~/BigStitcher/FIJI/Fiji.app/fiji-linux-x64
