------------------------------------------------------------------------------
--                                                                          --
--                     Copyright (C) 2015-2016, AdaCore                     --
--                                                                          --
--  Redistribution and use in source and binary forms, with or without      --
--  modification, are permitted provided that the following conditions are  --
--  met:                                                                    --
--     1. Redistributions of source code must retain the above copyright    --
--        notice, this list of conditions and the following disclaimer.     --
--     2. Redistributions in binary form must reproduce the above copyright --
--        notice, this list of conditions and the following disclaimer in   --
--        the documentation and/or other materials provided with the        --
--        distribution.                                                     --
--     3. Neither the name of the copyright holder nor the names of its     --
--        contributors may be used to endorse or promote products derived   --
--        from this software without specific prior written permission.     --
--                                                                          --
--   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS    --
--   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT      --
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR  --
--   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   --
--   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, --
--   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT       --
--   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  --
--   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  --
--   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT    --
--   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  --
--   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.   --
--                                                                          --
------------------------------------------------------------------------------
--
-- Mehdi Ben Djedidia 17/07/2022
--
-- Adaptation du driver MPU9250 car la valeur de WHO_AM_I n'est pas celle attendue
-- dans le driver d'origine
--
-- Suppression de la fonction MPU92XX_Test_Connection bas?e sur cette valeur
-- MPU92XX_Test est conserv?e
--
-- Rajout des fonctions :
--  function MPU92XX_Who_Am_I (Device : MPU92XX_Device) return UInt8;
--
--  -- Get temperature
--  function MPU92XX_Get_Temperature (Device : MPU92XX_Device) return Float;
--

--  MPU92XX I2C device class package

with Interfaces;          use Interfaces;

with HAL;                 use HAL;
with HAL.I2C;             use HAL.I2C;
with HAL.Time;

