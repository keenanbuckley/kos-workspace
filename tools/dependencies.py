#!/usr/bin/env python3
"""
kOS Dependency Resolver and Refactoring Utilities

This module contains functions essential for the kOS package build process,
specifically handling script refactoring, function extraction, and transitive
dependency resolution across kOS library files.

Key responsibilities:
1. Rewriting kOS script paths to point to their final location within the built package.
2. Robustly extracting function definitions from kOS scripts while ignoring comments.
3. Performing a Breadth-First Search (BFS) to identify all necessary library
   functions (including those called indirectly) for a given script.
"""
import re
from typing import Dict, Set, Tuple, List
from pathlib import Path


def refactor_script_for_cross_dependencies(
    script_content: str, lib_name: str
) -> Tuple[str, Set[str], Set[str]]:
    """
    Refactors kOS script content by finding all cross-script execution calls
    (RUNONCEPATH, RUNPATH) and replacing their absolute source paths with
    normalized, package-relative destination paths.

    Args:
        script_content: The kOS script string to refactor.
        lib_name: The name assigned to the consolidated library file (e.g., 'system_lib').

    Returns:
        A tuple containing:
        1. modified_script_string: The script with normalized paths.
        2. library_paths_set: The original source paths of all libraries (RUNONCEPATH calls).
        3. script_paths_set: The original source paths of all scripts (RUNPATH calls).
    """
    modified_script = script_content
    library_paths: Set[str] = set()
    script_paths: Set[str] = set()

    # --- 1. Handle runoncepath calls (Libraries) ---
    # Libraries are consolidated into a single file and the call is redirected.
    # Pattern explanation:
    # (1:command): Captures 'runoncepath' (case-insensitive)
    # (2:open_quote): Captures ' or "
    # (3:path): Captures the original path (e.g., "0:/lib/utils.ks")
    # \2: Matches the closing quote captured by group 2
    # (4:remaining_args): Captures any arguments following the path, including the comma.
    lib_pattern = re.compile(
        r"(runoncepath)\s*\(([\"'])(.*?)\2([^)]*)\)", re.IGNORECASE
    )

    # Find and collect all original library source paths
    for match in lib_pattern.finditer(modified_script):
        original_path = match.group(3).strip()
        if original_path:
            library_paths.add(original_path)

    # Define the replacement logic: Redirect all RUNONCEPATH calls to the new,
    # consolidated library file, preserving any arguments.
    def lib_replacer(match: re.Match) -> str:
        command = match.group(1)
        # Group 4 contains everything after the path's closing quote (e.g., ", arg1, arg2")
        remaining_args = match.group(4).strip()
        # New target path is always "1:/lib/{lib_name}" (package-relative)
        return f'{command}("1:/lib/{lib_name}"{remaining_args})'

    modified_script = lib_pattern.sub(lib_replacer, modified_script)

    # --- 2. Handle runPath calls (Scripts) ---
    # Scripts are copied to the package root, and the call is redirected to the
    # script's stem name in the package-relative path.
    run_path_pattern = re.compile(
        r"(runpath)\s*\(([\"'])(.*?)\2([^)]*)\)", re.IGNORECASE
    )

    # Find and collect all original script source paths
    for match in run_path_pattern.finditer(modified_script):
        original_path = match.group(3).strip()
        if original_path:
            script_paths.add(original_path)

    # Define the replacement logic: Redirect RUNPATH calls to the new package-relative path.
    def run_path_replacer(match: re.Match) -> str:
        command = match.group(1)
        original_path = match.group(3).strip()  # e.g., "0:/src/core/node.ks"
        remaining_args = match.group(4).strip()

        # Extract the base script name: component after the last separator
        # This handles both "0:/..." and "/..."
        base_name_with_ext = original_path.split(":")[-1]
        base_name_with_ext = base_name_with_ext.split("/")[-1]

        # Strip extension if present (e.g., 'script.ks' -> 'script')
        script_name = base_name_with_ext.split(".")[0]

        # The replacement format is command("1:/<script_name>" + remaining_args)
        # The script is assumed to be copied to the root of the '1:' drive.
        return f'{command}("1:/{script_name}"{remaining_args})'

    modified_script = run_path_pattern.sub(run_path_replacer, modified_script)

    return modified_script, library_paths, script_paths


