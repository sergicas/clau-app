#!/bin/bash
# Prova el motor de Clau (sentir notes) al Mac, sense telèfon ni simulador.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -o build/prova-motor Clau/Music.swift Clau/Pitch.swift Clau/Course.swift Clau/Rhythm.swift proves/main.swift
./build/prova-motor