package MPU92XX is

	type MPU92XX_AD0_Pin_State is (High, Low);
	--  The MPU92XX has a pin that can be set to high or low level to change
	--  its I2C address.

	--  Types and subtypes
	type MPU92XX_Device (Port        : HAL.I2C.Any_I2C_Port;
							 I2C_AD0_Pin : MPU92XX_AD0_Pin_State;
							 Time        : not null HAL.Time.Any_Delays) is private;


	--  Type reprensnting all the different clock sources of the MPU92XX.
	--  See the MPU92XX register map section 4.4 for more details.
	type MPU92XX_Clock_Source is
	  (Internal_Clk,
	 X_Gyro_Clk,
	 Y_Gyro_Clk,
	 Z_Gyro_Clk,
	 External_32K_Clk,
	 External_19M_Clk,
	 Reserved_Clk,
	 Stop_Clk);
	for MPU92XX_Clock_Source use
	  (Internal_Clk     => 16#00#,
	 X_Gyro_Clk       => 16#01#,
	 Y_Gyro_Clk       => 16#02#,
	 Z_Gyro_Clk       => 16#03#,
	 External_32K_Clk => 16#04#,
	 External_19M_Clk => 16#05#,
	 Reserved_Clk     => 16#06#,
	 Stop_Clk         => 16#07#);
	for MPU92XX_Clock_Source'Size use 3;

	--  Type representing the allowed full scale ranges
	--  for MPU92XX gyroscope.
	type MPU92XX_FS_Gyro_Range is
	  (MPU92XX_Gyro_FS_250,
	 MPU92XX_Gyro_FS_500,
	 MPU92XX_Gyro_FS_1000,
	 MPU92XX_Gyro_FS_2000);
	for MPU92XX_FS_Gyro_Range use
	  (MPU92XX_Gyro_FS_250  => 16#00#,
	 MPU92XX_Gyro_FS_500  => 16#01#,
	 MPU92XX_Gyro_FS_1000 => 16#02#,
	 MPU92XX_Gyro_FS_2000 => 16#03#);
	for MPU92XX_FS_Gyro_Range'Size use 2;

	--  Type representing the allowed full scale ranges
	--  for MPU92XX accelerometer.
	type MPU92XX_FS_Accel_Range is
	  (MPU92XX_Accel_FS_2,
	 MPU92XX_Accel_FS_4,
	 MPU92XX_Accel_FS_8,
	 MPU92XX_Accel_FS_16);
	for MPU92XX_FS_Accel_Range use
	  (MPU92XX_Accel_FS_2  => 16#00#,
	 MPU92XX_Accel_FS_4  => 16#01#,
	 MPU92XX_Accel_FS_8  => 16#02#,
	 MPU92XX_Accel_FS_16 => 16#03#);
	for MPU92XX_FS_Accel_Range'Size use 2;

	type MPU92XX_DLPF_Bandwidth_Mode is
	  (MPU92XX_DLPF_BW_256,
	 MPU92XX_DLPF_BW_188,
	 MPU92XX_DLPF_BW_98,
	 MPU92XX_DLPF_BW_42,
	 MPU92XX_DLPF_BW_20,
	 MPU92XX_DLPF_BW_10,
	 MPU92XX_DLPF_BW_5);
	for MPU92XX_DLPF_Bandwidth_Mode use
	  (MPU92XX_DLPF_BW_256 => 16#00#,
	 MPU92XX_DLPF_BW_188 => 16#01#,
	 MPU92XX_DLPF_BW_98  => 16#02#,
	 MPU92XX_DLPF_BW_42  => 16#03#,
	 MPU92XX_DLPF_BW_20  => 16#04#,
	 MPU92XX_DLPF_BW_10  => 16#05#,
	 MPU92XX_DLPF_BW_5   => 16#06#);
	for MPU92XX_DLPF_Bandwidth_Mode'Size use 3;

	--  Use to convert MPU92XX registers in degrees (gyro) and G (acc).
	MPU92XX_DEG_PER_LSB_250  : constant := (2.0 * 250.0) / 65536.0;
	MPU92XX_DEG_PER_LSB_500  : constant := (2.0 * 500.0) / 65536.0;
	MPU92XX_DEG_PER_LSB_1000 : constant := (2.0 * 1000.0) / 65536.0;
	MPU92XX_DEG_PER_LSB_2000 : constant := (2.0 * 2000.0) / 65536.0;
	MPU92XX_G_PER_LSB_2      : constant := (2.0 * 2.0) / 65536.0;
	MPU92XX_G_PER_LSB_4      : constant := (2.0 * 4.0) / 65536.0;
	MPU92XX_G_PER_LSB_8      : constant := (2.0 * 8.0) / 65536.0;
	MPU92XX_G_PER_LSB_16     : constant := (2.0 * 16.0) / 65536.0;

	--  Procedures and functions

	--  Initialize the MPU92XX Device via I2C.
	procedure MPU92XX_Init (Device : in out MPU92XX_Device);

	--  Test if the MPU92XX is initialized and connected.
	function MPU92XX_Test (Device : MPU92XX_Device) return Boolean;

	--  Test if we are connected to MPU92XX via I2C.
	--  function MPU92XX_Test_Connection (Device : MPU92XX_Device) return Boolean;

	type Test_Reporter is access
	  procedure (Msg : String; Has_Succeeded : out Boolean);

	--  MPU92XX self test.
	function MPU92XX_Self_Test
	  (Device    : in out MPU92XX_Device;
	 Do_Report : Boolean;
	 Reporter  : Test_Reporter) return Boolean;

	--  Reset the MPU92XX device.
	--  A small delay of ~50ms may be desirable after triggering a reset.
	procedure MPU92XX_Reset (Device : in out MPU92XX_Device);

	--  Get raw 6-axis motion sensor readings (accel/gyro).
	--  Retrieves all currently available motion sensor values.
	procedure MPU92XX_Get_Motion_6
	  (Device : MPU92XX_Device;
	 Acc_X  : out Integer_16;
	 Acc_Y  : out Integer_16;
	 Acc_Z  : out Integer_16;
	 Gyro_X : out Integer_16;
	 Gyro_Y : out Integer_16;
	 Gyro_Z : out Integer_16);

	--  Set clock source setting.
	--  3 bits allowed to choose the source. The different
	--  clock sources are enumerated in the MPU92XX register map.
	procedure MPU92XX_Set_Clock_Source
	  (Device       : in out MPU92XX_Device;
	 Clock_Source : MPU92XX_Clock_Source);

	--  Set digital low-pass filter configuration.
	procedure MPU92XX_Set_DLPF_Mode
	  (Device    : in out MPU92XX_Device;
	 DLPF_Mode : MPU92XX_DLPF_Bandwidth_Mode);

	--  Set full-scale gyroscope range.
	procedure MPU92XX_Set_Full_Scale_Gyro_Range
	  (Device   : in out MPU92XX_Device;
	 FS_Range : MPU92XX_FS_Gyro_Range);

	--  Set full-scale acceler range.
	procedure MPU92XX_Set_Full_Scale_Accel_Range
	  (Device   : in out MPU92XX_Device;
	 FS_Range : MPU92XX_FS_Accel_Range);

	--  Set I2C bypass enabled status.
	--  When this bit is equal to 1 and I2C_MST_EN (Register 106 bit[5]) is
	--  equal to 0, the host application processor
	--  will be able to directly access the
	--  auxiliary I2C bus of the MPU-60X0. When this bit is equal to 0,
	--  the host application processor will not be able to directly
	--  access the auxiliary I2C bus of the MPU-60X0 regardless of the state
	--  of I2C_MST_EN (Register 106 bit[5]).
	procedure MPU92XX_Set_I2C_Bypass_Enabled
	  (Device : in out MPU92XX_Device;
	 Value  : Boolean);

	--  Set interrupts enabled status.
	procedure MPU92XX_Set_Int_Enabled
	  (Device : in out MPU92XX_Device;
	 Value  : Boolean);

	--  Set gyroscope sample rate divider
	procedure MPU92XX_Set_Rate
	  (Device   : in out MPU92XX_Device;
	 Rate_Div : UInt8);

	--  Set sleep mode status.
	procedure MPU92XX_Set_Sleep_Enabled
	  (Device : in out MPU92XX_Device;
	 Value  : Boolean);

	--  Set temperature sensor enabled status.
	procedure MPU92XX_Set_Temp_Sensor_Enabled
	  (Device : in out MPU92XX_Device;
	 Value  : Boolean);

	--  Get temperature sensor enabled status.
	function MPU92XX_Get_Temp_Sensor_Enabled
	  (Device : MPU92XX_Device) return Boolean;

	--
	-- new functions and procedures
	-- Mehdi Ben Djedidia (07/2022)
	--
	-- Return the device id
	function MPU92XX_Who_Am_I (Device : MPU92XX_Device) return UInt8;

	-- Get temperature
	function MPU92XX_Get_Temperature (Device : MPU92XX_Device) return Float;

	-- Compute angles
	--
	-- Angle_X : angle en rd que fait l'axe X par rapport ? l'horizontal
	-- Angle_Y : angle en rd que fait l'axe X par rapport ? l'horizontal
	procedure Compute_Angles (Acc_X, Acc_Y, Acc_Z    : in Float;
									Angle_X, Angle_Y       : out Float);

private

	type MPU92XX_Device
	  (Port        : HAL.I2C.Any_I2C_Port;
	 I2C_AD0_Pin : MPU92XX_AD0_Pin_State;
	 Time        : not null HAL.Time.Any_Delays)
	is record
		Is_Init : Boolean := False;
		Address : UInt10;
	end record;

	subtype T_Bit_Pos_8 is Natural  range 0 .. 7;
	subtype T_Bit_Pos_16 is Natural range 0 .. 15;

	--  Global variables and constants

	--  MPU92XX Device ID. Use to test if we are connected via I2C
	MPU92XX_DEVICE_ID        : constant := 16#75#;  -- 16#75# pour MPU92XX vs 16#71# pour MPU9250
	--  Address pin low (GND), default for InvenSense evaluation board
	MPU92XX_ADDRESS_AD0_LOW  : constant := 16#68#;
	--  Address pin high (VCC)
	MPU92XX_ADDRESS_AD0_HIGH : constant := 16#69#;

	MPU92XX_STARTUP_TIME_MS  : constant := 1_000;

	--  MPU92XX register adresses and other defines

	MPU92XX_REV_C4_ES : constant := 16#14#;
	MPU92XX_REV_C5_ES : constant := 16#15#;
	MPU92XX_REV_D6_ES : constant := 16#16#;
	MPU92XX_REV_D7_ES : constant := 16#17#;
	MPU92XX_REV_D8_ES : constant := 16#18#;
	MPU92XX_REV_C4 : constant := 16#54#;
	MPU92XX_REV_C5 : constant := 16#55#;
	MPU92XX_REV_D6 : constant := 16#56#;
	MPU92XX_REV_D7 : constant := 16#57#;
	MPU92XX_REV_D8 : constant := 16#58#;
	MPU92XX_REV_D9 : constant := 16#59#;

	MPU92XX_RA_ST_X_GYRO      : constant := 16#00#;
	MPU92XX_RA_ST_Y_GYRO      : constant := 16#01#;
	MPU92XX_RA_ST_Z_GYRO      : constant := 16#02#;
	MPU92XX_RA_ST_X_ACCEL     : constant := 16#0D#;
	MPU92XX_RA_ST_Y_ACCEL     : constant := 16#0E#;
	MPU92XX_RA_ST_Z_ACCEL     : constant := 16#0F#;
	MPU92XX_RA_XG_OFFS_USRH   : constant := 16#13#;
	MPU92XX_RA_XG_OFFS_USRL   : constant := 16#14#;
	MPU92XX_RA_YG_OFFS_USRH   : constant := 16#15#;
	MPU92XX_RA_YG_OFFS_USRL   : constant := 16#16#;
	MPU92XX_RA_ZG_OFFS_USRH   : constant := 16#17#;
	MPU92XX_RA_ZG_OFFS_USRL   : constant := 16#18#;
	MPU92XX_RA_SMPLRT_DIV     : constant := 16#19#;
	MPU92XX_RA_CONFIG         : constant := 16#1A#;
	MPU92XX_RA_GYRO_CONFIG    : constant := 16#1B#;
	MPU92XX_RA_ACCEL_CONFIG   : constant := 16#1C#;
	MPU92XX_RA_ACCEL_CONFIG_2 : constant := 16#1D#;
	MPU92XX_RA_LP_ACCEL_ODR   : constant := 16#1E#;
	MPU92XX_RA_WOM_THR        : constant := 16#1F#;

	MPU92XX_RA_FIFO_EN            : constant := 16#23#;
	MPU92XX_RA_I2C_MST_CTRL       : constant := 16#24#;
	MPU92XX_RA_I2C_SLV0_ADDR      : constant := 16#25#;
	MPU92XX_RA_I2C_SLV0_REG       : constant := 16#26#;
	MPU92XX_RA_I2C_SLV0_CTRL      : constant := 16#27#;
	MPU92XX_RA_I2C_SLV1_ADDR      : constant := 16#28#;
	MPU92XX_RA_I2C_SLV1_REG       : constant := 16#29#;
	MPU92XX_RA_I2C_SLV1_CTRL      : constant := 16#2A#;
	MPU92XX_RA_I2C_SLV2_ADDR      : constant := 16#2B#;
	MPU92XX_RA_I2C_SLV2_REG       : constant := 16#2C#;
	MPU92XX_RA_I2C_SLV2_CTRL      : constant := 16#2D#;
	MPU92XX_RA_I2C_SLV3_ADDR      : constant := 16#2E#;
	MPU92XX_RA_I2C_SLV3_REG       : constant := 16#2F#;
	MPU92XX_RA_I2C_SLV3_CTRL      : constant := 16#30#;
	MPU92XX_RA_I2C_SLV4_ADDR      : constant := 16#31#;
	MPU92XX_RA_I2C_SLV4_REG       : constant := 16#32#;
	MPU92XX_RA_I2C_SLV4_DO        : constant := 16#33#;
	MPU92XX_RA_I2C_SLV4_CTRL      : constant := 16#34#;
	MPU92XX_RA_I2C_SLV4_DI        : constant := 16#35#;
	MPU92XX_RA_I2C_MST_STATUS     : constant := 16#36#;
	MPU92XX_RA_INT_PIN_CFG        : constant := 16#37#;
	MPU92XX_RA_INT_ENABLE         : constant := 16#38#;
	MPU92XX_RA_DMP_INT_STATUS     : constant := 16#39#;
	MPU92XX_RA_INT_STATUS         : constant := 16#3A#;
	MPU92XX_RA_ACCEL_XOUT_H       : constant := 16#3B#;
	MPU92XX_RA_ACCEL_XOUT_L       : constant := 16#3C#;
	MPU92XX_RA_ACCEL_YOUT_H       : constant := 16#3D#;
	MPU92XX_RA_ACCEL_YOUT_L       : constant := 16#3E#;
	MPU92XX_RA_ACCEL_ZOUT_H       : constant := 16#3F#;
	MPU92XX_RA_ACCEL_ZOUT_L       : constant := 16#40#;

	MPU92XX_RA_TEMP_OUT_H         : constant := 16#41#;
	MPU92XX_RA_TEMP_OUT_L         : constant := 16#42#;

	MPU92XX_RA_GYRO_XOUT_H        : constant := 16#43#;
	MPU92XX_RA_GYRO_XOUT_L        : constant := 16#44#;
	MPU92XX_RA_GYRO_YOUT_H        : constant := 16#45#;
	MPU92XX_RA_GYRO_YOUT_L        : constant := 16#46#;
	MPU92XX_RA_GYRO_ZOUT_H        : constant := 16#47#;
	MPU92XX_RA_GYRO_ZOUT_L        : constant := 16#48#;
	MPU92XX_RA_EXT_SENS_DATA_00   : constant := 16#49#;
	MPU92XX_RA_EXT_SENS_DATA_01   : constant := 16#4A#;
	MPU92XX_RA_EXT_SENS_DATA_02   : constant := 16#4B#;
	MPU92XX_RA_EXT_SENS_DATA_03   : constant := 16#4C#;
	MPU92XX_RA_EXT_SENS_DATA_04   : constant := 16#4D#;
	MPU92XX_RA_EXT_SENS_DATA_05   : constant := 16#4E#;
	MPU92XX_RA_EXT_SENS_DATA_06   : constant := 16#4F#;
	MPU92XX_RA_EXT_SENS_DATA_07   : constant := 16#50#;
	MPU92XX_RA_EXT_SENS_DATA_08   : constant := 16#51#;
	MPU92XX_RA_EXT_SENS_DATA_09   : constant := 16#52#;
	MPU92XX_RA_EXT_SENS_DATA_10   : constant := 16#53#;
	MPU92XX_RA_EXT_SENS_DATA_11   : constant := 16#54#;
	MPU92XX_RA_EXT_SENS_DATA_12   : constant := 16#55#;
	MPU92XX_RA_EXT_SENS_DATA_13   : constant := 16#56#;
	MPU92XX_RA_EXT_SENS_DATA_14   : constant := 16#57#;
	MPU92XX_RA_EXT_SENS_DATA_15   : constant := 16#58#;
	MPU92XX_RA_EXT_SENS_DATA_16   : constant := 16#59#;
	MPU92XX_RA_EXT_SENS_DATA_17   : constant := 16#5A#;
	MPU92XX_RA_EXT_SENS_DATA_18   : constant := 16#5B#;
	MPU92XX_RA_EXT_SENS_DATA_19   : constant := 16#5C#;
	MPU92XX_RA_EXT_SENS_DATA_20   : constant := 16#5D#;
	MPU92XX_RA_EXT_SENS_DATA_21   : constant := 16#5E#;
	MPU92XX_RA_EXT_SENS_DATA_22   : constant := 16#5F#;
	MPU92XX_RA_EXT_SENS_DATA_23   : constant := 16#60#;
	MPU92XX_RA_MOT_DETECT_STATUS  : constant := 16#61#;
	MPU92XX_RA_I2C_SLV0_DO        : constant := 16#63#;
	MPU92XX_RA_I2C_SLV1_DO        : constant := 16#64#;
	MPU92XX_RA_I2C_SLV2_DO        : constant := 16#65#;
	MPU92XX_RA_I2C_SLV3_DO        : constant := 16#66#;
	MPU92XX_RA_I2C_MST_DELAY_CTRL : constant := 16#67#;
	MPU92XX_RA_SIGNAL_PATH_RESET  : constant := 16#68#;
	MPU92XX_RA_MOT_DETECT_CTRL    : constant := 16#69#;
	MPU92XX_RA_USER_CTRL          : constant := 16#6A#;
	MPU92XX_RA_PWR_MGMT_1         : constant := 16#6B#;
	MPU92XX_RA_PWR_MGMT_2         : constant := 16#6C#;
	MPU92XX_RA_BANK_SEL           : constant := 16#6D#;
	MPU92XX_RA_MEM_START_ADDR     : constant := 16#6E#;
	MPU92XX_RA_MEM_R_W            : constant := 16#6F#;
	MPU92XX_RA_DMP_CFG_1          : constant := 16#70#;
	MPU92XX_RA_DMP_CFG_2          : constant := 16#71#;
	MPU92XX_RA_FIFO_COUNTH        : constant := 16#72#;
	MPU92XX_RA_FIFO_COUNTL        : constant := 16#73#;
	MPU92XX_RA_FIFO_R_W           : constant := 16#74#;
	MPU92XX_RA_WHO_AM_I           : constant := 16#75#;

	MPU92XX_RA_XA_OFFSET_H : constant := 16#77#;
	MPU92XX_RA_XA_OFFSET_L : constant := 16#78#;
	MPU92XX_RA_YA_OFFSET_H : constant := 16#7A#;
	MPU92XX_RA_YA_OFFSET_L : constant := 16#7B#;
	MPU92XX_RA_ZA_OFFSET_H : constant := 16#7D#;
	MPU92XX_RA_ZA_OFFSET_L : constant := 16#7E#;

	MPU92XX_TC_PWR_MODE_BIT    : constant := 7;
	MPU92XX_TC_OFFSET_BIT      : constant := 6;
	MPU92XX_TC_OFFSET_LENGTH   : constant := 6;
	MPU92XX_TC_OTP_BNK_VLD_BIT : constant := 0;

	MPU92XX_VDDIO_LEVEL_VLOGIC : constant := 0;
	MPU92XX_VDDIO_LEVEL_VDD    : constant := 1;

	MPU92XX_CFG_EXT_SYNC_SET_BIT    : constant := 5;
	MPU92XX_CFG_EXT_SYNC_SET_LENGTH : constant := 3;
	MPU92XX_CFG_DLPF_CFG_BIT        : constant := 2;
	MPU92XX_CFG_DLPF_CFG_LENGTH     : constant := 3;

	MPU92XX_EXT_SYNC_DISABLED     : constant := 16#0#;
	MPU92XX_EXT_SYNC_TEMP_OUT_L   : constant := 16#1#;
	MPU92XX_EXT_SYNC_GYRO_XOUT_L  : constant := 16#2#;
	MPU92XX_EXT_SYNC_GYRO_YOUT_L  : constant := 16#3#;
	MPU92XX_EXT_SYNC_GYRO_ZOUT_L  : constant := 16#4#;
	MPU92XX_EXT_SYNC_ACCEL_XOUT_L : constant := 16#5#;
	MPU92XX_EXT_SYNC_ACCEL_YOUT_L : constant := 16#6#;
	MPU92XX_EXT_SYNC_ACCEL_ZOUT_L : constant := 16#7#;

	MPU92XX_GCONFIG_XG_ST_BIT     : constant := 7;
	MPU92XX_GCONFIG_YG_ST_BIT     : constant := 6;
	MPU92XX_GCONFIG_ZG_ST_BIT     : constant := 5;
	MPU92XX_GCONFIG_FS_SEL_BIT    : constant := 4;
	MPU92XX_GCONFIG_FS_SEL_LENGTH : constant := 2;

	MPU92XX_ACONFIG_XA_ST_BIT        : constant := 7;
	MPU92XX_ACONFIG_YA_ST_BIT        : constant := 6;
	MPU92XX_ACONFIG_ZA_ST_BIT        : constant := 5;
	MPU92XX_ACONFIG_AFS_SEL_BIT      : constant := 4;
	MPU92XX_ACONFIG_AFS_SEL_LENGTH   : constant := 2;
	MPU92XX_ACONFIG_ACCEL_HPF_BIT    : constant := 2;
	MPU92XX_ACONFIG_ACCEL_HPF_LENGTH : constant := 3;

	MPU92XX_DHPF_RESET : constant := 16#00#;
	MPU92XX_DHPF_5     : constant := 16#01#;
	MPU92XX_DHPF_2P5   : constant := 16#02#;
	MPU92XX_DHPF_1P25  : constant := 16#03#;
	MPU92XX_DHPF_0P63  : constant := 16#04#;
	MPU92XX_DHPF_HOLD  : constant := 16#07#;

	MPU92XX_TEMP_FIFO_EN_BIT  : constant := 7;
	MPU92XX_XG_FIFO_EN_BIT    : constant := 6;
	MPU92XX_YG_FIFO_EN_BIT    : constant := 5;
	MPU92XX_ZG_FIFO_EN_BIT    : constant := 4;
	MPU92XX_ACCEL_FIFO_EN_BIT : constant := 3;
	MPU92XX_SLV2_FIFO_EN_BIT  : constant := 2;
	MPU92XX_SLV1_FIFO_EN_BIT  : constant := 1;
	MPU92XX_SLV0_FIFO_EN_BIT  : constant := 0;

	MPU92XX_MULT_MST_EN_BIT    : constant := 7;
	MPU92XX_WAIT_FOR_ES_BIT    : constant := 6;
	MPU92XX_SLV_3_FIFO_EN_BIT  : constant := 5;
	MPU92XX_I2C_MST_P_NSR_BIT  : constant := 4;
	MPU92XX_I2C_MST_CLK_BIT    : constant := 3;
	MPU92XX_I2C_MST_CLK_LENGTH : constant := 4;

	MPU92XX_CLOCK_DIV_348 : constant := 16#0#;
	MPU92XX_CLOCK_DIV_333 : constant := 16#1#;
	MPU92XX_CLOCK_DIV_320 : constant := 16#2#;
	MPU92XX_CLOCK_DIV_308 : constant := 16#3#;
	MPU92XX_CLOCK_DIV_296 : constant := 16#4#;
	MPU92XX_CLOCK_DIV_286 : constant := 16#5#;
	MPU92XX_CLOCK_DIV_276 : constant := 16#6#;
	MPU92XX_CLOCK_DIV_267 : constant := 16#7#;
	MPU92XX_CLOCK_DIV_258 : constant := 16#8#;
	MPU92XX_CLOCK_DIV_500 : constant := 16#9#;
	MPU92XX_CLOCK_DIV_471 : constant := 16#A#;
	MPU92XX_CLOCK_DIV_444 : constant := 16#B#;
	MPU92XX_CLOCK_DIV_421 : constant := 16#C#;
	MPU92XX_CLOCK_DIV_400 : constant := 16#D#;
	MPU92XX_CLOCK_DIV_381 : constant := 16#E#;
	MPU92XX_CLOCK_DIV_364 : constant := 16#F#;

	MPU92XX_I2C_SLV_RW_BIT       : constant := 7;
	MPU92XX_I2C_SLV_ADDR_BIT     : constant := 6;
	MPU92XX_I2C_SLV_ADDR_LENGTH  : constant := 7;
	MPU92XX_I2C_SLV_EN_BIT       : constant := 7;
	MPU92XX_I2C_SLV_UInt8_SW_BIT : constant := 6;
	MPU92XX_I2C_SLV_REG_DIS_BIT  : constant := 5;
	MPU92XX_I2C_SLV_GRP_BIT      : constant := 4;
	MPU92XX_I2C_SLV_LEN_BIT      : constant := 3;
	MPU92XX_I2C_SLV_LEN_LENGTH   : constant := 4;

	MPU92XX_I2C_SLV4_RW_BIT         : constant := 7;
	MPU92XX_I2C_SLV4_ADDR_BIT       : constant := 6;
	MPU92XX_I2C_SLV4_ADDR_LENGTH    : constant := 7;
	MPU92XX_I2C_SLV4_EN_BIT         : constant := 7;
	MPU92XX_I2C_SLV4_INT_EN_BIT     : constant := 6;
	MPU92XX_I2C_SLV4_REG_DIS_BIT    : constant := 5;
	MPU92XX_I2C_SLV4_MST_DLY_BIT    : constant := 4;
	MPU92XX_I2C_SLV4_MST_DLY_LENGTH : constant := 5;

	MPU92XX_MST_PASS_THROUGH_BIT  : constant := 7;
	MPU92XX_MST_I2C_SLV4_DONE_BIT : constant := 6;
	MPU92XX_MST_I2C_LOST_ARB_BIT  : constant := 5;
	MPU92XX_MST_I2C_SLV4_NACK_BIT : constant := 4;
	MPU92XX_MST_I2C_SLV3_NACK_BIT : constant := 3;
	MPU92XX_MST_I2C_SLV2_NACK_BIT : constant := 2;
	MPU92XX_MST_I2C_SLV1_NACK_BIT : constant := 1;
	MPU92XX_MST_I2C_SLV0_NACK_BIT : constant := 0;

	MPU92XX_INTCFG_INT_LEVEL_BIT       : constant := 7;
	MPU92XX_INTCFG_INT_OPEN_BIT        : constant := 6;
	MPU92XX_INTCFG_LATCH_INT_EN_BIT    : constant := 5;
	MPU92XX_INTCFG_INT_RD_CLEAR_BIT    : constant := 4;
	MPU92XX_INTCFG_FSYNC_INT_LEVEL_BIT : constant := 3;
	MPU92XX_INTCFG_FSYNC_INT_EN_BIT    : constant := 2;
	MPU92XX_INTCFG_I2C_BYPASS_EN_BIT   : constant := 1;
	MPU92XX_INTCFG_CLKOUT_EN_BIT       : constant := 0;

	MPU92XX_INTMODE_ACTIVEHIGH : constant := 16#00#;
	MPU92XX_INTMODE_ACTIVELOW  : constant := 16#01#;

	MPU92XX_INTDRV_PUSHPULL  : constant := 16#00#;
	MPU92XX_INTDRV_OPENDRAIN : constant := 16#01#;

	MPU92XX_INTLATCH_50USPULSE : constant := 16#00#;
	MPU92XX_INTLATCH_WAITCLEAR : constant := 16#01#;

	MPU92XX_INTCLEAR_STATUSREAD : constant := 16#00#;
	MPU92XX_INTCLEAR_ANYREAD    : constant := 16#01#;

	MPU92XX_INTERRUPT_FF_BIT          : constant := 7;
	MPU92XX_INTERRUPT_MOT_BIT         : constant := 6;
	MPU92XX_INTERRUPT_ZMOT_BIT        : constant := 5;
	MPU92XX_INTERRUPT_FIFO_OFLOW_BIT  : constant := 4;
	MPU92XX_INTERRUPT_I2C_MST_INT_BIT : constant := 3;
	MPU92XX_INTERRUPT_PLL_RDY_INT_BIT : constant := 2;
	MPU92XX_INTERRUPT_DMP_INT_BIT     : constant := 1;
	MPU92XX_INTERRUPT_DATA_RDY_BIT    : constant := 0;

	MPU92XX_DMPINT_5_BIT : constant := 5;
	MPU92XX_DMPINT_4_BIT : constant := 4;
	MPU92XX_DMPINT_3_BIT : constant := 3;
	MPU92XX_DMPINT_2_BIT : constant := 2;
	MPU92XX_DMPINT_1_BIT : constant := 1;
	MPU92XX_DMPINT_0_BIT : constant := 0;

	MPU92XX_MOTION_MOT_XNEG_BIT  : constant := 7;
	MPU92XX_MOTION_MOT_XPOS_BIT  : constant := 6;
	MPU92XX_MOTION_MOT_YNEG_BIT  : constant := 5;
	MPU92XX_MOTION_MOT_YPOS_BIT  : constant := 4;
	MPU92XX_MOTION_MOT_ZNEG_BIT  : constant := 3;
	MPU92XX_MOTION_MOT_ZPOS_BIT  : constant := 2;
	MPU92XX_MOTION_MOT_ZRMOT_BIT : constant := 0;

	MPU92XX_DELAYCTRL_DELAY_ES_SHADOW_BIT : constant := 7;
	MPU92XX_DELAYCTRL_I2C_SLV4_DLY_EN_BIT : constant := 4;
	MPU92XX_DELAYCTRL_I2C_SLV3_DLY_EN_BIT : constant := 3;
	MPU92XX_DELAYCTRL_I2C_SLV2_DLY_EN_BIT : constant := 2;
	MPU92XX_DELAYCTRL_I2C_SLV1_DLY_EN_BIT : constant := 1;
	MPU92XX_DELAYCTRL_I2C_SLV0_DLY_EN_BIT : constant := 0;

	MPU92XX_PATHRESET_GYRO_RESET_BIT  : constant := 2;
	MPU92XX_PATHRESET_ACCEL_RESET_BIT : constant := 1;
	MPU92XX_PATHRESET_TEMP_RESET_BIT  : constant := 0;

	MPU92XX_DETECT_ACCEL_ON_DELAY_BIT    : constant := 5;
	MPU92XX_DETECT_ACCEL_ON_DELAY_LENGTH : constant := 2;
	MPU92XX_DETECT_FF_COUNT_BIT          : constant := 3;
	MPU92XX_DETECT_FF_COUNT_LENGTH       : constant := 2;
	MPU92XX_DETECT_MOT_COUNT_BIT         : constant := 1;
	MPU92XX_DETECT_MOT_COUNT_LENGTH      : constant := 2;

	MPU92XX_DETECT_DECREMENT_RESET : constant := 16#0#;
	MPU92XX_DETECT_DECREMENT_1     : constant := 16#1#;
	MPU92XX_DETECT_DECREMENT_2     : constant := 16#2#;
	MPU92XX_DETECT_DECREMENT_4     : constant := 16#3#;

	MPU92XX_USERCTRL_DMP_EN_BIT         : constant := 7;
	MPU92XX_USERCTRL_FIFO_EN_BIT        : constant := 6;
	MPU92XX_USERCTRL_I2C_MST_EN_BIT     : constant := 5;
	MPU92XX_USERCTRL_I2C_IF_DIS_BIT     : constant := 4;
	MPU92XX_USERCTRL_DMP_RESET_BIT      : constant := 3;
	MPU92XX_USERCTRL_FIFO_RESET_BIT     : constant := 2;
	MPU92XX_USERCTRL_I2C_MST_RESET_BIT  : constant := 1;
	MPU92XX_USERCTRL_SIG_COND_RESET_BIT : constant := 0;

	MPU92XX_PWR1_DEVICE_RESET_BIT : constant := 7;
	MPU92XX_PWR1_SLEEP_BIT        : constant := 6;
	MPU92XX_PWR1_CYCLE_BIT        : constant := 5;
	MPU92XX_PWR1_TEMP_DIS_BIT     : constant := 3;
	MPU92XX_PWR1_CLKSEL_BIT       : constant := 2;
	MPU92XX_PWR1_CLKSEL_LENGTH    : constant := 3;

	MPU92XX_CLOCK_INTERNAL   : constant := 16#00#;
	MPU92XX_CLOCK_PLL_XGYRO  : constant := 16#01#;
	MPU92XX_CLOCK_PLL_YGYRO  : constant := 16#02#;
	MPU92XX_CLOCK_PLL_ZGYRO  : constant := 16#03#;
	MPU92XX_CLOCK_PLL_EXT32K : constant := 16#04#;
	MPU92XX_CLOCK_PLL_EXT19M : constant := 16#05#;
	MPU92XX_CLOCK_KEEP_RESET : constant := 16#07#;

	MPU92XX_PWR2_LP_WAKE_CTRL_BIT    : constant := 7;
	MPU92XX_PWR2_LP_WAKE_CTRL_LENGTH : constant := 2;
	MPU92XX_PWR2_STBY_XA_BIT         : constant := 5;
	MPU92XX_PWR2_STBY_YA_BIT         : constant := 4;
	MPU92XX_PWR2_STBY_ZA_BIT         : constant := 3;
	MPU92XX_PWR2_STBY_XG_BIT         : constant := 2;
	MPU92XX_PWR2_STBY_YG_BIT         : constant := 1;
	MPU92XX_PWR2_STBY_ZG_BIT         : constant := 0;

	MPU92XX_WAKE_FREQ_1P25 : constant := 16#0#;
	MPU92XX_WAKE_FREQ_2P5  : constant := 16#1#;
	MPU92XX_WAKE_FREQ_5    : constant := 16#2#;
	MPU92XX_WAKE_FREQ_10   : constant := 16#3#;

	MPU92XX_BANKSEL_PRFTCH_EN_BIT     : constant := 6;
	MPU92XX_BANKSEL_CFG_USER_BANK_BIT : constant := 5;
	MPU92XX_BANKSEL_MEM_SEL_BIT       : constant := 4;
	MPU92XX_BANKSEL_MEM_SEL_LENGTH    : constant := 5;

	MPU92XX_WHO_AM_I_BIT    : constant := 6;
	MPU92XX_WHO_AM_I_LENGTH : constant := 6;

	MPU92XX_DMP_MEMORY_BANKS      : constant := 8;
	MPU92XX_DMP_MEMORY_BANK_SIZE  : constant := 256;
	MPU92XX_DMP_MEMORY_CHUNK_SIZE : constant := 16;

	MPU92XX_ST_GYRO_LOW           : constant := (-14.0);
	MPU92XX_ST_GYRO_HIGH          : constant := 14.0;
	MPU92XX_ST_ACCEL_LOW          : constant := (-14.0);
	MPU92XX_ST_ACCEL_HIGH         : constant := 14.0;

	--  Element n is 2620 * (1.01 ** n)
	MPU92XX_ST_TB : constant array (0 .. 255) of UInt16
	  := (
		 2620, 2646, 2672, 2699, 2726, 2753, 2781, 2808,
		 2837, 2865, 2894, 2923, 2952, 2981, 3011, 3041,
		 3072, 3102, 3133, 3165, 3196, 3228, 3261, 3293,
		 3326, 3359, 3393, 3427, 3461, 3496, 3531, 3566,
		 3602, 3638, 3674, 3711, 3748, 3786, 3823, 3862,
		 3900, 3939, 3979, 4019, 4059, 4099, 4140, 4182,
		 4224, 4266, 4308, 4352, 4395, 4439, 4483, 4528,
		 4574, 4619, 4665, 4712, 4759, 4807, 4855, 4903,
		 4953, 5002, 5052, 5103, 5154, 5205, 5257, 5310,
		 5363, 5417, 5471, 5525, 5581, 5636, 5693, 5750,
		 5807, 5865, 5924, 5983, 6043, 6104, 6165, 6226,
		 6289, 6351, 6415, 6479, 6544, 6609, 6675, 6742,
		 6810, 6878, 6946, 7016, 7086, 7157, 7229, 7301,
		 7374, 7448, 7522, 7597, 7673, 7750, 7828, 7906,
		 7985, 8065, 8145, 8227, 8309, 8392, 8476, 8561,
		 8647, 8733, 8820, 8909, 8998, 9088, 9178, 9270,
		 9363, 9457, 9551, 9647, 9743, 9841, 9939, 10038,
		 10139, 10240, 10343, 10446, 10550, 10656, 10763, 10870,
		 10979, 11089, 11200, 11312, 11425, 11539, 11654, 11771,
		 11889, 12008, 12128, 12249, 12371, 12495, 12620, 12746,
		 12874, 13002, 13132, 13264, 13396, 13530, 13666, 13802,
		 13940, 14080, 14221, 14363, 14506, 14652, 14798, 14946,
		 15096, 15247, 15399, 15553, 15709, 15866, 16024, 16184,
		 16346, 16510, 16675, 16842, 17010, 17180, 17352, 17526,
		 17701, 17878, 18057, 18237, 18420, 18604, 18790, 18978,
		 19167, 19359, 19553, 19748, 19946, 20145, 20347, 20550,
		 20756, 20963, 21173, 21385, 21598, 21814, 22033, 22253,
		 22475, 22700, 22927, 23156, 23388, 23622, 23858, 24097,
		 24338, 24581, 24827, 25075, 25326, 25579, 25835, 26093,
		 26354, 26618, 26884, 27153, 27424, 27699, 27976, 28255,
		 28538, 28823, 29112, 29403, 29697, 29994, 30294, 30597,
		 30903, 31212, 31524, 31839, 32157, 32479, 32804, 33132
		);

	--  Procedures and functions

	--  Read data to the specified MPU92XX register
	procedure MPU92XX_Read_Register
	  (Device      : MPU92XX_Device;
	 Reg_Addr    : UInt8;
	 Data        : in out I2C_Data);

	--  Read one UInt8 at the specified MPU92XX register
	procedure MPU92XX_Read_UInt8_At_Register
	  (Device   : MPU92XX_Device;
	 Reg_Addr : UInt8;
	 Data     : out UInt8);

	--  Read one bit at the specified MPU92XX register
	function MPU92XX_Read_Bit_At_Register
	  (Device    : MPU92XX_Device;
	 Reg_Addr  : UInt8;
	 Bit_Pos   : T_Bit_Pos_8) return Boolean;

	--  Write data to the specified MPU92XX register
	procedure MPU92XX_Write_Register
	  (Device      : MPU92XX_Device;
	 Reg_Addr    : UInt8;
	 Data        : I2C_Data);

	--  Write one UInt8 at the specified MPU92XX register
	procedure MPU92XX_Write_UInt8_At_Register
	  (Device   : MPU92XX_Device;
	 Reg_Addr : UInt8;
	 Data     : UInt8);

	--  Write one bit at the specified MPU92XX register
	procedure MPU92XX_Write_Bit_At_Register
	  (Device    : MPU92XX_Device;
	 Reg_Addr  : UInt8;
	 Bit_Pos   : T_Bit_Pos_8;
	 Bit_Value : Boolean);

	--  Write data in the specified register, starting from the
	--  bit specified in Start_Bit_Pos
	procedure MPU92XX_Write_Bits_At_Register
	  (Device        : MPU92XX_Device;
	 Reg_Addr      : UInt8;
	 Start_Bit_Pos : T_Bit_Pos_8;
	 Data          : UInt8;
	 Length        : T_Bit_Pos_8);

	function Fuse_Low_And_High_Register_Parts
	  (High : UInt8;
	 Low  : UInt8) return Integer_16;
	pragma Inline (Fuse_Low_And_High_Register_Parts);




end MPU92XX;