def scan_script_for_func_defs(script_content: str) -> Dict[str, str]:
    """
    Scans a kOS script string using a brace-counting parser to reliably extract
    full function definitions. It first strips all kOS comments (single-line //
    and block /* */) to simplify parsing.

    Returns:
        A dictionary where keys are the uppercase function names and values
        are their complete function code strings.
    """

    # --- 1. Strip ALL comments ---

    # a) Strip block comments (/* ... */)
    # Uses non-greedy matching across newlines ([\s\S]*?)
    script_content = re.sub(r"/\*[\s\S]*?\*/", "", script_content)

    # b) Strip single-line comments (//)
    # This function removes everything after // on a line.
    def strip_sl_comments(line: str) -> str:
        comment_index = line.find("//")
        # If comment found, return content up to comment, stripped of trailing whitespace
        return line[:comment_index].rstrip() if comment_index != -1 else line.rstrip()

    # Apply the stripping function to every line
    cleaned_lines = [strip_sl_comments(line) for line in script_content.splitlines()]

    # Join back the cleaned lines (now without any comments)
    content_for_parsing = "\n".join(cleaned_lines)

    # --- 2. Initialize parser state ---
    functions: Dict[str, str] = {}
    lines = content_for_parsing.splitlines()

    is_in_function = False
    brace_count = 0
    current_function_lines: List[str] = []
    current_function_name = ""

    # Regex to check for the start of a function and capture the name
    start_pattern = re.compile(r"^\s*function\s+(?P<name>\w+)\s*\{", re.IGNORECASE)

    # --- 3. Iterate and parse using the brace counter (simple state machine) ---
    for line in lines:
        line_stripped = line.strip()
        if not line_stripped:
            continue

        # Check for function start
        if not is_in_function:
            match = start_pattern.match(line)
            if match:
                is_in_function = True
                current_function_name = match.group("name")
                current_function_lines.append(line)

                # Initialize brace count on the starting line (must be at least 1)
                brace_count = line_stripped.count("{") - line_stripped.count("}")
                continue

        # Process lines within a function
        if is_in_function:
            current_function_lines.append(line)

            # Update brace count
            brace_count += line_stripped.count("{")
            brace_count -= line_stripped.count("}")

            # Check for function end
            if brace_count == 0:
                # Store the complete, clean function string
                full_function_string = "\n".join(current_function_lines).strip()
                # Store function name in uppercase for case-insensitive lookup later
                functions[current_function_name.upper()] = full_function_string

                # Reset state for the next function
                is_in_function = False
                current_function_lines = []
                current_function_name = ""

    return functions


def find_potential_calls(content: str) -> Set[str]:
    """
    Finds all identifiers immediately followed by an opening parenthesis.
    This captures all potential function calls in the given script content.

    Returns:
        A set of potential function names, all converted to uppercase.
    """
    # Identifiers (\w+) followed by optional whitespace and an opening parenthesis \(
    call_pattern = re.compile(r"\b(\w+)\s*\(", re.IGNORECASE)
    # kOS is case-insensitive, so we return all findings in uppercase for consistent lookup
    return {call.upper() for call in call_pattern.findall(content)}


def collect_library_functions(
    script_content: str,
    library_paths: Set[str],
    archive_dir_path: Path,
) -> Dict[str, str]:
    """
    Scans the main script's dependencies against functions defined in external
    library files and returns the code for all used library functions,
    including deep (transitive) dependencies, using a Breadth-First Search (BFS).

    Args:
        script_content: The main kOS script content.
        library_paths: A set of source file paths for necessary libraries.
        archive_dir_path: The root Path of the project archive on the host machine.

    Returns:
        A dictionary where keys are the uppercase names of the used library functions
        and values are their corresponding function code strings.
    """

    # --- 1. Gather all functions from all necessary libraries ---
    all_library_functions: Dict[str, str] = {}

    for original_path in library_paths:
        # Resolve the kOS path (e.g., "0:/src/lib/file") to a host file path
        if original_path.startswith("0:/"):
            # Strip "0:/" and ensure the .ks extension
            relative_path = Path(original_path[3:]).with_suffix(".ks")
        else:
            # Assume it's already a relative path structure, ensure .ks extension
            relative_path = Path(original_path).with_suffix(".ks")

        absolute_path = archive_dir_path / relative_path

        if absolute_path.exists():
            try:
                lib_script_content = absolute_path.read_text(encoding="utf-8")
                # Store function names in uppercase for case-insensitive lookup
                lib_funcs = {
                    k.upper(): v
                    for k, v in scan_script_for_func_defs(lib_script_content).items()
                }
                all_library_functions.update(lib_funcs)
            except Exception as e:
                # Print warning if a dependency file cannot be read
                print(f"Error reading or scanning library {absolute_path}: {e}")
        else:
            # Print warning if a dependency file is missing
            print(f"Warning: Library path not found: {absolute_path}")

    all_library_function_names = set(all_library_functions.keys())

    # --- 2. Get all functions defined locally in the main script ---
    main_script_functions = scan_script_for_func_defs(script_content)
    main_script_function_names = set(main_script_functions.keys())

    # --- 3. Find initial direct dependencies ---
    potential_calls_in_main = find_potential_calls(script_content)

    # Use a set to track functions that are confirmed dependencies
    functions_to_process: Set[str] = set()

    for call_name in potential_calls_in_main:
        # A library dependency is a function that is callable AND
        # is provided by a library AND is NOT defined locally in the main script.
        if (
            call_name in all_library_function_names
            and call_name not in main_script_function_names
        ):
            functions_to_process.add(call_name)

    # --- 4. Iteratively resolve deep (transitive) dependencies (BFS) ---

    # Queue for BFS processing (start with direct dependencies)
    processing_queue: List[str] = list(functions_to_process)

    # Track functions that are finalized to prevent re-processing and infinite loops
    collected_functions: Set[str] = set(functions_to_process)

    # Final output storage: name -> code
    used_library_functions_code: Dict[str, str] = {}

    while processing_queue:
        current_func_name = processing_queue.pop(0)

        # 4a. Collect the function's code
        # This function is guaranteed to exist in the collection
        func_code = all_library_functions[current_func_name]
        used_library_functions_code[current_func_name] = func_code

        # 4b. Scan the function's body for its own dependencies
        calls_in_func_body = find_potential_calls(func_code)

        for sub_call_name in calls_in_func_body:
            # Check if:
            # i) The sub-call is a function provided by one of the libraries, AND
            # ii) We have not already collected or queued it (preventing cycles/duplicates).
            # We don't need to check against main_script_function_names here, as
            # those functions are external to the library collection.
            if (
                sub_call_name in all_library_function_names
                and sub_call_name not in collected_functions
            ):
                # Found a new deep dependency! Add it to the queue and tracking set
                collected_functions.add(sub_call_name)
                processing_queue.append(sub_call_name)

    # Return the dictionary of all deeply required functions
    return used_library_functions_code


