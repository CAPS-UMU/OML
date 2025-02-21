while [[ $# -gt 0 ]]; do
	case "$1" in
	-name=*)
		filename="${1#*=}"
		shift
		;;
	-target=*)
		elf_target="${1#*=}"
		shift
		;;
	-cp=*)
		cp="${1#*=}"
		shift
		;;
	-vlen=*)
		vlen="${1#*=}"
		shift
		;;
	-urf=*)
		unroll_factor="${1#*=}"
		shift
		;;
	-skip=*)
		skip="${1#*=}"
		shift
		;;
	-only=*)
		only="${1#*=}"
		shift
		;;
-aff-vlen=*)
		ir_sub_path="v${1#*=}"
		affine_vlen="${1#*=}"
		shift
		;;
#	-*)
-env=*)
		env_path="${1#*=}"
		shift
		;;
	-*)
		echo "Unknown option: $1"
		exit 1
		;;
	*)
		shift
		;;
	esac
done

read_filenames_from_file() {
	relative_file_path="filenames.txt"
	cd ../config

	echo "Current directory: $(pwd)"
	cd $(pwd)
	echo "Checking for file at: $relative_file_path"
	filenames=()

	if [ -f "$relative_file_path" ]; then
		echo "File found: $relative_file_path"
		while IFS= read -r line; do
			echo "$line"
			echo "Adding filename to list"
			echo "$line"
			filenames+=("$line")
		done <"$relative_file_path"
	else
		echo "Error: Filenames not provided and 'filenames.txt' not found."
		exit 1
	fi

	cd ../scripts
}

create_folder_if_not_exists() {
	echo "======================================================================================="
	echo "inside create_folder_if_not_exists"

	local folder_name="$1"
	if [ ! -d "$DOCKER_UTILS/$env_path/$ir_sub_path/$folder_name" ]; then
	  mkdir -p $DOCKER_UTILS
	  mkdir -p $DOCKER_UTILS/$env_path/$ir_sub_path
	  	chmod -R 777  $DOCKER_UTILS
		cd $DOCKER_UTILS/$env_path/$ir_sub_path
		mkdir "$folder_name"
		chmod -R 777 $folder_name
		cd $folder_name
		mkdir "${folder_name}_v1"

		export ONNX_MLIR_FILES_PATH="$DOCKER_UTILS/$env_path/$ir_sub_path/$folder_name/${folder_name}_v1"
		chmod -R 777 $ONNX_MLIR_FILES_PATH
		echo "Folder '$folder_name' created."
	else
		count=$(find $DOCKER_UTILS/$env_path/$ir_sub_path/$folder_name -maxdepth 1 -type d | wc -l)
		new_child_folder="$DOCKER_UTILS/$env_path/$ir_sub_path/$folder_name/${folder_name}_v$count"
		mkdir "$new_child_folder"
		export ONNX_MLIR_FILES_PATH=$DOCKER_UTILS/$env_path/$ir_sub_path/$folder_name/${folder_name}_v$count
		chmod -R 777 $ONNX_MLIR_FILES_PATH
		echo "Child folder '$new_child_folder' created."
	fi

	echo "completed create_folder_if_not_exists"
	echo "======================================================================================="
}

get_llvm_dialect() {
	echo "======================================================================================="
	echo "inside get_llvm_dialect"
	filename="$1"
	affine_vlen="$3"

	echo "$affine_vlen"

	cd $ONNX_MLIR_FILES_PATH &&
	onnx-mlir -O3  --EmitMLIR $(if [ "$affine_vlen" -gt 0 ]; then echo "--vlen=$affine_vlen"; fi)  $ONNX_GRAPHS/$filename.onnx -o $ONNX_MLIR_FILES_PATH/$filename.trans
	onnx-mlir -O3 --EmitLLVMIR $(if [ "$affine_vlen" -gt 0 ]; then echo "--vlen=$affine_vlen"; fi)   $ONNX_GRAPHS/$filename.onnx -o $ONNX_MLIR_FILES_PATH/$filename &&
		echo "generated $filename.onnx.mlir"

	echo "completed get_llvm_dialect"
	echo "======================================================================================="
}

