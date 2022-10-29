# SUV PX4-Autopilot

### [전체 시스템 실행 메뉴얼](https://github.com/SUV-Olympiad/SUV-Tools/blob/main/shellscript/README.md)

## Config
### vehicles file

- 다수의 드론을 Spawn할 위치를 지정
- Gazebo상의 좌표계 사용
    #### format
    ````text
    #The [vehicles] file should have vehicle_type, pos_x, pos_y, pos_z(default: 0.83), group
    iris:0:0:0:A
    standard_vtol:5:5:10:B
    typhoon_h480:10:0:0:C
    ````

### Gazebo models files - [Link](https://drive.google.com/drive/folders/1iQrGri4qP_nPKJhN0nCnCg6VGx8K2sPp?usp=sharing)
- PX4-Autopilot 과 같은 workspace에 위치

## Build

- `make px4_sitl_rtps gazebo`
- 실행 전 `px4_sitl_rtps`, `gazebo` 빌드가 필요

## Run

```shell
    ./Tools/suv_run.sh -f Tools/vehicles -t px4_sitl_rtps -w suv
```

### [suv_run.sh](./Tools/suv_run.sh)

- `-f` : 기체 스폰 위치 config file
- `-t` : 빌드 대상
-  `-w` : Gazebo World 이름