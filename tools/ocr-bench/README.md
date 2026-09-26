# OCR bench

Synthetic Khan-style handwriting (six letters, neat and shaky) rendered like the app's OCR page and read with the app's Vision settings. Scores whether each line reads back as the same equation.

    cp ../../App/Ink/LinearAlgebra.swift ../../App/Ink/MathNormalizer.swift .
    swiftc -O main.swift LinearAlgebra.swift MathNormalizer.swift -o bench && ./bench all

Result that set `InkDocument.ocrStrokeScale = 2.2`: 58% of lines before, 100% with 2.2x strokes plus `MathNormalizer.repairLookalikes`.
