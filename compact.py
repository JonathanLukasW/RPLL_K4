import os
import re
import sys

def compact_file(input_path):
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"File not found: {input_path}")

    # split filename and extension
    base, _ = os.path.splitext(input_path)
    output_path = f"{base}_compact.txt"

    with open(input_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    compacted = []
    for line in lines:
        stripped = line.strip()
        if stripped:
            stripped = re.sub(r"\s+", " ", stripped)
            compacted.append(stripped)

    final = "".join(compacted)

    with open(output_path, "w", encoding="utf-8") as out:
        out.write(final)

    print(f"Done. Compacted file saved to: {output_path}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 compact.py <input_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    compact_file(input_file)
