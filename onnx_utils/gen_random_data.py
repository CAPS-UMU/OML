import torch
import numpy as np
import sys
import random
import string
import os
import re
import subprocess

from dotenv import load_dotenv

load_dotenv(dotenv_path="../config/.common.env")

def generate_and_save_tensor():
    if len(sys.argv) != 2:
        print("Usage: python gen_random_data.py <dtype>[<dimensions>]")
        sys.exit(1)

    input_str = sys.argv[1]

    match = re.match(r'(\w+)\[(.*)\]', input_str)
    if not match:
        print(f"Error: Invalid format '{input_str}'")
        sys.exit(1)

    dtype_str = match.group(1)
    dims_input = match.group(2)

    try:
        dtype = getattr(torch, dtype_str)
    except AttributeError:
        print(f"Error: Unsupported type '{dtype_str}'")
        sys.exit(1)

    dims = tuple(map(int, dims_input.split(',')))

    # Get the base output directories from the environment variables
    npy_base_dir = os.getenv("OUTPUT_DIR_NPY_RANDOM")
    npy_c_base_dir = os.getenv("OUTPUT_DIR_NPY_C_RANDOM")

    if not npy_base_dir or not npy_c_base_dir:
        print("Error: OUTPUT_DIR_NPY_RANDOM and OUTPUT_DIR_NPY_C_RANDOM must be set in the environment")
        sys.exit(1)

    # Ensure the directories for npy and npy.c files exist
    dim_folder = "x".join(map(str, dims))

    npy_output_dir = os.path.join(npy_base_dir, dim_folder)
    npy_c_output_dir = os.path.join(npy_c_base_dir, dim_folder)

    # Create directories if they don't exist
    os.makedirs(npy_output_dir, exist_ok=True)
    os.makedirs(npy_c_output_dir, exist_ok=True)

    # Generate and save 5 random tensors
    for i in range(5):
        # Generate a random tensor
        tensor_data = torch.rand(dims, dtype=dtype)
        flat_tensor_data = tensor_data.flatten().numpy()

        # Generate a random alphabet for filename uniqueness (with index appended)
        random_char = random.choice(string.ascii_lowercase)

        # To avoid overwriting, use a random alphabet + index (e.g., data_a_0.npy)
        filename = f"data_{random_char}_{i}{'.npy'}"
        npy_file_path = os.path.join(npy_output_dir, filename)

        # Save tensor as .npy file
        np.save(npy_file_path, flat_tensor_data)
        print(f"Tensor saved to {npy_file_path}")

        # Convert the .npy file to a .c file
        npy_c_filename = os.path.basename(npy_file_path) + ".c"
        npy_c_file_path = os.path.join(npy_c_output_dir, npy_c_filename)

        try:
            subprocess.run(["xxd", "-i", npy_file_path, npy_c_file_path], check=True)
            print(f"Converted to C header and saved to {npy_c_file_path}")
        except subprocess.CalledProcessError as e:
            print(f"Error occurred while running xxd: {e}")

if __name__ == "__main__":
    generate_and_save_tensor()
