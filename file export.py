import os

folders = [
    "lib"
]

# allowed file types for folder scanning
allowed_ext = [".dart"]

# single files you want to include even if they're outside those folders
extra_files = [
    ".env",
    "pubspec.yaml",
	"AndroidManifest.xml"
]

output = ""

def dump_file(filepath):
    """Reads a single file and appends its content to output."""
    global output
    if os.path.exists(filepath):
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            output += f"\n\n=== FILE: {filepath} ===\n\n"
            output += f.read()

def scan_folder(folder):
    """Scan folder recursively for allowed file types."""
    for root, dirs, files in os.walk(folder):
        for file in files:
            if any(file.endswith(ext) for ext in allowed_ext):
                filepath = os.path.join(root, file)
                dump_file(filepath)

# scan all folder paths
for folder in folders:
    if os.path.exists(folder):
        scan_folder(folder)

# dump extra single files
for filepath in extra_files:
    dump_file(filepath)

# write final result
with open("project_dump.txt", "w", encoding="utf-8") as out:
    out.write(output)

print("Done → project_dump.txt")
