# Push-up model training

Push-ups are counted by two small Core ML models trained on pose recordings:

- **PushUpPhaseModel** looks at each camera frame and decides whether the body is
  at the top, at the bottom, moving between them, or not in push-up position at all.
- **PushUpRepModel** looks at each completed top → bottom → top cycle and decides
  whether it was a good rep or which form fault it had (too shallow, hips sagging,
  hips piked, from the knees, not a push-up).

Both models read the output of `LevelSet/Vision/PushUpFeatures.swift`. The app and the
trainer compile that same file, so the features can't drift. Until trained models are
in `LevelSet/Vision/Models/`, the app falls back to the old angle thresholds in
`PushUpClassifier.swift`.

## 1. Record sessions

In a **Debug** build, open Profile → Debug → Push-up training data → Record. The
recorder saves Vision pose keypoints only, never video.

For each session:

1. Enter your initials. The trainer uses them to test on people it didn't train on.
2. Pick what you're about to do, then tap **Start recording**.
3. Get into position and do the movement, then get up and tap **Stop recording**.
   Time spent walking to and from the phone is handled automatically.
4. Enter how many reps you did, counting bad ones too, and tap **Save**.

Keep each session to one kind of movement at a steady depth. The trainer finds reps
from the motion and only uses a session if it finds the same number you entered.

### What to record

Variety matters more than volume. Aim for at least:

| Label | Sessions per person | Notes |
| --- | --- | --- |
| Good push-ups | 6+ | 5–15 reps each. Mix slow and fast. |
| Too shallow | 2+ | Elbows only bend partway. |
| Hips sagging | 2+ | |
| Hips piked up | 2+ | |
| Knee push-ups | 2+ | |
| Not a push-up | 6+ | Standing, walking, waving arms, squats, holding a still plank, sitting near the phone. |

Across sessions, vary:

- **Camera angle:** side-on, 45°, head-on, phone on the floor and phone propped higher.
- **Distance:** fill the frame, and leave the body small.
- **Clothing and lighting:** baggy and fitted clothes, bright and dim rooms.
- **People:** three or more lets the trainer hold out a whole person for testing.
  Five or more gives a model that generalizes.

### Export

Tap **Export** in the recorder and AirDrop the files to your Mac. Put them in
`Training/data/`. Subfolders are fine. That folder is git-ignored because it holds
people's body data.

## 2. Train

Requires macOS with Xcode or the Command Line Tools. No Python needed.

```sh
Training/train.sh                 # reads Training/data, writes LevelSet/Vision/Models
Training/train.sh path/to/data out/dir
```

The trainer prints:

- each label's session count, and any session it excluded because the reps it found
  didn't match the count you entered (re-record those or fix the count);
- phase and rep model accuracy on held-out people (or held-out sessions, if fewer than
  three people recorded);
- **a rep-count comparison on held-out sessions between the trained model and the old
  heuristic.** Use this number to decide whether to ship the model.

It then retrains on all the data and writes `PushUpPhaseModel.mlmodel` and
`PushUpRepModel.mlmodel`.

## 3. Ship

Run `xcodegen generate` so the project picks up the new models, then build. The app
loads the models automatically. It ignores models built from a different
`PushUpFeatures.version`, so if you change the features, bump that version and retrain.
