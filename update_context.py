#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path
import xml.etree.ElementTree as ET
import argparse


def get_git_root():
    """Get the root directory of the git repository."""
    try:
        git_root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"])
        return git_root.decode("utf-8").strip()
    except subprocess.CalledProcessError:
        raise Exception("Not a git repository")


def should_include_file(file_path, max_size_kb=100, include_tests=False, include_addons=False):
    """Check if file should be included based on size and path."""
    # Skip files larger than max_size_kb
    if file_path.stat().st_size > (max_size_kb * 1024):
        print(f"Skipping {file_path}: exceeds {max_size_kb}KB size limit")
        return False
        
    # Skip test files unless specifically requested
    if "tests" in file_path.parts and not include_tests:
        return False
        
    # Skip addons unless specifically requested
    if "addons" in file_path.parts and not include_addons:
        return False
        
    return True


def find_godot_files(root_dir, include_scenes=True, include_tests=False, include_addons=False, max_size_kb=100):
    """Find relevant Godot files."""
    files = []
    
    # Always include GDScript files
    files.extend(Path(root_dir).rglob("*.gd"))
    
    # Optionally include scene files
    if include_scenes:
        files.extend(Path(root_dir).rglob("*.tscn"))
    
    # Filter files based on size and path criteria
    return [f for f in files if should_include_file(f, max_size_kb, include_tests, include_addons)]


def create_xml_document(files, root_dir):
    """Create XML document structure for Claude context."""
    root = ET.Element("documents")

    for i, file_path in enumerate(files, 1):
        # Create document element
        doc = ET.SubElement(root, "document", index=str(i))

        # Add source (relative path from git root)
        source = ET.SubElement(doc, "source")
        rel_path = os.path.relpath(file_path, root_dir)
        source.text = rel_path

        # Add content
        content = ET.SubElement(doc, "document_content")
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content.text = f.read()
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            content.text = f"Error reading file: {e}"

    return root


def main():
    parser = argparse.ArgumentParser(description="Update Claude project context")
    parser.add_argument(
        "--output",
        "-o",
        default="claude_context.xml",
        help="Output XML file (default: claude_context.xml)",
    )
    parser.add_argument(
        "--scenes",
        "-s",
        action="store_true",
        help="Include scene (.tscn) files",
    )
    parser.add_argument(
        "--tests",
        "-t",
        action="store_true",
        help="Include files from test directories",
    )
    parser.add_argument(
        "--addons",
        "-a",
        action="store_true",
        help="Include files from addon directories",
    )
    parser.add_argument(
        "--max-size",
        "-m",
        type=int,
        default=100,
        help="Maximum file size in KB (default: 100)",
    )
    args = parser.parse_args()

    try:
        # Get git root
        root_dir = get_git_root()

        # Find relevant files
        files = find_godot_files(
            root_dir, 
            include_scenes=args.scenes, 
            include_tests=args.tests,
            include_addons=args.addons,
            max_size_kb=args.max_size
        )

        # Create XML structure
        root = create_xml_document(files, root_dir)

        # Write to file with proper XML formatting
        tree = ET.ElementTree(root)
        ET.indent(tree, space="  ")
        tree.write(args.output, encoding="utf-8", xml_declaration=True)

        print(f"Successfully created {args.output} with {len(files)} files")

    except Exception as e:
        print(f"Error: {e}")
        return 1

    return 0


if __name__ == "__main__":
    exit(main())