navigate_to_docker_utils_host() {
	filename="$1"
	PWD="$2"
	env_path="$3"
	ir_sub_path="$4"
	cd $PWD
	pwd

#	echo "======================================================================================="
#	echo "======================================================================================="
#	echo "======================================================================================="
#	echo "======================================================================================="
#
#	echo $env_path
#	echo "======================================================================================="
#
#	echo $ir_sub_path
#	echo "======================================================================================="
#	echo "======================================================================================="
#	echo "======================================================================================="


	source ../oml-vect-prep/config/.m1.host.env
#	cat ../oml-vect-prep/config/.m1.host.env

	count=$(find "$DOCKER_UTILS/$env_path/$ir_sub_path/$filename" -maxdepth 1 -type d | wc -l)
	count=$((count - 1))

	cd $DOCKER_UTILS/$env_path/$ir_sub_path/$filename/"$filename"_v$count &&
		export ONNX_MLIR_FILES_PATH=$DOCKER_UTILS/$env_path/$ir_sub_path/$filename/"$filename"_v$count

		echo $ONNX_MLIR_FILES_PATH
	echo "======================================================================================="
	echo "inside navigate_to_docker_utils_host"
	echo "======================================================================================="
}

get_llvm_IR() {
	echo "======================================================================================="
	echo "inside get_llvm_IR"
	filename="$1"

	mlir-translate $filename.onnx.mlir --mlir-to-llvmir -o "$filename"_def.ll &&
		echo "generated llvm IR for $filename"
	ls
	pwd

	echo "completed get_llvm_IR"
	echo "======================================================================================="
}

otp_llvm_IR() {
	echo "======================================================================================="
	echo "inside otp_llvm_IR"
	filename="$1"

	opt --mtriple=riscv64-unknown-linux-gnu --mcpu=$MCPU --march=riscv64 -S -o $filename.ll "$filename"_def.ll &&

	$LLVM_RISCV_BIN/opt -O3 -S -o "$filename"_O3.ll $filename.ll &&
		$LLVM_RISCV_BIN/opt -passes=loop-unroll -unroll-count="$unroll_factor" -S -o "$filename"_O3_xpass.ll "$filename"_O3.ll
	$LLVM_RISCV_BIN/opt -passes=loop-vectorize -S -o "$filename"_O3_xpass_lv.ll "$filename"_O3_xpass.ll

	if [ -n "$cp" ]; then
		mkdir -p $IR
		mkdir -p $LLVM_IR
		cp "$filename"_O3.ll "$LLVM_IR/"
		cp "$filename"_O3_xpass.ll "$LLVM_IR/"
	fi
	ls

	echo "completed otp_llvm_IR"
	echo "======================================================================================="
}

get_asm() {
	echo "======================================================================================="
	echo "inside get_asm"
	filename="$1"

	$LLVM_x86_BIN/llc -O3 --filetype=asm -o "$filename"_O3_x86.s "$filename"_O3.ll &&
		$LLVM_x86_BIN/llc -O3 --filetype=asm -o "$filename"_O3_x86_xpass.s "$filename"_O3_xpass.ll &&
		echo "generated asm for $filename"
	ls

	echo "completed get_asm"
	echo "======================================================================================="
}

