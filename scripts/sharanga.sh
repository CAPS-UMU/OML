#!/bin/bash

COMMON_ENV_FILE="../config/.common.env"

GREP_PATTERN=""
ITERATIONS=5

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -g=*) GREP_PATTERN="${1#*=}";;
        -t=*) ITERATIONS="${1#*=}";;
        *) echo "Unknown option: $1"; exit 1;;
    esac
    shift
done

# Load environment variables
if [ -f "$COMMON_ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        if [[ -z "$key" || "$key" =~ ^# ]]; then
            continue
        fi

        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        eval "$key=\"$value\""
    done < "$COMMON_ENV_FILE"
else
    echo ".common.env file not found at $COMMON_ENV_FILE. Please ensure the file exists."
    exit 1
fi

YAML_FILE=$ELF_X86_JSON
BASE_PATH=$OUTPUT_DIR_NPY_C_RANDOM
ELF_X86=$ELF_X86

echo "Base Directory: $ELF_X86"
cd "$ELF_X86" || { echo "Failed to navigate to $ELF_X86"; exit 1; }
ls
echo "Processing YAML file: $YAML_FILE"

if [ ! -f "$YAML_FILE" ]; then
    echo "YAML file not found at $YAML_FILE"
    exit 1
fi

# Function to parse YAML
parse_yaml() {
    awk '
    /^[ \t]*-[ \t]*name:/ {
        if (model != "" && dims != "") {
            print model "|" dims
        }
        model = $3
        dims = ""
    }
    /^[ \t]*-[ \t]*".+"/ {
        gsub(/^[ \t]*-[ \t]*"/, "", $0)
        gsub(/"$/, "", $0)
        dims = (dims ? dims " and " : "") $0
    }
    END {
        if (model != "" && dims != "") {
            print model "|" dims
        }
    }
    ' "$YAML_FILE"
}

echo " model is identifies as  >>>>>>>>>>>>>>>>>>"
echo "$(echo "$model" | xargs)"

# Process YAML models and dimensions
while IFS="|" read -r model dims; do
    model=$(echo "$model" | xargs)
    dims=$(echo "$dims" | xargs)  # Ensure dims is a single string like "1,3,224,224"

    if [[ -z "$model" || -z "$dims" ]]; then
        echo "=================================="
        echo "Model: $model"
        echo "Dims: $dims"
        echo "=================================="
        echo "Skipping empty model or dimensions."
        continue
    fi

    echo "=================================="
    echo "Model: $model"
    echo "Dims: $dims"
    echo "=================================="
    ELF_FILES=$(find . -type f -name "$model*.elf")

    if [ -z "$ELF_FILES" ]; then
        echo "No ELF files found for model: $model"
        continue
    fi

    IFS=' and ' read -r -a dim_sets <<< "$dims"

    echo "=================================="
    # echo "dim_sets : $dim_sets"
    for dim in "${dim_sets[@]}"; do
        echo "Dimension set item: $dim"
    done

    # Loop through each ELF file
    for elf in $ELF_FILES; do
        echo "Running $elf $ITERATIONS times..."
        
        # Loop through the number of iterations
        for i in $(seq 1 $ITERATIONS); do
            echo "------------------------------------------"
            echo "Run Cycle: #$i of $elf"
            
            rand_files=()  # Reset rand_files array for each iteration
            dims_a=()

            # Loop through each dimension set and find a random file
            for dims_set in "${dim_sets[@]}"; do
                if [[ -z "$dims_set" ]]; then
                    echo "Skipping empty dimension set."
                    continue
                fi
                echo "Processing dimension set: $dims_set"


                # Convert the dimension set from comma-separated to 'x' separated
                search_dim="${dims_set//,/x}"  # Convert "1,3,224,224" -> "1x3x224x224"
                dim_dir="$BASE_PATH/$search_dim"  # Construct the directory path for this dimension set

                # Ensure the directory exists and is not empty
                if [ -d "$dim_dir" ] && [ "$(ls -A "$dim_dir" 2>/dev/null)" ]; then
                    # Find files that match the dimension set (adjust pattern if necessary)
                    rand_file=$(find "$dim_dir" -type f | awk -v var=$(find "$dim_dir" -type f | wc -l) 'BEGIN{srand();} {a[NR]=$0} END {print a[int(rand()*var)+1]}')

                    # Check if we found a file
                    if [[ -n "$rand_file" ]]; then
                        echo "Selected random file for dimension set '$dims_set': $rand_file"
                        rand_files+=("$rand_file")
                        dims_a+=("$dims_set")

                    else
                        echo "No files found for dimension set '$dims_set'. Skipping this dimension."
                    fi
                else
                    echo "Directory '$dim_dir' is empty or doesn't exist. Skipping dimension set '$dims_set'."
                fi
            done

            # If no random files were selected, skip the ELF execution for this iteration
            if [ ${#rand_files[@]} -eq 0 ]; then
                echo "No files selected for iteration $i. Skipping ELF execution."
                continue
            fi

            # Now pass the selected random file and dimensions to the ELF
            dim_args="$dims"  # Already in the correct format for ELF: "1,3,224,224"

            echo "=========================================================="
            echo "Selected files: ${rand_files[@]}"
            echo "=========================================================="
            
            # Execute the ELF file with the random files and dimensions
            echo "Executing: $elf ${rand_files[@]} ${dims_a[@]}"
            
            # Execute the ELF file, grep the output if GREP_PATTERN is set
            if [[ -n "$GREP_PATTERN" ]]; then
                # If GREP_PATTERN is set, grep the output of ELF
                $elf "${rand_files[@]}" "${dims_a[@]}" 2>&1 | grep -i "$GREP_PATTERN"
            else
                # Otherwise, just run the ELF command normally
                $elf "${rand_files[@]}" "${dims_a[@]}"
            fi
        done
    done
done < <(parse_yaml)

echo "Finished running all .elf files."
