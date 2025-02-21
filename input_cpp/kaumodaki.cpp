#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <iomanip>
#include <cstring>
#include <chrono>

#define INPUT_NUM 3

#include "OnnxMlirRuntime.h"

std::vector<int64_t> parseShapeString(const std::string& shapeStr) {
    std::vector<int64_t> shape;
    std::istringstream ss(shapeStr);
    std::string item;

    while (std::getline(ss, item, ',')) {
        shape.push_back(std::stoll(item));
    }
    return shape;
}

std::vector<float> readFileData(const std::string &filePath) {
    std::ifstream inputFile(filePath, std::ios::binary);
    if (!inputFile.is_open()) {
        std::cerr << "Error: Could not open the file '" << filePath << "'!" << std::endl;
        exit(1);
    }

    std::vector<unsigned char> byteArray;
    std::string line;

    while (std::getline(inputFile, line)) {
        std::istringstream stream(line);
        std::string hexValue;

        while (std::getline(stream, hexValue, ',')) {
            hexValue.erase(0, hexValue.find_first_not_of(" \t"));
            hexValue.erase(hexValue.find_last_not_of(" \t") + 1);

            if (hexValue.empty()) continue;

            if (hexValue.size() > 1 && hexValue[0] == '0' && (hexValue[1] == 'x' || hexValue[1] == 'X')) {
                unsigned int value;
                std::istringstream(hexValue) >> std::hex >> value;
                byteArray.push_back(static_cast<unsigned char>(value));
            }
        }
    }

    inputFile.close();

    size_t num_floats = byteArray.size() / sizeof(float);
    std::vector<float> rgb_data(num_floats);

    for (size_t i = 0; i < num_floats; ++i) {
        float value;
        std::memcpy(&value, &byteArray[i * sizeof(float)], sizeof(value));
        rgb_data[i] = value;
    }

    return rgb_data;
}

extern "C" OMTensorList *run_main_graph(OMTensorList *);

int main(int argc, char *argv[]) {
    if (argc < 2 || argc > 7) {
      std::cout << argc << std::endl;
        std::cerr << "Usage: " << argv[0] << " <file_path1> <file_path2> [<file_path3>] <shape1> <shape2> [<shape3>]" << std::endl;
        return 1;
    }

    int inputNum = argc / 2;

    std::vector<std::string> filePaths;
    std::vector<std::string> shapeStrs;

    for (int i = 1; i <= inputNum; ++i) {
        filePaths.push_back(argv[i]);
    }

    for (int i = inputNum + 1; i < argc; ++i) {
        shapeStrs.push_back(argv[i]);
    }

    std::vector<std::vector<float>> inputData(inputNum);
    for (int i = 0; i < inputNum; ++i) {
        inputData[i] = readFileData(filePaths[i]);
    }

    std::vector<std::vector<int64_t>> shapes(inputNum);
    for (int i = 0; i < inputNum; ++i) {
        shapes[i] = parseShapeString(shapeStrs[i]);
    }

    OMTensor *inputTensors[inputNum];
    for (int i = 0; i < inputNum; ++i) {
        inputTensors[i] = omTensorCreateWithOwnership(inputData[i].data(), shapes[i].data(), shapes[i].size(), ONNX_TYPE_FLOAT, true);
    }

    OMTensorList *tensorListIn = omTensorListCreate(inputTensors, inputNum);

    std::cout << "Calling run_main_graph" << std::endl;
    auto start = std::chrono::high_resolution_clock::now();
    OMTensorList *tensorListOut = run_main_graph(tensorListIn);
    auto end = std::chrono::high_resolution_clock::now();

    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    std::cout << "Function runtime: " << duration.count() << " milliseconds" << std::endl;
    std::cout << "Completed and got prediction" << std::endl;
    std::cout << "Completed run_main_graph" << std::endl;

    OMTensor *y = omTensorListGetOmtByIndex(tensorListOut, 0);
    float *prediction = (float *)omTensorGetDataPtr(y);

    std::cout << "Prediction: " << prediction[0] << std::endl;
    std::cout << "Completed and got prediction" << std::endl;

    return 0;
}