get_bin() {
	echo "======================================================================================="
	echo "inside gen bin"
	filename="$1"
	skip="$2"
	echo "in gen bin"

	navigate_to_docker_utils_host $filename $SCRIPTS_PATH $env_path $ir_sub_path

	if [ "$skip" != "elf" ]; then
	  echo "testing >>>>>>>>>>>>>>>>>>>>> ==================================================================================================="
	  pwd
	  ls

echo "$filename"_O3_xpass.ll exists: $([ -f "$filename"_O3_xpass.ll ] && echo true || echo false)
echo "$filename"_O3.ll exists: $([ -f "$filename"_O3.ll ] && echo true || echo false)


	  if [ -f "$filename"_O3_xpass.ll ]; then
        # Use $filename"_O3_xpass.ll" if 'xyz' exists
        input_file="$filename"_O3_xpass.ll
    else
        # Use a different file (replace 'alternative_file.ll' with the actual file name)
        input_file="$filename"_O3.ll
    fi


#		$LLVM_x86_BIN/llc -O3 --filetype=asm  --mtriple="x86_64-unknown-linux-gnu" --mcpu="alderlake"  -o "$filename"_O3_x86.s $input_file &&

echo "$filename"

		$LLVM_x86_BIN/llc -O3 --filetype=asm -o "$filename"_O3_x86_xpass.s $input_file &&
		echo "generated asm for $filename"
		ls
	fi

	cd $ONNX_MLIR_FILES_PATH &&
		current_date=$(date +"%Y-%m-%d")
	mkdir -p $OML_ELF_x86
	mkdir -p $OML_ELF_x86/"$current_date" &&
		count=$(find "$OML_ELF_x86/$current_date" -maxdepth 1 -type f | wc -l) &&
		count=$((++count)) &&
		$LLVM_x86_BIN/clang++ --std=c++11 -static -O3 -ffast-math -stdlib=libstdc++ -L/usr/lib64 -L/lib64 \
					-I /usr/include/c++/14 \
          -I /usr/include \
          -I /usr/include/c++/14/x86_64-redhat-linux/ \
			$MAIN_CPP/kaumodaki.cpp \
			"$filename"_O3_x86_xpass.s \
			-target x86_64-unknown-linux-gnu \
      -march=alderlake \
			$OML_RUNTIME_LIBC/libcruntime.a \
			-o $OML_ELF_x86/$current_date/"$filename"_O3_"$count".elf \
			-I $ONNX_MLIR_INCLUDE


	echo "generated exec bin for $filename..."
	echo "completed gen bin"
	echo "======================================================================================="
}

gen_riscv_bin() {
	echo "======================================================================================="
	echo "inside gen bin riscv"
	filename="$1"
	vlen="$3"
	skip="$2"
	navigate_to_docker_utils_host $filename $SCRIPTS_PATH  $env_path $ir_sub_path
	echo "in gen bin riscv"
	current_date=$(date +"%Y-%m-%d")
	mkdir -p $OML_ELF_RISCV
	mkdir -p $OML_ELF_RISCV/"$current_date"

	if [ "$skip" != "elf" ]; then


	  if [ -f "$filename"_O3_xpass.ll ]; then
        # Use $filename"_O3_xpass.ll" if 'xyz' exists
        input_file="$filename"_O3_xpass.ll
    else
        # Use a different file (replace 'alternative_file.ll' with the actual file name)
        input_file="$filename"_O3.ll
    fi

		$LLVM_RISCV_BIN/llc \
			-O3 \
			--filetype=asm \
			--mtriple=$MTRIPLE \
			--mcpu=$MCPU \
			${vlen:+-riscv-v-vector-bits-min=$vlen} \
			-o $ONNX_MLIR_FILES_PATH/"$filename"_riscv.s \
			$ONNX_MLIR_FILES_PATH/$input_file
	fi

	if [ -n "$MEPI" ]; then
      suffix="_mepi"
  else
      suffix=""
  fi

	$LLVM_RISCV_BIN/clang++ \
		--gcc-toolchain=$RISCV_GCC_TOOLCHAIN \
		-static \
		-target $TARGET \
		$(if [ -n "$MEPI" ]; then echo "-$MEPI"; fi) \
		-march=$MARCH \
		-mabi=$MABI \
		-ffast-math \
		-O3 \
		-lm \
		-L $SYSROOT \
		-I $ONNX_MLIR_INCLUDE \
		-I $RISCV_GCC_TOOLCHAIN_CPP_INCLUDE \
		-I $RISCV_GCC_TOOLCHAIN_CPP_LINUX_GNU \
		-I $SYSROOT \
		--sysroot=$SYSROOT \
		$ONNX_MLIR_FILES_PATH/"$filename"_riscv.s \
		$MAIN_CPP/trishula.cpp \
		$OML_RUNTIME_LIBC/libriscv_cruntime-riscv.a -o $OML_ELF_RISCV/"$current_date"/"$filename"_oml.elf

	echo "generated elf for riscv"
	echo "completed gen bin riscv"
	echo "======================================================================================="
}

init_in_container() {
	filename="$1"
	skip_till="$2"
	skip_copy_to_con="$3"
	debug="$4"
	env_path="$6"
	affine_vlen="$7"
	ir_sub_path="$8"
	echo $ir_sub_path
	echo "======================================================================================="
	echo "inside init_in_container"
$ir_sub_path
#cat  /workdir/oml/config/.m1.docker.env
	source /workdir/oml/config/.m1.docker.env

	export ONNX_MLIR_BIN=$ONNX_MLIR_ROOT/"$env_path"-build/Debug/bin
	export PATH=$ONNX_MLIR_BIN:$PATH

	create_folder_if_not_exists "$filename" "$debug"
	get_llvm_dialect "$filename" "$debug" "$affine_vlen"
	echo "completed init_in_container"
	echo "======================================================================================="
}

