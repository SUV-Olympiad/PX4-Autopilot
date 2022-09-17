#!/bin/bash
# run multiple instances of the 'px4' binary, with the gazebo SITL simulation
# It assumes px4 is already built, with 'make px4_sitl_default gazebo'

# The simulator is expected to send to TCP port 4560+i for i in [0, N-1]
# For example gazebo can be run like this:
#./Tools/gazebo_sitl_multiple_run.sh -n 10 -m iris
# ./Tools/gazebo_suv_run.sh -t px4_sitl_rtps -f [vehicles] -w empty
# The [vehicles] file should have vehicle_type, pos_x, pos_y, pos_z(default: 0.83), group
# iris:0:0:0:A
# plane:5:5:10:B
# iris:10:0:0:C

function cleanup() {
	pkill -x px4
	pkill gzclient
	pkill gzserver
}

function spawn_model() {
	MODEL=$1
	N=$2 #Instance Number
	X=$3
	Y=$4
	Z=$5
	X=${X:=0.0}
	Y=${Y:=$((3*${N}))}

	SUPPORTED_MODELS=("iris" "plane" "standard_vtol" "rover" "r1_rover" "typhoon_h480", "iris_fpv_cam")
	if [[ " ${SUPPORTED_MODELS[*]} " != *"$MODEL"* ]];
	then
		echo "ERROR: Currently only vehicle model $MODEL is not supported!"
		echo "       Supported Models: [${SUPPORTED_MODELS[@]}]"
		trap "cleanup" SIGINT SIGTERM EXIT
		exit 1
	fi

  MODEL_PX4 = ${MODEL}
  if [${MODEL} == "iris_fpv_cam"];
  then
    MODEL_PX4 = "iris"
  fi

	working_dir="$build_path/instance_$n"
	[ ! -d "$working_dir" ] && mkdir -p "$working_dir"

	pushd "$working_dir" &>/dev/null
	echo "starting instance $N in $(pwd)"
	../bin/px4 -i $N -d "$build_path/etc" -w sitl_${MODEL}_${N} -s etc/init.d-posix/rcS >out.log 2>err.log &
	python3 ${src_path}/Tools/sitl_gazebo/scripts/jinja_gen.py ${src_path}/Tools/sitl_gazebo/models/${MODEL}/${MODEL}.sdf.jinja ${src_path}/Tools/sitl_gazebo --instance_number $((${N})) --mavlink_tcp_port $((4560+${N})) --mavlink_udp_port $((14560+${N})) --mavlink_id $((1+${N})) --gst_udp_port $((5600+${N})) --video_uri $((5600+${N})) --mavlink_cam_udp_port $((14530+${N})) --output-file /tmp/${MODEL}_${N}.sdf

	echo "Spawning ${MODEL}_${N} at ${X} ${Y} ${Z}"

	gz model --spawn-file=/tmp/${MODEL}_${N}.sdf --model-name=${MODEL}_${N} -x ${X} -y ${Y} -z ${Z}

	popd &>/dev/null

}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
	echo "Usage: $0 [-n <num_vehicles>] [-m <vehicle_model>] [-w <world>] [-f <script>]"
	echo "-f flag is used to script spawning vehicles e.g. $0 -f [script_name]"
	exit 1
fi

while getopts n:m:w:f:t:l: option
do
	case "${option}"
	in
		n) NUM_VEHICLES=${OPTARG};;
		m) VEHICLE_MODEL=${OPTARG};;
		w) WORLD=${OPTARG};;
		f) SCRIPT=${OPTARG};;
		t) TARGET=${OPTARG};;
		l) LABEL=_${OPTARG};;
	esac
done

num_vehicles=${NUM_VEHICLES:=3}
world=${WORLD:=empty}
target=${TARGET:=px4_sitl_default}
vehicle_model=${VEHICLE_MODEL:="iris"}
export PX4_SIM_MODEL=${vehicle_model}
export PX4_HOME_LAT=36.766559
export PX4_HOME_LON=127.281290
export PX4_HOME_ALT=53.5
export GAZEBO_MODEL_PATH=$HOME/olympiad/models

echo ${SCRIPT}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_path="$SCRIPT_DIR/.."

build_path=${src_path}/build/${target}
mavlink_udp_port=14560
mavlink_tcp_port=4560

echo "killing running instances"
pkill -x px4 || true

sleep 1

source ${src_path}/Tools/setup_gazebo.bash ${src_path} ${src_path}/build/${target}

# To use gazebo_ros ROS2 plugins
if [[ -n "$ROS_VERSION" ]] && [ "$ROS_VERSION" == "2" ]; then
	ros_args="-s libgazebo_ros_init.so -s libgazebo_ros_factory.so"
else
	ros_args=""
fi

echo "Starting gazebo"
gzserver ${src_path}/Tools/sitl_gazebo/worlds/${world}.world --verbose $ros_args &
sleep 5

n=0
if [ -z ${SCRIPT} ]; then
	if [ $num_vehicles -gt 255 ]
	then
		echo "Tried spawning $num_vehicles vehicles. The maximum number of supported vehicles is 255"
		exit 1
	fi

	while [ $n -lt $num_vehicles ]; do
		spawn_model ${vehicle_model} $n
		n=$(($n + 1))
	done
else
	IFS=,
	a_n=0
	b_n=10
	c_n=20
	while read target; do
		target="$(echo "$target" | tr -d ' ')" #Remove spaces
		target_vehicle=$(echo $target | cut -f1 -d:)
		target_x=$(echo $target | cut -f2 -d:)
		target_y=$(echo $target | cut -f3 -d:)
		target_z=$(echo $target | cut -f4 -d:)
		group=$(echo $target | cut -f5 -d:)

		if [ $n -gt 255 ]
		then
			echo "Tried spawning $n vehicles. The maximum number of supported vehicles is 255"
			exit 1
		fi
    case "${group}"
    	in
    	  A) n=$a_n
    	    a_n=$(($a_n + 1));;
    	  B) n=$b_n
    	    b_n=$(($b_n + 1));;
    	  C) n=$c_n
          c_n=$(($c_n + 1));;
    esac
		export PX4_SIM_MODEL=${target_vehicle}
		spawn_model ${target_vehicle}${LABEL} $n $target_x $target_y $target_z
	done < ${SCRIPT}

fi
trap "cleanup" SIGINT SIGTERM EXIT

echo "Starting gazebo client"
gzclient