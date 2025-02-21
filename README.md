# vectorization-prep
start onnx-mlir docker: docker run -d -it -v vectorization-prep:/automation/vectorization-prep -v onnx-inputs:/automation/onnx-inputs onnxmlir/onnx-mlir-dev:latest

generate random data for testing:
python gen_random_data.py float32[1,8,768]

split onnx graphs:
python split_manul.py

generate ELF for all models from filename.txt
./run.sh -target=all -aff-vlen=4 -env=m1

./run.sh -cp=llvmir -target=all -aff-vlen=4 -env=m1

-target = x86, all, riscv

generate ELF for single model bertgoogle_Add
./run.sh -name=bertgoogle_Add -target=riscv -aff-vlen=4 -env=m1

Run Elf: 
./model.elf [inuputs] [input_dim]

./alex_O3_2.elf ../../../common/onnx-inputs/npy_c_uns_char/alex.npy.c "1,3,224,224"

./bertgoogle_Add_O3_1.elf ../../../common/onnx-inputs/npy_c_uns_char/random_generated/data_1_8_768_c.npy.c  ../../../common/onnx-inputs/npy_c_uns_char/random_generated/data_1_8_768_c.npy.c  "1,8,768" "1,8,768"
