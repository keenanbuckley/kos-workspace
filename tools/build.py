#!/usr/bin/env python3
"""
Package Builder Script for kOS Archives

This script is responsible for building self-contained kOS packages from source.
It reads package configurations from a central 'manifest.yaml', manages
directories, copies scripts, resolves cross-script dependencies (library
functions), and generates final boot scripts for deployment.

The build process for each package involves:
1. Clearing and creating the necessary 'build' subdirectories.
2. Copying the main boot script.
3. Recursively processing 'offline_scripts' to identify and extract library
   functions (cross-dependencies) into a dedicated library file.
4. Generating simple 'online_scripts' wrappers.
5. Saving persistent state information (if configured).
6. Generating the final initial boot file that calls the installer.

It relies on external functions for dependency resolution:
- refactor_script_for_cross_dependencies
- collect_library_functions
"""
import os
import shutil
import yaml
import re
from pathlib import Path

# Assuming these functions are available in a 'dependencies' module
from dependencies import (
    refactor_script_for_cross_dependencies,
    collect_library_functions,
    extract_kos_global_parameters,
)

# --- Configuration Constants (Derived from Script Location) ---
# ARCHIVE: The root directory of the entire project archive (two levels up from this script)
ARCHIVE = Path(__file__).resolve().parents[1]
SRC = ARCHIVE / "src"
BUILD = ARCHIVE / "build"
BOOT = ARCHIVE / "boot"

# Path to the main installer script used by the generated boot files
INSTALLER = SRC / "pacman" / "install.ks"
# Path to the package manifest file
MANIFEST = ARCHIVE / "manifest.yaml"


def load_manifest() -> dict:
    """
    Loads and parses the package configurations from the manifest file.

    Returns:
        dict: A dictionary containing all defined packages and their configurations.
    """
    print(f"Loading manifest from: {MANIFEST.relative_to(ARCHIVE)}")
    with open(MANIFEST, "r", encoding="utf-8") as f:
        # We assume the top level key is 'packages'
        return yaml.safe_load(f)["packages"]


def copy_script(src: Path, dst: Path) -> None:
    """
    Copies a kOS script file from source to destination, creating parent
    directories if they do not exist.

    Args:
        src (Path): The source path of the script.
        dst (Path): The destination path of the script.
    """
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    # Read/write using Path methods for simplicity
    text = src.read_text(encoding="utf-8")
    dst.write_text(text, encoding="utf-8")


