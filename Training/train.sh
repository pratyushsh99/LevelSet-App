#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

mkdir -p .build
swiftc -O \
    LevelSet/Vision/PoseFrame.swift \
    LevelSet/Vision/PoseGeometry.swift \
    LevelSet/Vision/PushUpRecording.swift \
    LevelSet/Vision/PushUpFeatures.swift \
    LevelSet/Vision/PushUpClassifier.swift \
    LevelSet/Vision/PushUpModelClassifier.swift \
    Training/PushUpTrainer/*.swift \
    -o .build/pushup-trainer

.build/pushup-trainer "${1:-Training/data}" "${2:-LevelSet/Vision/Models}"
