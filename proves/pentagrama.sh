#!/bin/bash
# Dibuixa pentagrames de mostra a build/pentagrama.png, al Mac, sense telèfon ni simulador.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -parse-as-library -o build/prova-pentagrama Clau/Music.swift Clau/Course.swift Clau/Rhythm.swift Clau/Theme.swift Clau/StaffView.swift proves/pentagrama.swift 2>&1 | grep -v "warning" || true
./build/prova-pentagrama