def extract_kos_global_parameters(script_content: str) -> List[str]:
    """
    Scans kOS script content for parameter definitions, excluding those that
    are inside a function block (identified by curly braces).

    Args:
        script_content: The full content of the kOS script as a string.

    Returns:
        A list of strings, where each string is a global kOS parameter definition line.
    """
    # --- 1. Strip ALL comments ---

    # a) Strip block comments (/* ... */)
    # Uses non-greedy matching across newlines ([\s\S]*?)
    script_content = re.sub(r"/\*[\s\S]*?\*/", "", script_content)

    # b) Strip single-line comments (//)
    # This function removes everything after // on a line.
    def strip_sl_comments(line: str) -> str:
        comment_index = line.find("//")
        # If comment found, return content up to comment, stripped of trailing whitespace
        return line[:comment_index].rstrip() if comment_index != -1 else line.rstrip()

    # Apply the stripping function to every line
    cleaned_lines = [strip_sl_comments(line) for line in script_content.splitlines()]

    # Join back the cleaned lines (now without any comments)
    content_for_parsing = "\n".join(cleaned_lines)

    # --- 2. Collect list of parameter definitions in the global scope ---

    parameter_definitions: List[str] = []
    # Tracks the nesting level of curly braces.
    # Level 0 means we are in the global script scope.
    brace_count = 0

    # Regex to identify parameter definition lines (global or local)
    param_pattern = re.compile(r"^\s*(declare\s+parameter|parameter)\b", re.IGNORECASE)

    for line in content_for_parsing.splitlines():
        trimmed_line = line.strip()

        # Update brace count
        brace_count += trimmed_line.count("{")
        brace_count -= trimmed_line.count("}")

        # Ensure brace_count doesn't drop below zero due to mismatched braces
        brace_count = max(0, brace_count)

        # Check for parameter definition at the global scope
        if brace_count == 0:
            if param_pattern.match(trimmed_line):
                # Add the whole trimmed line to the list
                parameter_definitions.append(trimmed_line)

    # Filter out empty strings that might result from logic
    return parameter_definitions


if __name__ == "__main__":
    archive_dir_path = "../"
    script_src = "0:/src/scripts/launch.ks"
    script_dst = "0:/build/test_package/offline_scripts/launch.ks"
    lib_name = "test_lib.ks"
    lib_dst = f"0:/build/test_package/lib/{lib_name}"

    script_content = Path(".." + script_src[2:]).read_text()

    modified_script, library_paths, script_paths = (
        refactor_script_for_cross_dependencies(script_content, lib_name)
    )

    print(library_paths)
    print(script_paths)
    print(f'Wrote modified script to: "{(Path(archive_dir_path) / script_dst[3:])}"')
    (Path(archive_dir_path) / script_dst[3:]).write_text(modified_script)

    library_functions = collect_library_functions(
        modified_script, library_paths, archive_dir_path
    )
    print(library_functions.keys())

    library_content = f"//{lib_name}\n@lazyGlobal off.\n\n"
    for full_function_string in reversed(library_functions.values()):
        library_content += full_function_string + "\n\n"
    print(f'Wrote library to: "{(Path(archive_dir_path) / lib_dst[3:])}"')
    (Path(archive_dir_path) / lib_dst[3:]).write_text(library_content)
