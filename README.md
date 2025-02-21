# vectorization-prep
start onnx-mlir docker: docker run -d -it -v vectorization-prep:/automation/vectorization-prep -v onnx-inputs:/automation/onnx-inputs onnxmlir/onnx-mlir-dev:latest

python gen_random_data.py float32[1,8,768]

python split_manul.py

./vajra.sh -target=all

./gen_bin.sh -cp=llvmir -target=all

-target = x86, all, riscv

./alex_O3_2.elf ../../../common/onnx-inputs/npy_c_uns_char/alex.npy.c "1,3,224,224"

./bertgoogle_Add_O3_1.elf ../../../common/onnx-inputs/npy_c_uns_char/random_generated/data_1_8_768_c.npy.c  ../../../common/onnx-inputs/npy_c_uns_char/random_generated/data_1_8_768_c.npy.c  "1,8,768" "1,8,768"
