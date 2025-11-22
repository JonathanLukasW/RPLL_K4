import os

# ====== SETTINGS ======

include_files = True
include_folders = True
deep_scan = True

output_file = "tree_dump.txt"

# Exclusions (edit freely)
exclude_folders = {
".git"
}

exclude_files = {
}

exclude_extensions = {
}

# =======================

def should_skip_folder(folder_name):
    return folder_name in exclude_folders

def should_skip_file(file_name):
    if file_name in exclude_files:
        return True
    _, ext = os.path.splitext(file_name)
    return ext in exclude_extensions

def generate_tree(path, indent=0):
    lines = []
    try:
        items = sorted(os.listdir(path))
    except PermissionError:
        return [f"{' ' * indent}!! [ACCESS DENIED] {path}"]

    for item in items:
        full_path = os.path.join(path, item)
        prefix = " " * indent

        if os.path.isdir(full_path):
            if should_skip_folder(item):
                continue

            if include_folders:
                lines.append(f"{prefix}[DIR]  {item}/")

            if deep_scan:
                lines.extend(generate_tree(full_path, indent + 4))

        else:
            if should_skip_file(item):
                continue
            
            if include_files:
                lines.append(f"{prefix}- {item}")

    return lines


if __name__ == "__main__":
    start_path = os.getcwd()

    tree_lines = [
        "=== PROJECT TREE DUMP ===",
        f"Root Path: {start_path}",
        ""
    ]

    tree_lines.extend(generate_tree(start_path))

    with open(output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(tree_lines))

    print(f"Done → {output_file}")
