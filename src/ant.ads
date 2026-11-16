--  A colony on a grid, and four voices of one short tune.
--  The page only draws what this package stores.

with System;

package Ant is

   Ant_Count : constant := 150;
   Width     : constant := 28;
   Height    : constant := 18;
   Cells     : constant := Width * Height;
   Coarse    : constant := 4;
   Cluster_W : constant := (Width + Coarse - 1) / Coarse;
   Cluster_H : constant := (Height + Coarse - 1) / Coarse;
   Cluster_N : constant := Cluster_W * Cluster_H;
   Trail_Max : constant := 16;
   Food_Add  : constant := 8;
   Food_Max  : constant := 24;
   Voice_N   : constant := 4;
   Motif_N   : constant := 4;
   Loop_N    : constant := 16;
   Step_Ms   : constant := 420;

   procedure Reset;
   procedure Reseed (Value : Natural);
   procedure Step;
   procedure Steps (Count : Natural);
   procedure Drop_Food (X : Natural; Y : Natural);
   procedure Set_Trail (X : Natural; Y : Natural; Value : Natural);
   procedure Clear_Loads;

   function Ant_X (Index : Natural) return Natural;
   function Ant_Y (Index : Natural) return Natural;
   function Carrying (Index : Natural) return Boolean;
   function In_Bounds return Boolean;
   function Trail_At (X : Natural; Y : Natural) return Natural;
   function Food_At (X : Natural; Y : Natural) return Natural;
   function Cluster_Of (Index : Natural) return Natural;
   function Cluster_Size (Id : Natural) return Natural;

   function Step_Milliseconds return Natural;
   function Play_Column (Voice : Natural; Beat : Natural) return Integer;
   function Voice_Pitch (Voice : Natural; Beat : Natural) return Integer;

   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "ant_meta";
   function X_Address return System.Address
     with Export, Convention => C, External_Name => "ant_x";
   function Y_Address return System.Address
     with Export, Convention => C, External_Name => "ant_y";
   function Carry_Address return System.Address
     with Export, Convention => C, External_Name => "ant_carry";
   function Trail_Address return System.Address
     with Export, Convention => C, External_Name => "ant_trail";
   function Food_Address return System.Address
     with Export, Convention => C, External_Name => "ant_food";
   function Cluster_Address return System.Address
     with Export, Convention => C, External_Name => "ant_cluster";
   function Sum_X_Address return System.Address
     with Export, Convention => C, External_Name => "ant_sum_x";
   function Sum_Y_Address return System.Address
     with Export, Convention => C, External_Name => "ant_sum_y";
   function Motif_Address return System.Address
     with Export, Convention => C, External_Name => "ant_motif";
   function Voice_Address return System.Address
     with Export, Convention => C, External_Name => "ant_voice";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "ant_reset";
   procedure Step_Exported
     with Export, Convention => C, External_Name => "ant_step";
   procedure Drop_Exported (X : Integer; Y : Integer)
     with Export, Convention => C, External_Name => "ant_drop";
   procedure Set_Beat_Exported (Beat : Integer)
     with Export, Convention => C, External_Name => "ant_set_beat";

end Ant;
