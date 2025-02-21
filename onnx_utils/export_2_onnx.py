import torch
import torch.nn as nn
import torch.onnx

# Define the MLP model
class MLPWithSoftmax(nn.Module):
    def __init__(self):
        super(MLPWithSoftmax, self).__init__()
        self.model = nn.Sequential(
            nn.Flatten(),                       # Flatten input tensor
            nn.Linear(32 * 32 * 3, 64),         # First fully connected layer
            nn.ReLU(),                          # ReLU activation
            nn.Linear(64, 32),                  # Second fully connected layer
            nn.ReLU(),                          # ReLU activation
            nn.Linear(32, 10),                  # Third fully connected layer
            nn.Softmax(dim=1)                   # Softmax activation for output
        )

    def forward(self, x):
        return self.model(x)

# Instantiate the model
model = MLPWithSoftmax()
print(model)

# Dummy input for testing and exporting (batch_size=1, channels=3, height=32, width=32)
dummy_input = torch.randn(1, 3, 32, 32)

# Export the model to ONNX format
onnx_file = "onnx_graphs/mlp_with_softmax.onnx"
torch.onnx.export(
    model,                     # Model being exported
    dummy_input,               # Dummy input to the model
    onnx_file,                 # Path to save the ONNX file
    export_params=True,        # Store the trained parameter weights inside the model file
    opset_version=12,          # ONNX version to use
    input_names=['input'],     # Input tensor names
    output_names=['output'],   # Output tensor names
    # dynamic_axes={'input': {0: 'batch_size'}, 'output': {0: 'batch_size'}}  # Enable dynamic batching
)

print(f"Model exported to {onnx_file}")