run_bin_in_host() {
	filename="$1"

	echo "running bin $filename"
	cd bin
	./"$filename"_O3 >$filename.output.txt
	echo "======================================================================================="
	echo "completed"

	cd ../../scripts
	pwd
}

get_container_info() {
	first_container_id="d06f1cbfa76d"
	# echo "First Container ID: $first_container_id"
}

start_container_get_bin() {
	echo "======================================================================================="
	echo "$ir_sub_path"
	container_id="$1"
	echo "Starting container with ID: $container_id"
	docker start "$container_id"
	echo "======================================================================================="
	docker exec -it $first_container_id /bin/bash -c "$(declare -f init_in_container set_env_onnx-mlir_vars create_folder_if_not_exists get_llvm_dialect); init_in_container '"$filename"' '"$bf"' '"$skip_till"' '"$skip_copy_to_con"' '"$debug"' '"$env_path"'  '"$affine_vlen"' '"$ir_sub_path"'"
}
get_and_run_bin() {
	export SCRIPTS_PATH=$(pwd)
	echo "======================================================================================="
	# echo "======================================================================================="
	#	navigate_to_docker_utils_host $filename $SCRIPTS_PATH  $env_path $ir_sub_path

	# get_container_info

	# echo "======================================================================================="
	# echo "======================================================================================="

	if [[ -n "$only" ]]; then
		case $only in
		"mlir")
			echo "No skip option provided"
			get_container_info
			start_container_get_bin $first_container_id
			;;
		"llvm")
			echo "Skipping llvm step $SCRIPTS_PATH"
			navigate_to_docker_utils_host $filename $SCRIPTS_PATH  $env_path $ir_sub_path
			get_llvm_IR "$filename"
			;;
		"opt")
			echo "Skipping opt step $SCRIPTS_PATH"
			navigate_to_docker_utils_host $filename $SCRIPTS_PATH  $env_path $ir_sub_path
			otp_llvm_IR "$filename"
			;;
		"asm")
			echo "Skipping asm step"
			get_asm "$filename"
			;;
		esac
	elif [[ -z "$only"  ]]; then
		case $skip in
		"")
			echo "No skip option provided"
			get_container_info
			start_container_get_bin $first_container_id
			;&
		"llvm")
			echo "Skipping llvm step $SCRIPTS_PATH"
			navigate_to_docker_utils_host $filename $SCRIPTS_PATH  $env_path $ir_sub_path
			get_llvm_IR "$filename"
			;&
		"opt")
			echo "Skipping opt step $SCRIPTS_PATH"
			navigate_to_docker_utils_host $filename $SCRIPTS_PATH  $env_path $ir_sub_path
			otp_llvm_IR "$filename"
			;&
		"asm")
			echo "Skipping asm step"
#			get_asm "$filename"
			;;
		esac

		# echo "======================================================================================="

		# echo "======================================================================================="

		case "$elf_target" in
		all)
			echo "Calling both functions for filename: $filename"

			export -f get_bin
			export -f gen_riscv_bin
			export -f navigate_to_docker_utils_host

			bash -c "get_bin \"$filename\" \"$skip\"" &
			bash -c "gen_riscv_bin \"$filename\" \"$skip\" \"$vlen\"" &
			wait

			cd $SCRIPTS_PATH
			;;
		x86)
			echo "Calling get_bin only for filename: $filename"
			get_bin "$filename" "$skip"
			;;
		riscv)
			echo "Calling gen_riscv_bin only for filename: $filename"
			gen_riscv_bin "$filename" "$skip" "$vlen"
			;;
		*)
			exit 1
			;;
		esac

	fi

	cd $SCRIPTS_PATH
}

if [[ -z "$filename" ]]; then
	read_filenames_from_file
else
	filenames=("$filename")
fi

for filename in "${filenames[@]}"; do
	echo "running $filename" &&
		get_and_run_bin "$filename"
done
