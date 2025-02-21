import os
import sys
import json
import onnx
from onnx import utils
from dotenv import load_dotenv

load_dotenv(dotenv_path="../config/.common.env")

DEFAULT_INPUT_PATH = output_dir = os.getenv("DEFAULT_INPUT_PATH_ONNX_GRAPHS")

DEFAULT_OUTPUT_FOLDER = output_dir = os.getenv("DEFAULT_OUTPUT_FOLDER_ONNX_SPLIT_GRAPHS")

DEFAULT_CONFIG = output_dir = os.getenv("DEFAULT_CONFIG_ONNX_SPLIT_GRAPHS")

def extract_subgraphs(input_path, output_folder, model_name, subgraphs):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    full_input_path = os.path.join(input_path, f"{model_name}.onnx")

    try:
        model = onnx.load(full_input_path)
    except Exception as e:
        print(f"Error loading model {model_name}: {e}")
        return

    for subgraph in subgraphs:
        node_name = subgraph['node']
        inputs = subgraph['input']
        outputs = subgraph['output']
        print(f"Subgraph {node_name} processing")

        output_filename = f"{model_name}_{node_name}.onnx"
        output_path = os.path.join(output_folder, output_filename)

        utils.extract_model(full_input_path, output_path, inputs, outputs)

        print(f"Subgraph {node_name} saved to {output_path}")


if __name__ == "__main__":
    input_folder = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_INPUT_PATH
    output_folder = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUTPUT_FOLDER
    config_path = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_CONFIG

    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except Exception as e:
        print(f"Error loading config file {config_path}: {e}")
        sys.exit(1)

    for model_config in config:
        model_name = model_config['model']
        subgraphs = model_config['sub-graphs']

        print(f"Processing model: {model_name}")

        extract_subgraphs(input_folder, output_folder, model_name, subgraphs)
