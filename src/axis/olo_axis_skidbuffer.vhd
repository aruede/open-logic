------------------------------------------------------------------------------
--  Copyright (c) 2024 by Alexander Ruede
--  All rights reserved.
--  Authors: Alexander Ruede
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This entity implements a self-sufficient and low-resource AXI-Stream skid
-- buffer that can be used to add a register, for example for pipelining in
-- AXI-Stream cores. Its completely self-sufficient, as in it does not include
-- other entities and is thus easy to use and understand.
-- Notice that all signals, except the handshaking signals are optional.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_axis_skidbuffer is
generic (
    AxisTDataWidth_g        : natural := 8;
    AxisTUserWidth_g        : natural := 1;
    AxisTDestWidth_g        : natural := 0;
    AxisTIdWidth_g          : natural := 0
);
port (
    -- Control Signals
    Clk                     : in  std_logic;
    Rst                     : in  std_logic;
    -- AXI-Stream Slave Interface
    S_Axis_TValid           : in  std_logic;
    S_Axis_TReady           : out std_logic;
    S_Axis_TData            : in  std_logic_vector(AxisTDataWidth_g - 1 downto 0) := (others => '0');
    S_Axis_TKeep            : in  std_logic_vector(AxisTDataWidth_g/8 - 1 downto 0) := (others => '0');
    S_Axis_TUser            : in  std_logic_vector(AxisTUserWidth_g - 1 downto 0) := (others => '0');
    S_Axis_TDest            : in  std_logic_vector(AxisTDestWidth_g - 1 downto 0) := (others => '0');
    S_Axis_TId              : in  std_logic_vector(AxisTIdWidth_g - 1 downto 0) := (others => '0');
    S_Axis_TLast            : in  std_logic := '0';
    -- AXI-Stream Master Interface
    M_Axis_TValid           : out std_logic;
    M_Axis_TReady           : in  std_logic;
    M_Axis_TData            : out std_logic_vector(AxisTDataWidth_g - 1 downto 0);
    M_Axis_TKeep            : out std_logic_vector(AxisTDataWidth_g/8 - 1 downto 0);
    M_Axis_TUser            : out std_logic_vector(AxisTUserWidth_g - 1 downto 0);
    M_Axis_TDest            : out std_logic_vector(AxisTDestWidth_g - 1 downto 0);
    M_Axis_TId              : out std_logic_vector(AxisTIdWidth_g - 1 downto 0);
    M_Axis_TLast            : out std_logic
);
end entity olo_axis_skidbuffer;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_axis_skidbuffer is

    signal InBuf_TData      : std_logic_vector(AxisTDataWidth_g - 1 downto 0);
    signal InBuf_TKeep      : std_logic_vector(AxisTDataWidth_g/8 - 1 downto 0);
    signal InBuf_TUser      : std_logic_vector(AxisTUserWidth_g - 1 downto 0);
    signal InBuf_TLast      : std_logic;
    signal InBuf_TDest      : std_logic_vector(AxisTDestWidth_g - 1 downto 0);
    signal InBuf_TId        : std_logic_vector(AxisTIdWidth_g - 1 downto 0);
    signal InBuf_TReady     : std_logic;

    signal OutBuf_TValid    : std_logic;
    signal OutBuf_TReady    : std_logic;
    signal OutBuf_TData     : std_logic_vector(AxisTDataWidth_g - 1 downto 0);
    signal OutBuf_TKeep     : std_logic_vector(AxisTDataWidth_g/8 - 1 downto 0);
    signal OutBuf_TUser     : std_logic_vector(AxisTUserWidth_g - 1 downto 0);
    signal OutBuf_TDest     : std_logic_vector(AxisTDestWidth_g - 1 downto 0);
    signal OutBuf_TId       : std_logic_vector(AxisTIdWidth_g - 1 downto 0);
    signal OutBuf_TLast     : std_logic;

begin

    -- Input buffer

    S_Axis_TReady <= InBuf_TReady and not Rst;

    p_input_bufffer : process(Clk)
    begin
        if rising_edge(Clk) then
            if OutBuf_TValid = '1' then
                InBuf_TReady <= OutBuf_TReady;
            end if;
            if InBuf_TReady = '1' then
                InBuf_TData <= s_axis_tdata;
                InBuf_TKeep <= s_axis_tkeep;
                InBuf_TUser <= s_axis_tuser;
                InBuf_TLast <= s_axis_tlast;
                InBuf_TId <= s_axis_tid;
                InBuf_TDest <= s_axis_tdest;
            end if;
            -- Reset
            if Rst = '1' then
                InBuf_TReady <= '1';
                InBuf_TData <= (others => '-');
                InBuf_TKeep <= (others => '-');
                InBuf_TUser <= (others => '-');
                InBuf_TLast <= '-';
                InBuf_TId <= (others => '-');
                InBuf_TDest <= (others => '-');
            end if;
        end if;
    end process;

    -- Output buffer

    OutBuf_TValid <= not InBuf_TReady or s_axis_tvalid;
    OutBuf_TReady <= not M_Axis_TValid or M_Axis_TReady;

    OutBuf_TData <= InBuf_TData when InBuf_TReady = '0' else s_axis_tdata;
    OutBuf_TKeep <= InBuf_TKeep when InBuf_TReady = '0' else s_axis_tkeep;
    OutBuf_TUser <= InBuf_TUser when InBuf_TReady = '0' else s_axis_tuser;
    OutBuf_TLast <= InBuf_TLast when InBuf_TReady = '0' else s_axis_tlast;
    OutBuf_TId <= InBuf_TId when InBuf_TReady = '0' else s_axis_tid;
    OutBuf_TDest <= InBuf_TDest when InBuf_TReady = '0' else s_axis_tdest;

    p_output_buffer : process(Clk)
    begin
        if rising_edge(Clk) then
            if OutBuf_TReady = '1' then
                M_Axis_TValid <= OutBuf_TValid;
                M_Axis_TData <= OutBuf_TData;
                M_Axis_TKeep <= OutBuf_TKeep;
                M_Axis_TUser <= OutBuf_TUser;
                M_Axis_TLast <= OutBuf_TLast;
                M_Axis_TId <= OutBuf_TId;
                M_Axis_TDest <= OutBuf_TDest;
            end if;
            -- Reset
            if Rst = '1' then
                M_Axis_TValid <= '0';
                M_Axis_TData <= (others => '-');
                M_Axis_TKeep <= (others => '-');
                M_Axis_TUser <= (others => '-');
                M_Axis_TLast <= '-';
                M_Axis_TId <= (others => '-');
                M_Axis_TDest <= (others => '-');
            end if;
        end if;
    end process;

end architecture rtl;