def build_package(name: str, cfg: dict) -> None:
    """
    Builds a single kOS package based on its manifest configuration.

    The process includes directory setup, file copying, dependency resolution,
    library creation, and final boot script generation.

    Args:
        name (str): The name of the package (e.g., 'main_system').
        cfg (dict): The configuration dictionary for this package.
    """
    # --- 1. Define Package Paths ---
    package_root = BUILD / name
    boot_dir = package_root / "boot"
    lib_dir = package_root / "lib"
    offline_scripts_dir = package_root / "offline_scripts"
    online_scripts_dir = package_root / "online_scripts"

    # Destination for the main boot script copy
    boot_dst = boot_dir / "default.ks"

    # Destination for the generated library file containing all dependencies
    lib_name = f"{name}_lib"
    lib_dst = lib_dir / f"{lib_name}.ks"

    # --- 2. Initialize Build Folders ---
    for path in [
        package_root,
        boot_dir,
        lib_dir,
        offline_scripts_dir,
        online_scripts_dir,
    ]:
        # Clean up existing build folder for fresh build
        if path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True)

    # Load and define config variables
    cfg_version: str = cfg.get("version", "0.0.1")
    cfg_compile: bool = cfg.get("compile", False)

    print(f"\n{'=' * 5} Building {name} v{cfg_version} {'=' * 5}")

    # --- 3. Copy Main Boot Script ---
    # The cfg_boot_path is a kOS path (e.g., "0:/src/boot/myboot.ks").
    cfg_boot_path: str = cfg.get("boot")
    # [3:] strips "0:/" to get the relative archive path.
    source_boot_path = ARCHIVE / cfg_boot_path[3:]
    copy_script(source_boot_path, boot_dst)

    print(f"--- {cfg_boot_path} ---")
    print(f"Wrote default boot script to: {boot_dst.relative_to(ARCHIVE)}")
    print()

    # --- 4. Process Offline Scripts and Resolve Dependencies ---

    # Paths to scripts that need to be processed
    scripts_to_process = set(cfg.get("offline_scripts", []))
    # Paths already successfully processed
    processed_scripts = set()
    # Dictionary to hold unique function strings extracted from all scripts
    full_library_functions = dict()

    # Loop continues until all scripts, including newly discovered dependencies,
    # have been processed.
    while scripts_to_process - processed_scripts:
        # Iterate only over scripts not yet processed
        for script_path_kos in scripts_to_process - processed_scripts:
            # [3:] strips "0:/" to get the relative archive path.
            source_script_path = ARCHIVE / script_path_kos[3:]
            script_content = source_script_path.read_text(encoding="utf-8")

            # Refactor the script to resolve internal calls (RUNPATH, RUNONCEPATH)
            # The refactoring extracts library dependencies and modifies script calls.
            modified_script, library_paths, script_paths = (
                refactor_script_for_cross_dependencies(script_content, lib_name)
            )

            # Add any newly discovered script dependencies (from RUNPATH/RUNONCEPATH calls)
            # to the set to be processed in future iterations.
            scripts_to_process.update(script_paths)

            # Collect unique library functions from the modified script content.
            library_functions = collect_library_functions(
                modified_script, library_paths, ARCHIVE
            )
            # Merge collected functions into the master list of all library functions.
            full_library_functions.update(library_functions)

            # Define the destination path for the processed script
            # (maintaining only the stem, and placing it in the offline directory)
            script_dst = Path(offline_scripts_dir) / f"{source_script_path.stem}.ks"
            script_dst.write_text(modified_script, encoding="utf-8")

            # Mark the current script as processed
            processed_scripts.add(script_path_kos)

            print(f"--- {script_path_kos} ---")
            print("libs found:", library_paths)
            print("scripts found:", script_paths)
            print("functions extracted:", set(library_functions.keys()))
            print(f"Wrote offline script to: {script_dst.relative_to(ARCHIVE)}")
            print()

    # --- 5. Build Library File ---
    # Create the library script content by combining all unique extracted functions.
    library_content = f"// {lib_name} - Generated library script\n@lazyGlobal off.\n\n"

    # Functions are reversed to ensure functions called by others are defined earlier.
    for function_string in reversed(full_library_functions.values()):
        library_content += function_string + "\n\n"

    lib_dst.write_text(library_content, encoding="utf-8")

    print(f"--- {lib_name}.ks ---")
    print("total functions:", set(full_library_functions.keys()))
    print(f"Wrote library script to: {lib_dst.relative_to(ARCHIVE)}")
    print()

    # --- 6. Generate Online Scripts (Simple Wrappers) ---
    for script_path_kos in cfg.get("online_scripts", []):
        parameter_definitions = extract_kos_global_parameters(
            (ARCHIVE / script_path_kos[3:]).read_text()
        )

        param_list = ""
        script_content = ""
        for param_def in parameter_definitions:
            script_content += param_def + "\n"
            match = re.search(
                r"^\s*(declare\s+parameter|parameter)\s+([\w.]+)",
                param_def,
                re.IGNORECASE,
            )
            if match:
                # The capture group 2 is the parameter name
                param_list += ", " + match.group(2)
                if param_list[-1] == ".":
                    param_list = param_list[:-1]

        # Online scripts are simple wrappers that call the original script path.
        script_content += f'runPath("{script_path_kos}"{param_list}).\n'

        # Get the stem (filename without extension) from the kOS path
        script_stem = Path(script_path_kos[3:]).stem
        script_dst = Path(online_scripts_dir) / f"{script_stem}.ks"

        script_dst.write_text(script_content, encoding="utf-8")

        print(f"--- {script_path_kos} ---")
        print(f"Wrote online script wrapper to: {script_dst.relative_to(ARCHIVE)}")
        print()

    # --- 7. Add Persistent State (if required) ---
    if cfg.get("persistent_data"):
        package_state_content = """
{
    "entries": [
        {
            "value": "package",
            "$type": "kOS.Safe.Encapsulation.StringValue"
        },
        {
            "value": "PACKAGE",
            "$type": "kOS.Safe.Encapsulation.StringValue"
        },
        {
            "value": "version",
            "$type": "kOS.Safe.Encapsulation.StringValue"
        },
        {
            "value": "VERSION",
            "$type": "kOS.Safe.Encapsulation.StringValue"
        }
    ],
    "$type": "kOS.Safe.Encapsulation.Lexicon"
}
"""
        package_state_content = package_state_content.replace("PACKAGE", name)
        package_state_content = package_state_content.replace("VERSION", cfg_version)
        state_file = package_root / "state.json"
        state_file.write_text(package_state_content)

        print(f"Wrote state file to: {state_file.relative_to(ARCHIVE)}")

    # --- 8. Create Initial Boot Script ---
    # This is the script the user runs to start the installation process.
    boot_name = cfg.get("boot_name", f"boot_{name}.ks")
    boot_file = BOOT / boot_name

    # This boot script executes the main installer script with package parameters.
    boot_file.write_text(
        f"// Auto-generated initial boot script for {name}\n"
        f'print "Booting installer for {name} (v{cfg_version})...".\n'
        # Arguments: package_name, version, compile_flag (lowercase string)
        f'runpath("{INSTALLER.as_posix().replace(str(ARCHIVE.as_posix()), "0:")}", "{name}", {str(cfg_compile).lower()}, true).\n',
        encoding="utf-8",
    )

    print(f"--- 0:/boot/{boot_name} ---")
    print(f"Wrote initial boot script to: {boot_file.relative_to(ARCHIVE)}")
    print()

    print(f"=== Finished building {name} v{cfg_version} ===")
    print(f"Build output path: {package_root.relative_to(ARCHIVE)}")


def main() -> None:
    """
    Main execution function. Loads the manifest and iterates over packages
    to initiate the build process for each one.
    """
    try:
        packages = load_manifest()
        for name, cfg in packages.items():
            build_package(name, cfg)
        print("\nBuild complete.")
    except Exception as e:
        print(f"\nERROR: An unexpected error occurred during the build: {e}")
        raise


if __name__ == "__main__":
    main()
